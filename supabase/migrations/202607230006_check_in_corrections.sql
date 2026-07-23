create function public.undo_account_check_in(p_check_in_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
declare
  owner_id uuid := auth.uid();
  affected_account_id uuid;
begin
  delete from public.account_check_ins
    where id = p_check_in_id and user_id = owner_id
    returning account_id into affected_account_id;
  if affected_account_id is null then raise exception 'Check-in not found'; end if;

  update public.game_accounts
    set last_played_at = (
      select max(ci.played_at) from public.account_check_ins ci
      where ci.account_id = affected_account_id and ci.user_id = owner_id
    )
    where id = affected_account_id and user_id = owner_id;
end; $$;

create function public.reassign_account_check_in(
  p_check_in_id uuid, p_new_account_id uuid
) returns void language plpgsql security invoker set search_path = '' as $$
declare
  owner_id uuid := auth.uid();
  old_account_id uuid;
begin
  select ci.account_id into old_account_id from public.account_check_ins ci
    where ci.id = p_check_in_id and ci.user_id = owner_id;
  if old_account_id is null then raise exception 'Check-in not found'; end if;
  if not exists (
    select 1 from public.game_accounts
    where id = p_new_account_id and user_id = owner_id
  ) then raise exception 'New account not found'; end if;

  update public.account_check_ins set account_id = p_new_account_id
    where id = p_check_in_id and user_id = owner_id;
  update public.game_accounts
    set last_played_at = (
      select max(ci.played_at) from public.account_check_ins ci
      where ci.account_id = old_account_id and ci.user_id = owner_id
    )
    where id = old_account_id and user_id = owner_id;
  update public.game_accounts
    set last_played_at = (
      select max(ci.played_at) from public.account_check_ins ci
      where ci.account_id = p_new_account_id and ci.user_id = owner_id
    )
    where id = p_new_account_id and user_id = owner_id;
end; $$;

revoke all on function public.undo_account_check_in(uuid) from public;
grant execute on function public.undo_account_check_in(uuid) to authenticated;
revoke all on function public.reassign_account_check_in(uuid,uuid) from public;
grant execute on function public.reassign_account_check_in(uuid,uuid)
  to authenticated;
