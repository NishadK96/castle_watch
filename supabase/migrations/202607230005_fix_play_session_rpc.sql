create or replace function public.start_play_session(p_account_ids uuid[])
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  owner_id uuid := auth.uid();
  session_row public.play_sessions;
  first_account_name text;
begin
  if cardinality(p_account_ids) = 0 then raise exception 'Select at least one account'; end if;
  if exists (
    select 1 from unnest(p_account_ids) queued_account_id
    where not exists (
      select 1 from public.game_accounts ga
      where ga.id = queued_account_id and ga.user_id = owner_id
    )
  ) then raise exception 'Invalid account queue'; end if;

  update public.play_sessions set status = 'stopped', completed_at = now()
    where user_id = owner_id and status = 'active';
  insert into public.play_sessions(user_id, account_ids)
    values(owner_id, p_account_ids) returning * into session_row;
  select ga.account_name into first_account_name
    from public.game_accounts ga where ga.id = p_account_ids[1];
  return jsonb_build_object(
    'id', session_row.id, 'secret', session_row.action_secret,
    'current_account_id', p_account_ids[1],
    'current_account_name', first_account_name,
    'position', 1, 'total', cardinality(p_account_ids), 'status', 'active'
  );
end; $$;

create or replace function public.advance_play_session(
  p_session_id uuid, p_secret uuid, p_action text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  session_row public.play_sessions;
  current_account_id uuid;
  next_account_id uuid;
  next_account_name text;
  next_index integer;
begin
  select ps.* into session_row from public.play_sessions ps
    where ps.id = p_session_id
      and ps.action_secret = p_secret
      and ps.status = 'active'
    for update;
  if session_row.id is null then raise exception 'Play session is unavailable'; end if;
  if p_action not in ('played','skip','stop') then raise exception 'Invalid action'; end if;
  if p_action = 'stop' then
    update public.play_sessions set status = 'stopped', completed_at = now()
      where id = session_row.id;
    return jsonb_build_object('status','stopped');
  end if;

  current_account_id := session_row.account_ids[session_row.current_index + 1];
  if p_action = 'played' then
    insert into public.account_check_ins(user_id, account_id, played_at, notes)
      values(session_row.user_id, current_account_id, now(), 'Notification check-in');
    update public.game_accounts set last_played_at = now()
      where id = current_account_id and user_id = session_row.user_id;
  end if;

  next_index := session_row.current_index + 1;
  if next_index >= cardinality(session_row.account_ids) then
    update public.play_sessions
      set status = 'completed', current_index = next_index, completed_at = now()
      where id = session_row.id;
    return jsonb_build_object('status','completed');
  end if;
  next_account_id := session_row.account_ids[next_index + 1];
  select ga.account_name into next_account_name
    from public.game_accounts ga where ga.id = next_account_id;
  update public.play_sessions set current_index = next_index
    where id = session_row.id;
  return jsonb_build_object(
    'id', session_row.id, 'secret', session_row.action_secret,
    'current_account_id', next_account_id,
    'current_account_name', next_account_name,
    'position', next_index + 1, 'total', cardinality(session_row.account_ids),
    'status', 'active'
  );
end; $$;

revoke all on function public.start_play_session(uuid[]) from public;
grant execute on function public.start_play_session(uuid[]) to authenticated;
revoke all on function public.advance_play_session(uuid,uuid,text) from public;
grant execute on function public.advance_play_session(uuid,uuid,text)
  to anon, authenticated;
