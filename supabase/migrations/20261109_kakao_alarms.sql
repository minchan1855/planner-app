-- 카카오톡 나에게 보내기 알림 (Supabase에 적용하는 설정)
create extension if not exists pg_cron;
create extension if not exists pg_net;

create table if not exists public.kakao_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  access_token text not null,
  refresh_token text not null,
  access_expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);
create table if not exists public.kakao_states (
  state text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.kakao_sent (
  user_id uuid not null references auth.users(id) on delete cascade,
  ref text not null,
  sent_at timestamptz not null default now(),
  primary key (user_id, ref)
);
alter table public.kakao_tokens enable row level security;
alter table public.kakao_states enable row level security;
alter table public.kakao_sent enable row level security;
revoke all on public.kakao_tokens, public.kakao_states, public.kakao_sent from anon, authenticated;

select vault.create_secret(encode(extensions.gen_random_bytes(24), 'hex'), 'kakao_cron_key')
where not exists (select 1 from vault.secrets where name = 'kakao_cron_key');

create or replace function public.kakao_cron_key_ok(k text) returns boolean
language sql security definer set search_path = '' as $$
  select exists (select 1 from vault.decrypted_secrets where name = 'kakao_cron_key' and decrypted_secret = k);
$$;
revoke all on function public.kakao_cron_key_ok(text) from public, anon, authenticated;
grant execute on function public.kakao_cron_key_ok(text) to service_role;

select cron.schedule('kakao-alarms', '* * * * *', $cron$
  select net.http_post(
    url := 'https://dqztfsinsyohdejjbive.supabase.co/functions/v1/kakao?cron=1',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-key',
      (select decrypted_secret from vault.decrypted_secrets where name = 'kakao_cron_key')),
    body := '{}'::jsonb,
    timeout_milliseconds := 20000
  );
$cron$);
select cron.schedule('kakao-cleanup', '17 4 * * *', $cron$
  delete from public.kakao_sent where sent_at < now() - interval '30 days';
  delete from public.kakao_states where created_at < now() - interval '1 day';
$cron$);
