import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';

/// Premier écran vu par un utilisateur non connecté : logo dans une carte
/// blanche en haut, panneau dégradé en bas avec les boutons Se connecter /
/// S'inscrire.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ---------- Partie haute : logo dans une carte blanche ----------
          Expanded(
            flex: 5,
            child: Center(
              child: Container(
                width: 168, height: 168,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: AppTheme.elevatedShadow,
                ),
                child: Center(
                  child: Container(
                    width: 96, height: 96,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                    ),
                    child: const Icon(Icons.menu_book, size: 48, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          // ---------- Partie basse : panneau dégradé + boutons ----------
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
              ),
              // Défilable : en mode paysage la hauteur disponible est trop
              // juste pour le contenu, on évite ainsi le débordement.
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Flipbook',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Créez des flipbooks interactifs à partir de vos PDF, Word, PPT ou images, '
                      'et convertissez vos fichiers en un clic.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54, width: 1.4),
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                            ),
                            onPressed: () => _goToAuth(context, isSignUp: true),
                            child: const Text("S'inscrire"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.primaryDark,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                            ),
                            onPressed: () => _goToAuth(context, isSignUp: false),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text('Se connecter'),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToAuth(BuildContext context, {required bool isSignUp}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AuthScreen(initialSignUpMode: isSignUp)),
    );
  }
}
