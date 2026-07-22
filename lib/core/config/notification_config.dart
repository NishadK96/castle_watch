abstract final class NotificationConfig {
  static const webVapidKey = String.fromEnvironment('WEB_VAPID_KEY');
  static bool get hasWebVapidKey =>
      webVapidKey.isNotEmpty && !webVapidKey.startsWith('your-');
}
