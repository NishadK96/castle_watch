-- Atomically replaces an account's current shield and returns the new record.
create or replace function public.replace_account_shield(
  p_account_id uuid,
  p_duration_minutes integer,
  p_shield_type text
) returns public.shields
language plpgsql
security invoker
set search_path = ''
as $$
declare
  result public.shields;
  owner_id uuid := auth.uid();
  started timestamptz := now();
begin
  if p_duration_minutes <= 0 then raise exception 'Duration must be positive'; end if;
  if not exists(select 1 from public.game_accounts where id = p_account_id and user_id = owner_id) then
    raise exception 'Account not found';
  end if;

  update public.shields
  set status = 'replaced', updated_at = now()
  where account_id = p_account_id and user_id = owner_id and status in ('active', 'expiring_soon');

  insert into public.shields(user_id, account_id, shield_type, duration_minutes, started_at, expires_at)
  values(owner_id, p_account_id, p_shield_type, p_duration_minutes, started, started + make_interval(mins => p_duration_minutes))
  returning * into result;
  return result;
end;
$$;
revoke all on function public.replace_account_shield(uuid, integer, text) from public;
grant execute on function public.replace_account_shield(uuid, integer, text) to authenticated;
