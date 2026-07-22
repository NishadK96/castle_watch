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
          })
          .select()
          .single();
      return GameAccount.fromJson(row);
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

  Future<Shield> replaceShield(String accountId, Duration duration) async {
    try {
      final row = await _client.rpc(
        'replace_account_shield',
        params: {
          'p_account_id': accountId,
          'p_duration_minutes': duration.inMinutes,
          'p_shield_type': duration.inHours >= 24
              ? '${duration.inDays} day'
              : '${duration.inHours} hours',
        },
      );
      return Shield.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }
}
