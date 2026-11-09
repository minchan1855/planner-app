// 카카오톡 "나에게 보내기" 알림
// - 앱에서: status / start(연결 주소 만들기) / test(시험 메시지) / disconnect
// - 카카오에서: ?code=..&state=.. 로 돌아오면 토큰 저장 후 웹 앱으로 돌려보냄
// - 1분마다(pg_cron): ?cron=1 + x-cron-key → 알람 시간이 된 일을 카톡으로 보냄
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const URL_ = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const REST_KEY = Deno.env.get("KAKAO_REST_KEY") ?? "";
const CLIENT_SECRET = Deno.env.get("KAKAO_CLIENT_SECRET") ?? "";
const REDIRECT = `${URL_}/functions/v1/kakao`;
const WEB = "https://minchan1855.github.io/planner-app/";
const db = createClient(URL_, SERVICE, { auth: { persistSession: false } });

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

async function tokenRequest(params: Record<string, string>) {
  const body = new URLSearchParams({ client_id: REST_KEY, ...params });
  if (CLIENT_SECRET) body.set("client_secret", CLIENT_SECRET);
  const r = await fetch("https://kauth.kakao.com/oauth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded;charset=utf-8" },
    body,
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`kakao token ${r.status}: ${JSON.stringify(j)}`);
  return j as { access_token: string; refresh_token?: string; expires_in: number };
}

