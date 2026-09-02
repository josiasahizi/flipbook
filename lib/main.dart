import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

const String supabaseUrl = 'https://wbkoojrzxzfnkwjroobr.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6India29vanJ6eHpmbmt3anJvb2JyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3NzcxOTksImV4cCI6MjEwMTM1MzE5OX0.FLrq1mWKqQPA-wkXq9l5Qt7Se3dXDDhAOtscTTkNbBc';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const FlipbookApp());
}

class FlipbookApp extends StatelessWidget {
  const FlipbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flipbook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}

// Raccourci pour accéder au client Supabase depuis n'importe où dans l'app
final supabase = Supabase.instance.client;
