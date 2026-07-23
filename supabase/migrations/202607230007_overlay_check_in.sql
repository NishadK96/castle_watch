create function public.mark_played_from_session(
  p_session_id uuid, p_secret uuid, p_account_id uuid
) returns void language plpgsql security definer set search_path = '' as $$
declare
  session_row public.play_sessions;
begin
  select ps.* into session_row from public.play_sessions ps
    where ps.id = p_session_id
      and ps.action_secret = p_secret
      and ps.status = 'active';
  if session_row.id is null then raise exception 'Play session is unavailable'; end if;
  if not (p_account_id = any(session_row.account_ids)) then
    raise exception 'Account is not part of this session';
  end if;

  insert into public.account_check_ins(user_id, account_id, played_at, notes)
    values(session_row.user_id, p_account_id, now(), 'Android overlay check-in');
  update public.game_accounts set last_played_at = now()
    where id = p_account_id and user_id = session_row.user_id;
end; $$;

revoke all on function public.mark_played_from_session(uuid,uuid,uuid)
  from public;
grant execute on function public.mark_played_from_session(uuid,uuid,uuid)
  to anon, authenticated;
