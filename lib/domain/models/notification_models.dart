class NotificationPreferences {
  const NotificationPreferences({
    this.pushEnabled = true,
    this.reminder24h = true,
    this.reminder6h = true,
    this.reminder1h = true,
    this.reminder15m = true,
    this.reminderExpired = true,
  });

  final bool pushEnabled;
  final bool reminder24h;
  final bool reminder6h;
  final bool reminder1h;
  final bool reminder15m;
  final bool reminderExpired;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        pushEnabled: json['push_enabled'] as bool? ?? true,
        reminder24h: json['reminder_24h'] as bool? ?? true,
        reminder6h: json['reminder_6h'] as bool? ?? true,
        reminder1h: json['reminder_1h'] as bool? ?? true,
        reminder15m: json['reminder_15m'] as bool? ?? true,
        reminderExpired: json['reminder_expired'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'push_enabled': pushEnabled,
    'reminder_24h': reminder24h,
    'reminder_6h': reminder6h,
    'reminder_1h': reminder1h,
    'reminder_15m': reminder15m,
    'reminder_expired': reminderExpired,
  };

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? reminder24h,
    bool? reminder6h,
    bool? reminder1h,
    bool? reminder15m,
    bool? reminderExpired,
  }) => NotificationPreferences(
    pushEnabled: pushEnabled ?? this.pushEnabled,
    reminder24h: reminder24h ?? this.reminder24h,
    reminder6h: reminder6h ?? this.reminder6h,
    reminder1h: reminder1h ?? this.reminder1h,
    reminder15m: reminder15m ?? this.reminder15m,
    reminderExpired: reminderExpired ?? this.reminderExpired,
  );
}

class NotificationLog {
  const NotificationLog({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    this.sentAt,
  });
  final String id;
  final String type;
  final String title;
  final String body;
  final String status;
  final DateTime createdAt;
  final DateTime? sentAt;

  factory NotificationLog.fromJson(Map<String, dynamic> json) =>
      NotificationLog(
        id: json['id'] as String,
        type: json['notification_type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        status: json['delivery_status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        sentAt: json['sent_at'] == null
            ? null
            : DateTime.parse(json['sent_at'] as String).toLocal(),
      );
}
