import '../models/flipbook.dart';

/// Version Web (sans effet) : le mode hors-ligne n'a pas de sens dans un
/// navigateur (pas d'accès à un système de fichiers local persistant de la
/// même façon que sur mobile/desktop). Toutes les méthodes indiquent
/// simplement "non disponible", sans planter.
class OfflineService {
  Future<bool> isAvailableOffline(String flipbookId) async => false;

  Future<String?> getOfflineIndexPath(String flipbookId) async => null;

  Future<void> downloadForOffline(
    Flipbook flipbook, {
    void Function(double progress)? onProgress,
  }) async {
    throw UnsupportedError('Le mode hors-ligne n\'est pas disponible sur le web.');
  }

  Future<void> removeOfflineCopy(String flipbookId) async {}

  Future<int> offlineSizeInBytes(String flipbookId) async => 0;
}
