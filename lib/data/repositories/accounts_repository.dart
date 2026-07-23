import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_failure.dart';
import '../../domain/models/models.dart';

class AccountsRepository {
  SupabaseClient get _client => SupabaseConfig.client;
  String get _userId => _client.auth.currentUser!.id;

  Future<List<GameAccount>> fetchAll() async {
    try {
      final rows = await _client
          .from('game_accounts')
          .select('*, shields(*)')
          .eq('user_id', _userId)
          .order('is_favorite', ascending: false)
          .order('created_at');
      return rows.map(GameAccount.fromJson).toList();
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<GameAccount> create({
    required String name,
    String player = '',
    String kingdom = '',
    String guild = '',
    int might = 0,
    int castleLevel = 0,
    String notes = '',
  }) async {
    try {
      final row = await _client
          .from('game_accounts')
          .insert({
            'user_id': _userId,
            'account_name': name,
            'player_name': player,
            'kingdom': kingdom,
            'guild_name': guild,
            'might': might,
            'castle_level': castleLevel == 0 ? null : castleLevel,
            'notes': notes,
          })
          .select()
          .single();
      return GameAccount.fromJson(row);
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<void> updateAccount(GameAccount account) async {
    try {
      await _client
          .from('game_accounts')
          .update({
            'account_name': account.name,
            'player_name': account.playerName,
            'kingdom': account.kingdom,
            'guild_name': account.guild,
            'might': account.might,
            'castle_level': account.castleLevel == 0
                ? null
                : account.castleLevel,
            'notes': account.notes,
            'is_favorite': account.isFavorite,
            'is_archived': account.isArchived,
          })
          .eq('id', account.id);
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<void> setFavorite(String id, bool value) =>
      _client.from('game_accounts').update({'is_favorite': value}).eq('id', id);
  Future<void> archive(String id) =>
      _client.from('game_accounts').update({'is_archived': true}).eq('id', id);
  Future<void> delete(String id) =>
      _client.from('game_accounts').delete().eq('id', id);

  Future<AccountCheckIn> checkIn(
    String accountId, {
    DateTime? playedAt,
    String notes = '',
  }) async {
    try {
      final row = await _client.rpc(
        'record_account_check_in',
        params: {
          'p_account_id': accountId,
          'p_played_at': (playedAt ?? DateTime.now()).toUtc().toIso8601String(),
          'p_notes': notes,
        },
      );
      return AccountCheckIn.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<List<AccountCheckIn>> fetchCheckIns(String accountId) async {
    try {
      final rows = await _client
          .from('account_check_ins')
          .select()
          .eq('user_id', _userId)
          .eq('account_id', accountId)
          .order('played_at', ascending: false)
          .limit(50);
      return rows.map(AccountCheckIn.fromJson).toList();
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<PlaySession> startPlaySession(List<String> accountIds) async {
    try {
      final row = await _client.rpc(
        'start_play_session',
        params: {'p_account_ids': accountIds},
      );
      return PlaySession.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<Shield> replaceShield(
    String accountId,
    Duration duration, {
    DateTime? startedAt,
    String notes = '',
  }) async {
    try {
      final row = await _client.rpc(
        'replace_account_shield',
        params: {
          'p_account_id': accountId,
          'p_duration_minutes': duration.inMinutes,
          'p_shield_type': duration.inHours >= 24
              ? '${duration.inDays} day'
              : '${duration.inHours} hours',
          'p_started_at': (startedAt ?? DateTime.now())
              .toUtc()
              .toIso8601String(),
          'p_notes': notes,
        },
      );
      return Shield.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<void> cancelShield(String shieldId) async {
    try {
      await _client
          .from('shields')
          .update({'status': 'cancelled'})
          .eq('id', shieldId);
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<List<ShieldHistoryEntry>> fetchShieldHistory() async {
    try {
      final rows = await _client
          .from('shields')
          .select('*, game_accounts(account_name)')
          .eq('user_id', _userId)
          .order('started_at', ascending: false);
      return rows.map(ShieldHistoryEntry.fromJson).toList();
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<void> deleteShield(String id) async {
    try {
      await _client.from('shields').delete().eq('id', id);
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }
}
