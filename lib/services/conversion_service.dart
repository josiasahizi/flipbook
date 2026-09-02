import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'backend_exception.dart';

/// ⚠️ Bascule ceci selon ce sur quoi tu testes :
/// - true  → émulateur Android (dans Android Studio)
/// - false → vrai téléphone Android/iOS sur le même Wi-Fi que ton PC
const bool _testingOnAndroidEmulator = true;

/// URL du backend Node.js.
/// - Windows et Web : l'app tourne sur le même PC que le backend, donc
///   'localhost' fonctionne directement.
/// - Émulateur Android : 'localhost' désigne l'émulateur lui-même, pas ton
///   PC — Android fournit l'adresse spéciale 10.0.2.2 qui redirige vers le
///   'localhost' de la machine hôte.
/// - Vrai téléphone (appareil physique) : il faut l'adresse IP locale du PC
///   sur le même réseau Wi-Fi — remplace la valeur ci-dessous par la
///   tienne (trouvable via `ipconfig` sur le PC qui fait tourner le backend).
String get backendBaseUrl {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
    return 'http://localhost:3000';
  }
  if (_testingOnAndroidEmulator) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://192.168.100.32:3000';
}

/// Résultat renvoyé par le backend après conversion d'un fichier (ou
/// fusion de plusieurs images).
class ConversionResult {
  final String flipbookId;
  final List<String> pageUrls;
  final String? pdfUrl; // null si aucun PDF n'est disponible au téléchargement

  ConversionResult({required this.flipbookId, required this.pageUrls, this.pdfUrl});

  factory ConversionResult.fromJson(Map<String, dynamic> json) {
    return ConversionResult(
      flipbookId: json['flipbookId'] as String,
      pageUrls: List<String>.from(json['pageUrls'] as List),
      pdfUrl: json['pdfUrl'] as String?,
    );
  }
}

/// Représente un fichier à envoyer (nom + contenu binaire), utilisé pour
/// l'envoi de plusieurs images en une seule requête.
class PickedFileData {
  final String fileName;
  final Uint8List bytes;

  PickedFileData({required this.fileName, required this.bytes});
}

/// Envoie un fichier (ou plusieurs images) au backend et récupère les
/// URLs des pages converties, ainsi que l'URL du PDF si disponible.
class ConversionService {
  /// Convertit UN fichier (PDF, Word, PPT, TXT, EPUB, image) en flipbook.
  Future<ConversionResult> convertFile(String fileName, Uint8List bytes) async {
    final uri = Uri.parse('$backendBaseUrl/convert');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    return _sendAndParse(request);
  }

  /// Fusionne PLUSIEURS images en un seul PDF, puis crée le flipbook
  /// correspondant. L'ordre de la liste détermine l'ordre des pages.
  Future<ConversionResult> convertImages(List<PickedFileData> images) async {
    final uri = Uri.parse('$backendBaseUrl/convert-images');
    final request = http.MultipartRequest('POST', uri);

    for (final image in images) {
      request.files.add(
        http.MultipartFile.fromBytes('images', image.bytes, filename: image.fileName),
      );
    }

    return _sendAndParse(request);
  }

  Future<ConversionResult> _sendAndParse(http.MultipartRequest request) async {
    final body = await sendMultipartRequest(request);
    return ConversionResult.fromJson(body);
  }
}
