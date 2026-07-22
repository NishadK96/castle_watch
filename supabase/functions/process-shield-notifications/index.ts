import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";

type Reminder = {
  type: "24h" | "6h" | "1h" | "15m" | "expired";
  flag: string;
  preference: string;
  label: string;
};

const reminders: Array<Reminder & { dueMinutes: number }> = [
  { type: "expired", flag: "notification_expired_sent", preference: "reminder_expired", label: "expired", dueMinutes: 0 },
  { type: "15m", flag: "notification_15m_sent", preference: "reminder_15m", label: "15 minutes", dueMinutes: 15 },
  { type: "1h", flag: "notification_1h_sent", preference: "reminder_1h", label: "1 hour", dueMinutes: 60 },
  { type: "6h", flag: "notification_6h_sent", preference: "reminder_6h", label: "6 hours", dueMinutes: 360 },
  { type: "24h", flag: "notification_24h_sent", preference: "reminder_24h", label: "24 hours", dueMinutes: 1440 },
];

Deno.serve(async (request) => {
  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const suppliedSecret = request.headers.get("x-cron-secret");
  const bearer = request.headers.get("authorization");
  if (suppliedSecret !== Deno.env.get("CRON_SECRET") && bearer !== `Bearer ${serviceKey}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(url, serviceKey, { auth: { persistSession: false } });
  const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")!);
  const auth = new JWT({ email: serviceAccount.client_email, key: serviceAccount.private_key, scopes: ["https://www.googleapis.com/auth/firebase.messaging"] });
  const credentials = await auth.authorize();
  const accessToken = credentials.access_token;
  const now = new Date();
  const horizon = new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString();
  const retryFloor = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();

  const { data: shields, error } = await supabase
    .from("shields")
    .select("*, game_accounts!inner(account_name)")
    .in("status", ["active", "expiring_soon", "expired"])
    .gte("expires_at", retryFloor)
    .lte("expires_at", horizon)
    .order("expires_at");
  if (error) throw error;

  let sent = 0;
  let failed = 0;
  for (const shield of shields ?? []) {
    const remainingMinutes = (new Date(shield.expires_at).getTime() - now.getTime()) / 60000;
    if (remainingMinutes <= 0 && shield.status !== "expired") {
      await supabase.from("shields").update({ status: "expired" }).eq("id", shield.id);
    } else if (remainingMinutes <= 1440 && shield.status === "active") {
      await supabase.from("shields").update({ status: "expiring_soon" }).eq("id", shield.id);
    }
    const reminder = reminders.find((item) => remainingMinutes <= item.dueMinutes && !shield[item.flag]);
    if (!reminder) continue;

    const [{ data: preferences }, { data: devices }, { data: existing }] = await Promise.all([
      supabase.from("notification_preferences").select().eq("user_id", shield.user_id).maybeSingle(),
      supabase.from("user_devices").select("id, device_token").eq("user_id", shield.user_id).eq("is_active", true),
      supabase.from("notification_logs").select("id, delivery_status").eq("shield_id", shield.id).eq("notification_type", reminder.type).maybeSingle(),
    ]);
    if (!preferences?.push_enabled || !preferences[reminder.preference] || !devices?.length || existing?.delivery_status === "sent") continue;

    const accountName = shield.game_accounts.account_name;
    const title = reminder.type === "expired" ? "Shield Expired" : "Shield Expiring Soon";
    const body = reminder.type === "expired"
      ? `The shield for “${accountName}” has expired.`
      : `Your shield for “${accountName}” will expire in ${reminder.label}.`;

    const logValues = { user_id: shield.user_id, account_id: shield.account_id, shield_id: shield.id, notification_type: reminder.type, title, body, delivery_status: "pending", error_message: null };
    const { data: log } = await supabase.from("notification_logs").upsert(logValues, { onConflict: "shield_id,notification_type" }).select("id").single();
    const results = await Promise.all(devices.map(async (device) => {
      const response = await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`, {
        method: "POST",
        headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json" },
        body: JSON.stringify({ message: { token: device.device_token, notification: { title, body }, data: { account_id: shield.account_id, shield_id: shield.id, notification_type: reminder.type } } }),
      });
      return { ok: response.ok, error: response.ok ? null : await response.text() };
    }));
    const success = results.some((result) => result.ok);
    const errorMessage = results.filter((result) => !result.ok).map((result) => result.error).join("; ").slice(0, 1000) || null;
    await supabase.from("notification_logs").update({ delivery_status: success ? "sent" : "failed", error_message: errorMessage, sent_at: success ? new Date().toISOString() : null }).eq("id", log.id);
    if (success) {
      await supabase.from("shields").update({ [reminder.flag]: true, ...(reminder.type === "expired" ? { status: "expired" } : {}) }).eq("id", shield.id);
      sent++;
    } else failed++;
  }

  return Response.json({ checked: shields?.length ?? 0, sent, failed });
});
