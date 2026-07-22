import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_failure.dart';

class AuthRepository {
  SupabaseClient get _client => SupabaseConfig.client;
  Session? get currentSession =>
      SupabaseConfig.isConfigured ? _client.auth.currentSession : null;
  Stream<AuthState> get changes => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<void> signOut() => _client.auth.signOut();
}
