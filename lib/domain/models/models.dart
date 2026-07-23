enum ShieldState { safe, attention, warning, critical, expired, none }

class Shield {
  const Shield({
    required this.id,
    required this.accountId,
    required this.startedAt,
    required this.expiresAt,
    required this.type,
    this.status = 'active',
    this.durationMinutes = 0,
    this.notes = '',
  });
  final String id;
  final String accountId;
  final DateTime startedAt;
  final DateTime expiresAt;
  final String type;
  final String status;
  final int durationMinutes;
  final String notes;
  factory Shield.fromJson(Map<String, dynamic> json) => Shield(
    id: json['id'] as String,
    accountId: json['account_id'] as String,
    startedAt: DateTime.parse(json['started_at'] as String).toUtc(),
    expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
    type: json['shield_type'] as String,
    status: json['status'] as String? ?? 'active',
    durationMinutes: json['duration_minutes'] as int? ?? 0,
    notes: json['notes'] as String? ?? '',
  );
  Duration remaining(DateTime now) => expiresAt.difference(now);
  ShieldState state(DateTime now) {
    final value = remaining(now);
    if (value <= Duration.zero) return ShieldState.expired;
    if (value <= const Duration(hours: 1)) return ShieldState.critical;
    if (value <= const Duration(hours: 6)) return ShieldState.warning;
    if (value <= const Duration(hours: 24)) return ShieldState.attention;
    return ShieldState.safe;
  }
}

class GameAccount {
  const GameAccount({
    required this.id,
    required this.name,
    this.playerName = '',
    this.kingdom = '',
    this.guild = '',
    this.might = 0,
    this.castleLevel = 0,
    this.isFavorite = false,
    this.isArchived = false,
    this.notes = '',
    this.lastPlayedAt,
    this.shield,
  });
  final String id;
  final String name;
  final String playerName;
  final String kingdom;
  final String guild;
  final int might;
  final int castleLevel;
  final bool isFavorite;
  final bool isArchived;
  final String notes;
  final DateTime? lastPlayedAt;
  final Shield? shield;
  factory GameAccount.fromJson(Map<String, dynamic> json) {
    final shields =
        (json['shields'] as List<dynamic>? ?? [])
            .map(
              (item) => Shield.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .where(
              (item) =>
                  item.status == 'active' || item.status == 'expiring_soon',
            )
            .toList()
          ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return GameAccount(
      id: json['id'] as String,
      name: json['account_name'] as String,
      playerName: json['player_name'] as String? ?? '',
      kingdom: json['kingdom'] as String? ?? '',
      guild: json['guild_name'] as String? ?? '',
      might: json['might'] as int? ?? 0,
      castleLevel: json['castle_level'] as int? ?? 0,
      isFavorite: json['is_favorite'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      lastPlayedAt: json['last_played_at'] == null
          ? null
          : DateTime.parse(json['last_played_at'] as String).toUtc(),
      shield: shields.firstOrNull,
    );
  }
  GameAccount copyWith({
    String? name,
    String? playerName,
    String? kingdom,
    String? guild,
    int? might,
    int? castleLevel,
    bool? isFavorite,
    bool? isArchived,
    String? notes,
    DateTime? lastPlayedAt,
    Shield? shield,
    bool clearShield = false,
  }) => GameAccount(
    id: id,
    name: name ?? this.name,
    playerName: playerName ?? this.playerName,
    kingdom: kingdom ?? this.kingdom,
    guild: guild ?? this.guild,
    might: might ?? this.might,
    castleLevel: castleLevel ?? this.castleLevel,
    isFavorite: isFavorite ?? this.isFavorite,
    isArchived: isArchived ?? this.isArchived,
    notes: notes ?? this.notes,
    lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    shield: clearShield ? null : shield ?? this.shield,
  );
}

enum PlayStatus { recent, dueSoon, overdue, never }

extension GameAccountPlayStatus on GameAccount {
  PlayStatus playStatus(DateTime now) {
    final played = lastPlayedAt;
    if (played == null) return PlayStatus.never;
    final age = now.difference(played);
    if (age >= const Duration(hours: 24)) return PlayStatus.overdue;
    if (age >= const Duration(hours: 18)) return PlayStatus.dueSoon;
    return PlayStatus.recent;
  }
}

class AccountCheckIn {
  const AccountCheckIn({
    required this.id,
    required this.accountId,
    required this.playedAt,
    this.notes = '',
  });

  final String id;
  final String accountId;
  final DateTime playedAt;
  final String notes;

  factory AccountCheckIn.fromJson(Map<String, dynamic> json) => AccountCheckIn(
    id: json['id'] as String,
    accountId: json['account_id'] as String,
    playedAt: DateTime.parse(json['played_at'] as String).toUtc(),
    notes: json['notes'] as String? ?? '',
  );
}

class ShieldHistoryEntry {
  const ShieldHistoryEntry({required this.shield, required this.accountName});
  final Shield shield;
  final String accountName;
  factory ShieldHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ShieldHistoryEntry(
        shield: Shield.fromJson(json),
        accountName:
            (json['game_accounts'] as Map<String, dynamic>?)?['account_name']
                as String? ??
            'Unknown account',
      );
}
