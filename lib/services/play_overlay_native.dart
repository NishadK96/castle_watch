import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/config/supabase_config.dart';
import '../domain/models/models.dart';

abstract final class PlayOverlay {
  static const _channel = MethodChannel('castle_watch/play_overlay');

  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> start(
    PlaySession session,
    List<GameAccount> accounts,
  ) async {
    if (!isSupported) return false;
    final allowed = await _channel.invokeMethod<bool>('canDraw') ?? false;
    if (!allowed) {
      await _channel.invokeMethod<void>('requestPermission');
      return false;
    }
    await _channel.invokeMethod<void>('start', {
      'sessionId': session.id,
      'secret': session.secret,
      'supabaseUrl': SupabaseConfig.url,
      'anonKey': SupabaseConfig.anonKey,
      'accounts': [
        for (final account in accounts)
          {'id': account.id, 'name': account.name},
      ],
    });
    return true;
  }
}
