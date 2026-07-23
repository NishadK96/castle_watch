alter table public.game_accounts
  add column if not exists last_played_at timestamptz;

create table if not exists public.account_check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_users(id) on delete cascade,
  account_id uuid not null references public.game_accounts(id) on delete cascade,
  played_at timestamptz not null default now(),
  notes text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists account_check_ins_user_played_idx
  on public.account_check_ins(user_id, played_at desc);
create index if not exists account_check_ins_account_played_idx
  on public.account_check_ins(account_id, played_at desc);

alter table public.account_check_ins enable row level security;

create policy account_check_ins_select on public.account_check_ins
  for select using ((select auth.uid()) = user_id);
create policy account_check_ins_insert on public.account_check_ins
  for insert with check ((select auth.uid()) = user_id);
create policy account_check_ins_update on public.account_check_ins
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy account_check_ins_delete on public.account_check_ins
  for delete using ((select auth.uid()) = user_id);

create or replace function public.record_account_check_in(
  p_account_id uuid,
  p_played_at timestamptz default now(),
  p_notes text default ''
) returns public.account_check_ins
language plpgsql
security invoker
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
  result public.account_check_ins;
begin
  if p_played_at > now() + interval '1 minute' then
    raise exception 'Played time cannot be in the future';
  end if;
  if not exists (
    select 1 from public.game_accounts
    where id = p_account_id and user_id = owner_id
  ) then
    raise exception 'Account not found';
  end if;

  insert into public.account_check_ins(user_id, account_id, played_at, notes)
  values(owner_id, p_account_id, p_played_at, trim(coalesce(p_notes, '')))
  returning * into result;

  update public.game_accounts
  set last_played_at = greatest(
    coalesce(last_played_at, '-infinity'::timestamptz),
    p_played_at
  )
  where id = p_account_id and user_id = owner_id;

  return result;
end;
$$;

revoke all on function public.record_account_check_in(uuid, timestamptz, text)
  from public;
grant execute on function public.record_account_check_in(uuid, timestamptz, text)
  to authenticated;
