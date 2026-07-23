import '../domain/models/models.dart';

abstract final class PlayOverlay {
  static bool get isSupported => false;
  static Future<bool> start(
    PlaySession session,
    List<GameAccount> accounts,
  ) async => false;
}
