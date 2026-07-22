import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../core/config/supabase_config.dart';
import '../core/errors/app_failure.dart';
import '../data/repositories/accounts_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../domain/models/models.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());
final accountsRepositoryProvider = Provider((ref) => AccountsRepository());
final accountErrorProvider = StateProvider<String?>((ref) => null);
final accountsLoadingProvider = StateProvider<bool>((ref) => false);

final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now().toUtc(),
  );
});
final accountsProvider = NotifierProvider<AccountsNotifier, List<GameAccount>>(
  AccountsNotifier.new,
);

class AccountsNotifier extends Notifier<List<GameAccount>> {
  static const _uuid = Uuid();
  @override
  List<GameAccount> build() {
    if (SupabaseConfig.isConfigured &&
        SupabaseConfig.client.auth.currentUser != null) {
      Future<void>.microtask(refresh);
      return const [];
    }
    if (!SupabaseConfig.demoMode) return const [];
    final now = DateTime.now().toUtc();
    return [
      GameAccount(
        id: '1',
        name: 'Iron Citadel',
        playerName: 'Astra V',
        kingdom: 'K:714',
        guild: 'NOVA',
        might: 1284000000,
        castleLevel: 25,
        isFavorite: true,
        shield: Shield(
          id: 's1',
          accountId: '1',
          startedAt: now.subtract(const Duration(hours: 19)),
          expiresAt: now.add(const Duration(hours: 5, minutes: 42)),
          type: '24 hour',
        ),
      ),
      GameAccount(
        id: '2',
        name: 'Ember Keep',
        playerName: 'Kael',
        kingdom: 'K:826',
        guild: 'VANG',
        might: 782000000,
        castleLevel: 25,
        shield: Shield(
          id: 's2',
          accountId: '2',
          startedAt: now.subtract(const Duration(days: 1)),
          expiresAt: now.add(const Duration(days: 2, hours: 8)),
          type: '3 day',
        ),
      ),
      const GameAccount(
        id: '3',
        name: 'Frost Outpost',
        playerName: 'Lyra',
        kingdom: 'K:714',
        guild: 'NOVA',
        might: 346000000,
        castleLevel: 24,
      ),
    ];
  }

  Future<void> refresh() async {
    if (!SupabaseConfig.isConfigured) return;
    ref.read(accountsLoadingProvider.notifier).state = true;
    ref.read(accountErrorProvider.notifier).state = null;
    try {
      state = await ref.read(accountsRepositoryProvider).fetchAll();
    } on AppFailure catch (error) {
      ref.read(accountErrorProvider.notifier).state = error.message;
    } finally {
      ref.read(accountsLoadingProvider.notifier).state = false;
    }
  }

  void addAccount({
    required String name,
    String player = '',
    String kingdom = '',
    String guild = '',
  }) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final account = await ref
            .read(accountsRepositoryProvider)
            .create(name: name, player: player, kingdom: kingdom, guild: guild);
        state = [...state, account];
      } on AppFailure catch (error) {
        ref.read(accountErrorProvider.notifier).state = error.message;
      }
      return;
    }
    if (!SupabaseConfig.demoMode) return;
    state = [
      ...state,
      GameAccount(
        id: _uuid.v4(),
        name: name,
        playerName: player,
        kingdom: kingdom,
        guild: guild,
      ),
    ];
  }

  Future<void> toggleFavorite(String id) async {
    final account = state.firstWhere((item) => item.id == id);
    state = [
      for (final a in state)
        a.id == id ? a.copyWith(isFavorite: !a.isFavorite) : a,
    ];
    if (SupabaseConfig.isConfigured) {
      await ref
          .read(accountsRepositoryProvider)
          .setFavorite(id, !account.isFavorite);
    }
  }

  Future<void> archive(String id) async {
    state = [
      for (final a in state) a.id == id ? a.copyWith(isArchived: true) : a,
    ];
    if (SupabaseConfig.isConfigured) {
      await ref.read(accountsRepositoryProvider).archive(id);
    }
  }

  Future<void> delete(String id) async {
    final previous = state;
    state = state.where((a) => a.id != id).toList();
    if (SupabaseConfig.isConfigured) {
      try {
        await ref.read(accountsRepositoryProvider).delete(id);
      } catch (_) {
        state = previous;
        rethrow;
      }
    }
  }

  Future<void> addShield(String accountId, Duration duration) async {
    if (!SupabaseConfig.isConfigured && !SupabaseConfig.demoMode) return;
    final now = DateTime.now().toUtc();
    final shield = SupabaseConfig.isConfigured
        ? await ref
              .read(accountsRepositoryProvider)
              .replaceShield(accountId, duration)
        : Shield(
            id: _uuid.v4(),
            accountId: accountId,
            startedAt: now,
            expiresAt: now.add(duration),
            type: duration.inHours >= 24
                ? '${duration.inDays} day'
                : '${duration.inHours} hours',
          );
    state = [
      for (final a in state) a.id == accountId ? a.copyWith(shield: shield) : a,
    ];
  }
}