async function accessToken(userId: string): Promise<string | null> {
  const { data: t } = await db.from("kakao_tokens").select("*").eq("user_id", userId).maybeSingle();
  if (!t) return null;
  if (new Date(t.access_expires_at).getTime() > Date.now() + 120_000) return t.access_token;
  const j = await tokenRequest({ grant_type: "refresh_token", refresh_token: t.refresh_token });
  await db.from("kakao_tokens").update({
    access_token: j.access_token,
    refresh_token: j.refresh_token ?? t.refresh_token,
    access_expires_at: new Date(Date.now() + j.expires_in * 1000).toISOString(),
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId);
  return j.access_token;
}

async function sendMemo(userId: string, text: string) {
  const at = await accessToken(userId);
  if (!at) throw new Error("not connected");
  const template = { object_type: "text", text, link: { web_url: WEB, mobile_web_url: WEB }, button_title: "계획표 열기" };
  const r = await fetch("https://kapi.kakao.com/v2/api/talk/memo/default/send", {
    method: "POST",
    headers: { Authorization: `Bearer ${at}`, "Content-Type": "application/x-www-form-urlencoded;charset=utf-8" },
    body: new URLSearchParams({ template_object: JSON.stringify(template) }),
  });
  if (!r.ok) throw new Error(`kakao send ${r.status}: ${await r.text()}`);
}

const hm = (s?: string | null) => {
  const m = s ? /^(\d{1,2}):(\d{2})$/.exec(s) : null;
  return m ? +m[1] * 60 + +m[2] : null;
};
const kstDate = (ms: number) => new Date(ms + 9 * 3600_000).toISOString().slice(0, 10);

type Task = { id: string; type?: string; title?: string; alarm?: string | null; done?: boolean; start?: string; end?: string };

async function runCron() {
  const { data: users } = await db.from("kakao_tokens").select("user_id");
  const nowMs = Date.now();
  const kst = new Date(nowMs + 9 * 3600_000);
  const today = kstDate(nowMs), tomorrow = kstDate(nowMs + 86400_000);
  const nowMin = kst.getUTCHours() * 60 + kst.getUTCMinutes();
  let sent = 0;
  for (const { user_id } of users ?? []) {
    const { data: docs } = await db.from("docs").select("key,data").eq("user_id", user_id)
      .in("key", ["settings", `day:${today}`, `day:${tomorrow}`]);
    const get = (k: string) => docs?.find((d) => d.key === k)?.data as Record<string, any> | undefined;
    const s = get("settings") ?? {};
    if (s.kakaoAlarm === false) continue;
    const lead = typeof s.leadMinutes === "number" ? s.leadMinutes : 10;
    const due: { ref: string; text: string }[] = [];
    for (const [date, offset] of [[today, 0], [tomorrow, 1440]] as const) {
      const day = get(`day:${date}`);
      if (!day) continue;
      const items: [Task, string][] = [
        ...((day.tasks ?? []) as Task[]).map((t) => [t, t.type === "B" ? "여유 있게 할 일" : "꼭 할 일"] as [Task, string]),
        ...((day.blocks ?? []) as Task[]).map((t) => [t, "계획"] as [Task, string]),
      ];
      for (const [t, kind] of items) {
        const m = hm(t.alarm);
        if (m == null || t.done || !t.title?.trim()) continue;
        const fire = m - lead + offset;
        const late = nowMin - fire;
        if (late < 0 || late >= 10) continue;
        const when = lead === 0 ? "지금" : `${lead}분 뒤`;
        const range = t.start && t.end ? ` (${t.start}~${t.end})` : ` (${t.alarm})`;
        due.push({ ref: `${date}|${t.id}|${t.alarm}`, text: `⏰ ${kind} · ${when}\n${t.title.trim()}${range}` });
      }
    }
    if (s.weeklyReviewAlarm !== false && kst.getUTCDay() === 0 && nowMin >= 1260 && nowMin < 1270) {
      due.push({ ref: `${today}|review`, text: "📝 주간 회고 쓸 시간이에요\n이번 주 잘한 점, 아쉬운 점, 다음 주 다짐을 적어보세요" });
    }
    for (const d of due) {
      const { data: ins } = await db.from("kakao_sent").upsert({ user_id, ref: d.ref }, { onConflict: "user_id,ref", ignoreDuplicates: true }).select();
      if (!ins?.length) continue;
      try {
        await sendMemo(user_id, d.text);
        sent++;
      } catch (e) {
        console.error(e);
        await db.from("kakao_sent").delete().eq("user_id", user_id).eq("ref", d.ref);
      }
    }
  }
  return sent;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const url = new URL(req.url);

  // 1분마다 부르는 알림
  if (url.searchParams.has("cron")) {
    const { data: ok } = await db.rpc("kakao_cron_key_ok", { k: req.headers.get("x-cron-key") ?? "" });
    if (ok !== true) return json({ error: "forbidden" }, 403);
    return json({ sent: await runCron() });
  }

  // 카카오 로그인 후 돌아오는 곳
  if (req.method === "GET" && (url.searchParams.has("code") || url.searchParams.has("error"))) {
    const back = (r: string) => Response.redirect(`${WEB}?kakao=${r}`, 302);
    const state = url.searchParams.get("state") ?? "";
    const { data: st } = await db.from("kakao_states").delete().eq("state", state).select().maybeSingle();
    if (!st || Date.now() - new Date(st.created_at).getTime() > 15 * 60_000) return back("expired");
    const code = url.searchParams.get("code");
    if (!code) return back("denied");
    try {
      const j = await tokenRequest({ grant_type: "authorization_code", redirect_uri: REDIRECT, code });
      await db.from("kakao_tokens").upsert({
        user_id: st.user_id,
        access_token: j.access_token,
        refresh_token: j.refresh_token!,
        access_expires_at: new Date(Date.now() + j.expires_in * 1000).toISOString(),
        updated_at: new Date().toISOString(),
      });
      await sendMemo(st.user_id, "✅ 계획표 앱과 카카오톡이 연결됐어요.\n이제 알람 시간에 여기로 알려드릴게요.").catch(console.error);
      return back("ok");
    } catch (e) {
      console.error(e);
      return back("fail");
    }
  }

  // 앱에서 부르는 기능 (로그인한 사용자만)
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer /, "");
  const { data: u } = await db.auth.getUser(jwt);
  if (!u?.user) return json({ error: "login" }, 401);
  const userId = u.user.id;
  const { action } = await req.json().catch(() => ({ action: "status" }));
  try {
    if (action === "status") {
      const { data } = await db.from("kakao_tokens").select("updated_at").eq("user_id", userId).maybeSingle();
      return json({ ready: !!REST_KEY, connected: !!data });
    }
    if (action === "start") {
      if (!REST_KEY) return json({ error: "not_ready" }, 400);
      const state = crypto.randomUUID();
      await db.from("kakao_states").insert({ state, user_id: userId });
      const q = new URLSearchParams({ client_id: REST_KEY, redirect_uri: REDIRECT, response_type: "code", scope: "talk_message", state });
      return json({ url: `https://kauth.kakao.com/oauth/authorize?${q}` });
    }
    if (action === "test") {
      await sendMemo(userId, "🔔 시험 메시지예요. 카톡 알림이 잘 와요!");
      return json({ ok: true });
    }
    if (action === "disconnect") {
      await db.from("kakao_tokens").delete().eq("user_id", userId);
      return json({ ok: true });
    }
    return json({ error: "unknown" }, 400);
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
