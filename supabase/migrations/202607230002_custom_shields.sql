drop function if exists public.replace_account_shield(uuid, integer, text);

create function public.replace_account_shield(
  p_account_id uuid,
  p_duration_minutes integer,
  p_shield_type text,
  p_started_at timestamptz default now(),
  p_notes text default ''
) returns public.shields
language plpgsql security invoker set search_path = '' as $$
declare result public.shields; owner_id uuid := auth.uid();
begin
  if p_duration_minutes <= 0 then raise exception 'Duration must be positive'; end if;
  if p_started_at > now() + interval '1 minute' then raise exception 'Activation time cannot be in the future'; end if;
  if not exists(select 1 from public.game_accounts where id = p_account_id and user_id = owner_id) then raise exception 'Account not found'; end if;
  update public.shields set status = 'replaced', updated_at = now()
    where account_id = p_account_id and user_id = owner_id and status in ('active','expiring_soon');
  insert into public.shields(user_id, account_id, shield_type, duration_minutes, started_at, expires_at, notes)
  values(owner_id, p_account_id, p_shield_type, p_duration_minutes, p_started_at, p_started_at + make_interval(mins => p_duration_minutes), p_notes)
  returning * into result;
  return result;
end; $$;
revoke all on function public.replace_account_shield(uuid, integer, text, timestamptz, text) from public;
grant execute on function public.replace_account_shield(uuid, integer, text, timestamptz, text) to authenticated;
