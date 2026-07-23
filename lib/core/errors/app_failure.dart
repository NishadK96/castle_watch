import 'package:supabase_flutter/supabase_flutter.dart';

class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
  @override
  String toString() => message;

  static AppFailure friendly(Object error) {
    if (error is AuthException) {
      final message = error.message;
      if (message.toLowerCase().contains('invalid login')) {
        return const AppFailure('Incorrect email or password.');
      }
      return AppFailure(message);
    }
    if (error is PostgrestException) {
      return AppFailure(
        [
          error.message,
          error.details,
          error.hint,
        ].whereType<String>().where((value) => value.isNotEmpty).join(' — '),
      );
    }
    final value = error.toString().toLowerCase();
    if (value.contains('invalid login')) {
      return const AppFailure('Incorrect email or password.');
    }
    if (value.contains('already registered')) {
      return const AppFailure('An account already exists for this email.');
    }
    if (value.contains('network') || value.contains('socket')) {
      return const AppFailure(
        'You appear to be offline. Check your connection and retry.',
      );
    }
    return const AppFailure('Something went wrong. Please try again.');
  }
}
