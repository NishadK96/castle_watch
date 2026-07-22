# Shield notification worker

Set secrets before deployment:

```sh
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
supabase secrets set CRON_SECRET='a-long-random-value'
supabase functions deploy process-shield-notifications
```

Schedule the function every five minutes from Supabase Dashboard → Integrations
→ Cron. Send `x-cron-secret` with the configured `CRON_SECRET` value.

Firebase service-account credentials stay in Edge Function secrets and must
never be added to Flutter or committed to Git.
