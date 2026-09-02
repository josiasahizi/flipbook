import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Onglet Profil : affiche prénom, nom et email de l'utilisateur connecté,
/// avec le bouton de déconnexion.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    final firstName = service.currentUserFirstName;
    final lastName = service.currentUserLastName;
    final email = service.currentUserEmail;
    final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final initial = firstName.isNotEmpty
        ? firstName[0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : '?');

    return Scaffold(
      appBar: AppBar(title: const Text('Profil'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient, shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (fullName.isNotEmpty)
            Text(
              fullName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          const SizedBox(height: 28),
          _InfoTile(
            icon: Icons.person_outline,
            label: 'Prénom',
            value: firstName.isNotEmpty ? firstName : 'Non renseigné',
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.badge_outlined,
            label: 'Nom',
            value: lastName.isNotEmpty ? lastName : 'Non renseigné',
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.mail_outline,
            label: 'Email',
            value: email.isNotEmpty ? email : 'Non renseigné',
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.error),
            ),
            onPressed: () async => await service.signOut(),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        title: Text(label, style: Theme.of(context).textTheme.labelMedium),
        subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
