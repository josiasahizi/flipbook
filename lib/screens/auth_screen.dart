import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/auth_error_messages.dart';
import '../theme/app_theme.dart';

/// Écran de connexion/inscription : bandeau dégradé en haut avec le titre,
/// carte blanche arrondie qui chevauche par-dessus avec les champs.
class AuthScreen extends StatefulWidget {
  final bool initialSignUpMode;

  const AuthScreen({super.key, this.initialSignUpMode = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _service = SupabaseService();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late bool _isSignUpMode = widget.initialSignUpMode;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Renseigne un email et un mot de passe.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUpMode) {
        await _service.signUpWithEmail(
          email, password,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte créé ! Vérifie ta boîte mail si la confirmation est activée.'),
            ),
          );
        }
      } else {
        await _service.signInWithEmail(email, password);
      }

      // Si une session est active (connexion réussie, ou inscription avec
      // confirmation email désactivée), on referme cet écran pour laisser
      // l'AuthGate (à la racine) afficher l'écran d'accueil. Sans ça, cet
      // écran restait affiché par-dessus jusqu'à un rafraîchissement manuel.
      if (mounted && _service.currentUser != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _errorMessage = friendlyAuthErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Renseigne d\'abord ton email ci-dessus.');
      return;
    }
    try {
      await _service.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email de réinitialisation envoyé.')),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = friendlyAuthErrorMessage(e));
    }
  }

  void _showComingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connexion $provider bientôt disponible.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // SizedBox.expand force le Stack à prendre toute la hauteur de l'écran.
      // Sans ça, un Stack se dimensionne uniquement sur son plus grand enfant
      // NON positionné (ici le bandeau, ~240px) et pas sur l'écran entier —
      // c'est ce qui causait la page blanche : le Positioned.fill n'avait
      // alors presque plus de place pour s'afficher.
      body: SizedBox.expand(
        child: Stack(
          children: [
            // ---------- Bandeau dégradé ----------
            Container(
              height: 240,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSignUpMode ? "S'inscrire" : 'Se connecter',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isSignUpMode
                                ? 'Crée ton compte pour commencer à créer des flipbooks.'
                                : 'Content de te revoir ! Connecte-toi pour continuer.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white.withOpacity(0.9)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ---------- Carte blanche qui chevauche ----------
            Positioned.fill(
              top: 190,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isSignUpMode) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _firstNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Prénom',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _lastNameController,
                                decoration: const InputDecoration(labelText: 'Nom'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      if (!_isSignUpMode) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _forgotPassword,
                            child: const Text('Mot de passe oublié ?'),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 14),
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isSignUpMode ? "S'inscrire" : 'Se connecter'),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('ou', style: Theme.of(context).textTheme.bodyMedium),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SocialButton(
                        label: 'Continuer avec Google',
                        badge: const _GoogleBadge(),
                        onTap: () => _showComingSoon('Google'),
                      ),
                      const SizedBox(height: 12),
                      _SocialButton(
                        label: 'Continuer avec Facebook',
                        badge: const _FacebookBadge(),
                        onTap: () => _showComingSoon('Facebook'),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => setState(() => _isSignUpMode = !_isSignUpMode),
                          child: Text(
                            _isSignUpMode
                                ? 'Déjà un compte ? Se connecter'
                                : "Pas encore de compte ? S'inscrire",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget badge;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textPrimary,
        side: const BorderSide(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          badge,
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

/// Badge circulaire "G" façon logo Google (sans utiliser l'image de marque
/// réelle — juste une représentation visuelle neutre).
class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22, height: 22,
      decoration: const BoxDecoration(color: Color(0xFFF1F1F1), shape: BoxShape.circle),
      child: const Center(
        child: Text('G', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }
}

/// Badge carré bleu "f" façon logo Facebook (représentation neutre).
class _FacebookBadge extends StatelessWidget {
  const _FacebookBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF1877F2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Text('f', style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
      ),
    );
  }
}
