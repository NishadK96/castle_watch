-- Castle Watch initial schema. All client-owned data is protected by RLS.
create extension if not exists pgcrypto;

create type public.shield_status as enum ('active','expiring_soon','expired','cancelled','replaced');

create table public.app_users (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '', email text not null, avatar_url text,
  timezone text not null default 'UTC', notification_enabled boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.game_accounts (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.app_users(id) on delete cascade,
  account_name text not null check (length(trim(account_name)) > 0), player_name text, kingdom text, guild_name text,
  might bigint check (might is null or might >= 0), castle_level smallint check (castle_level between 1 and 25),
  account_color text, account_icon text, notes text, is_favorite boolean not null default false, is_archived boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.shields (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.app_users(id) on delete cascade,
  account_id uuid not null references public.game_accounts(id) on delete cascade, shield_type text not null,
  duration_minutes integer not null check (duration_minutes > 0), started_at timestamptz not null, expires_at timestamptz not null,
  status public.shield_status not null default 'active', notes text,
  notification_24h_sent boolean not null default false, notification_6h_sent boolean not null default false,
  notification_1h_sent boolean not null default false, notification_15m_sent boolean not null default false,
  notification_expired_sent boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (expires_at > started_at)
);
create unique index one_active_shield_per_account on public.shields(account_id) where status in ('active','expiring_soon');
create table public.user_devices (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.app_users(id) on delete cascade,
  device_token text not null unique, platform text not null check (platform in ('android','ios','web')),
  device_name text, is_active boolean not null default true, last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.notification_preferences (
  id uuid primary key default gen_random_uuid(), user_id uuid not null unique references public.app_users(id) on delete cascade,
  reminder_24h boolean not null default true, reminder_6h boolean not null default true, reminder_1h boolean not null default true,
  reminder_15m boolean not null default true, reminder_expired boolean not null default true, push_enabled boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.notification_logs (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.app_users(id) on delete cascade,
  account_id uuid references public.game_accounts(id) on delete set null, shield_id uuid references public.shields(id) on delete set null,
  notification_type text not null, title text not null, body text not null, delivery_status text not null,
  error_message text, sent_at timestamptz, created_at timestamptz not null default now()
);

create index game_accounts_user_idx on public.game_accounts(user_id);
create index shields_user_idx on public.shields(user_id);
create index shields_account_idx on public.shields(account_id);
create index shields_status_expires_idx on public.shields(status, expires_at);
create index devices_user_idx on public.user_devices(user_id);
create index logs_user_created_idx on public.notification_logs(user_id, created_at desc);

create function public.set_updated_at() returns trigger language plpgsql set search_path = '' as $$ begin new.updated_at = now(); return new; end; $$;
create function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.app_users(id,email,display_name) values(new.id,coalesce(new.email,''),coalesce(new.raw_user_meta_data->>'display_name',''));
  insert into public.notification_preferences(user_id) values(new.id);
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
create trigger app_users_updated before update on public.app_users for each row execute function public.set_updated_at();
create trigger accounts_updated before update on public.game_accounts for each row execute function public.set_updated_at();
create trigger shields_updated before update on public.shields for each row execute function public.set_updated_at();
create trigger devices_updated before update on public.user_devices for each row execute function public.set_updated_at();
create trigger preferences_updated before update on public.notification_preferences for each row execute function public.set_updated_at();

alter table public.app_users enable row level security;
alter table public.game_accounts enable row level security;
alter table public.shields enable row level security;
alter table public.user_devices enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_logs enable row level security;

create policy app_users_select on public.app_users for select using ((select auth.uid()) = id);
create policy app_users_insert on public.app_users for insert with check ((select auth.uid()) = id);
create policy app_users_update on public.app_users for update using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy app_users_delete on public.app_users for delete using ((select auth.uid()) = id);
do $$ declare t text; begin
  foreach t in array array['game_accounts','shields','user_devices','notification_preferences','notification_logs'] loop
    execute format('create policy %I_select on public.%I for select using ((select auth.uid()) = user_id)',t,t);
    execute format('create policy %I_insert on public.%I for insert with check ((select auth.uid()) = user_id)',t,t);
    execute format('create policy %I_update on public.%I for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)',t,t);
    execute format('create policy %I_delete on public.%I for delete using ((select auth.uid()) = user_id)',t,t);
  end loop;
end $$;

-- Also validates that a shield cannot be attached to another user's account.
create function public.validate_shield_owner() returns trigger language plpgsql set search_path = '' as $$
begin
  if not exists(select 1 from public.game_accounts where id = new.account_id and user_id = new.user_id) then
    raise exception 'Account ownership mismatch';
  end if;
  return new;
end; $$;
create trigger shield_owner before insert or update on public.shields for each row execute function public.validate_shield_owner();
