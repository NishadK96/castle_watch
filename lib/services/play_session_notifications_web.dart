import 'dart:js_interop';

import '../core/config/supabase_config.dart';
import '../domain/models/models.dart';

@JS('castleWatchShowPlaySession')
external JSPromise<JSAny?> _showPlaySession(
  JSString sessionId,
  JSString secret,
  JSString accountName,
  JSNumber position,
  JSNumber total,
  JSString supabaseUrl,
  JSString anonKey,
);

abstract final class PlaySessionNotifications {
  static Future<void> initialize() async {}
  static bool consumePickerRequest() => false;

  static Future<void> show(PlaySession session) async {
    await _showPlaySession(
      session.id.toJS,
      session.secret.toJS,
      session.accountName.toJS,
      session.position.toJS,
      session.total.toJS,
      SupabaseConfig.url.toJS,
      SupabaseConfig.anonKey.toJS,
    ).toDart;
  }
}
