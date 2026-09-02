/// Point d'entrée public pour le mode hors-ligne. Choisit automatiquement
/// la bonne implémentation à la compilation :
/// - offline_service_io.dart (dart:io) sur Android/iOS/Windows/macOS/Linux
/// - offline_service_web.dart (sans effet) sur Web
///
/// C'est nécessaire car dart:io ne compile pas du tout pour le web — un
/// simple test "if (kIsWeb)" à l'exécution ne suffit pas, il faut ce
/// mécanisme d'import conditionnel résolu à la compilation.
export 'offline_service_stub.dart'
    if (dart.library.io) 'offline_service_io.dart';
