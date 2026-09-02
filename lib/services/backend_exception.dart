import 'dart:convert';
import 'package:http/http.dart' as http;

/// Erreur de communication avec le backend, avec un message déjà adapté
/// à l'affichage direct à l'utilisateur (pas besoin de le retraiter).
class BackendException implements Exception {
  final String message;
  BackendException(this.message);

  @override
  String toString() => message;
}

/// Envoie une requête multipart au backend et retourne son corps JSON
/// décodé en cas de succès. Distingue deux familles d'erreurs :
/// - impossible de joindre le serveur (réseau, backend éteint, mauvaise IP)
/// - le serveur a répondu mais avec une erreur (message déjà clair, fourni
///   par le backend — voir errorMessages.js côté serveur)
Future<Map<String, dynamic>> sendMultipartRequest(http.MultipartRequest request) async {
  http.Response response;
  try {
    final streamedResponse = await request.send();
    response = await http.Response.fromStream(streamedResponse);
  } on http.ClientException {
    throw BackendException(
      'Impossible de contacter le serveur. Vérifie que le backend est bien '
      'lancé sur ton PC, et que ton appareil est sur le même réseau Wi-Fi.',
    );
  } catch (_) {
    throw BackendException(
      'Impossible de contacter le serveur. Vérifie ta connexion et réessaie.',
    );
  }

  Map<String, dynamic> body;
  try {
    body = jsonDecode(response.body) as Map<String, dynamic>;
  } catch (_) {
    throw BackendException('Réponse invalide du serveur (${response.statusCode}).');
  }

  if (response.statusCode != 200) {
    throw BackendException(body['error'] as String? ?? 'Échec de la conversion.');
  }

  return body;
}
