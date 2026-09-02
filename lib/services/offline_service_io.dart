import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/flipbook.dart';

/// Gère le téléchargement d'un flipbook pour une lecture 100% hors-ligne :
/// copie la bibliothèque du lecteur (StPageFlip) en local, télécharge
/// chaque page, et génère un index.html autonome référençant uniquement
/// des fichiers locaux (aucune requête réseau nécessaire à la lecture).
class OfflineService {
  Future<Directory> _flipbookDir(String flipbookId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/offline_flipbooks/$flipbookId');
    return dir;
  }

  /// Chemin du fichier "marqueur" indiquant que le téléchargement est
  /// complet (évite de considérer un téléchargement interrompu comme valide).
  String _completeMarkerPath(Directory dir) => '${dir.path}/.complete';

  /// Vrai si ce flipbook est déjà entièrement disponible hors-ligne.
  Future<bool> isAvailableOffline(String flipbookId) async {
    final dir = await _flipbookDir(flipbookId);
    return File(_completeMarkerPath(dir)).exists();
  }

  /// Chemin local de l'index.html à charger dans la WebView, si disponible.
  Future<String?> getOfflineIndexPath(String flipbookId) async {
    final available = await isAvailableOffline(flipbookId);
    if (!available) return null;
    final dir = await _flipbookDir(flipbookId);
    return '${dir.path}/index.html';
  }

  /// Télécharge tout ce qu'il faut pour lire ce flipbook hors-ligne :
  /// bibliothèque StPageFlip (copiée depuis les assets de l'app) + chaque
  /// page (téléchargée depuis Supabase) + un index.html généré localement.
  ///
  /// [onProgress] reçoit une valeur entre 0.0 et 1.0.
  Future<void> downloadForOffline(
    Flipbook flipbook, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await _flipbookDir(flipbook.id);
    await dir.create(recursive: true);
    final libDir = Directory('${dir.path}/lib');
    await libDir.create(recursive: true);

    // 1. Copie la bibliothèque du lecteur depuis les assets de l'app
    final jsBytes = await rootBundle.load('assets/flipbook_viewer/lib/page-flip.browser.js');
    await File('${libDir.path}/page-flip.browser.js')
        .writeAsBytes(jsBytes.buffer.asUint8List());
    final cssBytes = await rootBundle.load('assets/flipbook_viewer/lib/page-flip.css');
    await File('${libDir.path}/page-flip.css').writeAsBytes(cssBytes.buffer.asUint8List());

    onProgress?.call(0.1);

    // 2. Télécharge chaque page (avec un peu de parallélisme pour la vitesse)
    final total = flipbook.pageImageUrls.length;
    var completed = 0;
    const concurrency = 4;

    for (var i = 0; i < total; i += concurrency) {
      final batch = <Future<void>>[];
      for (var j = i; j < total && j < i + concurrency; j++) {
        final url = flipbook.pageImageUrls[j];
        final index = j;
        batch.add(() async {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode != 200) {
            throw Exception('Échec du téléchargement de la page ${index + 1}');
          }
          // L'extension locale suit le format réel de la page (PNG pour les
          // images originales re-uploadées, JPG pour les pages converties)
          final ext = url.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
          await File('${dir.path}/page-${index + 1}$ext').writeAsBytes(response.bodyBytes);
          completed++;
          onProgress?.call(0.1 + (completed / total) * 0.8);
        }());
      }
      await Future.wait(batch);
    }

    // 3. Génère l'index.html avec les chemins locaux (relatifs, dans le
    // même dossier que ce fichier — c'est ce que OfflineWebView chargera).
    // Même logique d'extension qu'au téléchargement ci-dessus.
    final template = await rootBundle.loadString('assets/flipbook_viewer/offline_template.html');
    final localPageNames = List.generate(total, (i) {
      final url = flipbook.pageImageUrls[i];
      return 'page-${i + 1}${url.toLowerCase().endsWith('.png') ? '.png' : '.jpg'}';
    });
    final html = template.replaceFirst('%%PAGES_JSON%%', jsonEncode(localPageNames));
    await File('${dir.path}/index.html').writeAsString(html);

    // 4. Marqueur de complétion — signale que tout est prêt
    await File(_completeMarkerPath(dir)).writeAsString('ok');

    onProgress?.call(1.0);
  }

  /// Supprime la copie hors-ligne d'un flipbook (libère l'espace utilisé).
  Future<void> removeOfflineCopy(String flipbookId) async {
    final dir = await _flipbookDir(flipbookId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Taille approximative (en octets) occupée par la copie hors-ligne,
  /// ou 0 si elle n'existe pas.
  Future<int> offlineSizeInBytes(String flipbookId) async {
    final dir = await _flipbookDir(flipbookId);
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}
