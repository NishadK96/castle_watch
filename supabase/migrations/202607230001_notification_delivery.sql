-- One durable delivery record per shield/reminder prevents duplicate pushes.
create unique index if not exists notification_logs_shield_type_unique
  on public.notification_logs(shield_id, notification_type);

create index if not exists notification_due_shields_idx
  on public.shields(expires_at)
  where status in ('active', 'expiring_soon');

-- Run after deploying the process-shield-notifications Edge Function.
-- Store CRON_SECRET in Edge Function secrets and use the same value below.
-- Supabase Dashboard > Integrations > Cron can alternatively call the function
-- every 5 minutes without adding the pg_cron job manually.
