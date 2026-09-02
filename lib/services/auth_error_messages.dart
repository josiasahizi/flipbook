/// Transforme une erreur d'authentification Supabase (souvent longue et
/// très technique, du type "AuthRetryableFetchException(message: ...)")
/// en message clair, court, et professionnel à afficher directement dans
/// l'app.
String friendlyAuthErrorMessage(Object error) {
  final raw = error.toString().toLowerCase();

  // Cas particulier : email déjà inscrit (détecté via EmailAlreadyRegisteredException
  // dans SupabaseService, car Supabase ne lève pas d'erreur classique pour ça)
  if (raw.contains('email_already_registered')) {
    return 'Un compte existe déjà avec cet email. Essaie plutôt de te connecter.';
  }

  // Connexion réseau / serveur injoignable
  if (raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('clientexception') ||
      raw.contains('connection refused') ||
      raw.contains('retryablefetch') ||
      raw.contains('timeoutexception')) {
    return 'Impossible de se connecter au serveur. Vérifie ta connexion '
        'internet et réessaie.';
  }

  // Identifiants invalides
  if (raw.contains('invalid login credentials') || raw.contains('invalid_credentials')) {
    return 'Email ou mot de passe incorrect.';
  }

  // Compte déjà existant (à l'inscription)
  if (raw.contains('user already registered') ||
      raw.contains('already registered') ||
      raw.contains('user_already_exists')) {
    return 'Un compte existe déjà avec cet email. Essaie plutôt de te connecter.';
  }

  // Email non confirmé
  if (raw.contains('email not confirmed')) {
    return 'Confirme ton email avant de te connecter (vérifie ta boîte de réception).';
  }

  // Mot de passe trop court/faible
  if (raw.contains('password should be at least') ||
      raw.contains('password is too short') ||
      raw.contains('weak_password')) {
    return 'Le mot de passe doit contenir au moins 6 caractères.';
  }

  // Email invalide
  if (raw.contains('unable to validate email') ||
      raw.contains('invalid email') ||
      raw.contains('invalid_email')) {
    return 'Adresse email invalide.';
  }

  // Trop de tentatives
  if (raw.contains('rate limit') ||
      raw.contains('too many requests') ||
      raw.contains('for security purposes')) {
    return 'Trop de tentatives. Patiente quelques instants avant de réessayer.';
  }

  // Utilisateur introuvable
  if (raw.contains('user not found')) {
    return 'Aucun compte trouvé avec cet email.';
  }

  // Repli générique — on n'affiche jamais le message technique brut
  return 'Une erreur est survenue. Réessaie dans quelques instants.';
}
