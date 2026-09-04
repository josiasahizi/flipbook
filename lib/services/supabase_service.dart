import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flipbook.dart';

/// Exception explicite pour le cas "email déjà utilisé à l'inscription" —
/// Supabase ne lève pas d'erreur classique pour ça (voir signUpWithEmail),
/// donc on la simule nous-mêmes pour que l'UI puisse afficher un message clair.
class EmailAlreadyRegisteredException implements Exception {
  @override
  String toString() => 'email_already_registered';
}

/// Centralise toutes les interactions avec Supabase pour l'application.
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // ---------- AUTH ----------

  User? get currentUser => _client.auth.currentUser;

  String get currentUserFirstName =>
      (currentUser?.userMetadata?['first_name'] as String?) ?? '';
  String get currentUserLastName =>
      (currentUser?.userMetadata?['last_name'] as String?) ?? '';
  String get currentUserEmail => currentUser?.email ?? '';

  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// ⚠️ Par sécurité (pour empêcher de deviner quels emails sont déjà
  /// inscrits), Supabase NE renvoie PAS d'erreur quand on s'inscrit avec un
  /// email déjà existant — il renvoie une réponse qui ressemble à un succès.
  /// La façon documentée de détecter ce cas est de vérifier que le champ
  /// `identities` de l'utilisateur retourné est vide : c'est le signe
  /// qu'aucun nouveau compte n'a réellement été créé.
  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? firstName,
    String? lastName,
  }) async {
    final data = <String, dynamic>{};
    if (firstName != null && firstName.isNotEmpty) data['first_name'] = firstName;
    if (lastName != null && lastName.isNotEmpty) data['last_name'] = lastName;

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: data.isNotEmpty ? data : null,
    );

    final identities = response.user?.identities;
    if (identities != null && identities.isEmpty) {
      throw EmailAlreadyRegisteredException();
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ---------- STORAGE ----------

  /// Envoie le fichier original (PDF/Word/PPT/image) vers le bucket 'uploads'.
  /// Retourne le chemin du fichier stocké, à transmettre au backend pour conversion.
  Future<String> uploadOriginalFile(String fileName, Uint8List bytes) async {
    final path = '${currentUser!.id}/$fileName';
    await _client.storage.from('uploads').uploadBinary(path, bytes);
    return path;
  }

  // ---------- BASE DE DONNÉES (table 'flipbooks') ----------

  Future<List<Flipbook>> fetchMyFlipbooks() async {
    final data = await _client
        .from('flipbooks')
        .select()
        .eq('owner_id', currentUser!.id)
        .order('created_at', ascending: false);

    return (data as List).map((row) => Flipbook.fromMap(row)).toList();
  }

  Future<Flipbook> createFlipbook({
    required String title,
    required List<String> pageImageUrls,
    String? pdfUrl,
    bool isPublic = false,
  }) async {
    final row = await _client
        .from('flipbooks')
        .insert({
          'title': title,
          'owner_id': currentUser!.id,
          'page_image_urls': pageImageUrls,
          'pdf_url': pdfUrl,
          'is_public': isPublic,
        })
        .select()
        .single();

    return Flipbook.fromMap(row);
  }

  Future<void> renameFlipbook(String id, String newTitle) async {
    await _client.from('flipbooks').update({'title': newTitle}).eq('id', id);
  }

  /// Lit le compteur permanent de flipbooks créés (jamais décrémenté à la
  /// suppression), les places bonus débloquées (pub, premium...), et le
  /// statut premium. Retourne les valeurs par défaut si l'utilisateur n'a
  /// encore aucune ligne de stats.
  Future<({int createdCount, int bonusSlots, bool isPremium})> fetchUserStats() async {
    final rows = await _client
        .from('user_stats')
        .select()
        .eq('user_id', currentUser!.id)
        .limit(1);

    if (rows.isEmpty) return (createdCount: 0, bonusSlots: 0, isPremium: false);
    final row = rows.first;
    return (
      createdCount: row['flipbooks_created_count'] as int? ?? 0,
      bonusSlots: row['bonus_slots'] as int? ?? 0,
      isPremium: row['is_premium'] as bool? ?? false,
    );
  }

  /// Supprime un flipbook (ligne en base + fichiers associés dans le
  /// Storage : pages et PDF éventuel).
  Future<void> deleteFlipbook(Flipbook flipbook) async {
    await _client.from('flipbooks').delete().eq('id', flipbook.id);

    // Nettoyage best-effort du Storage — on ignore les erreurs ici pour ne
    // pas bloquer la suppression si un fichier a déjà disparu.
    try {
      final pageFiles = await _client.storage
          .from('flipbook-pages')
          .list(path: 'pages/${flipbook.id}');
      if (pageFiles.isNotEmpty) {
        await _client.storage.from('flipbook-pages').remove(
              pageFiles.map((f) => 'pages/${flipbook.id}/${f.name}').toList(),
            );
      }
      if (flipbook.pdfUrl != null) {
        final pdfFiles = await _client.storage
            .from('flipbook-pages')
            .list(path: 'pdfs/${flipbook.id}');
        if (pdfFiles.isNotEmpty) {
          await _client.storage.from('flipbook-pages').remove(
                pdfFiles.map((f) => 'pdfs/${flipbook.id}/${f.name}').toList(),
              );
        }
      }
    } catch (_) {
      // Le nettoyage du storage est secondaire — la ligne en base est déjà supprimée.
    }
  }

  // ============================================================
  // BOOKMARKS (signets)
  // ============================================================

  /// Récupère tous les signets de l'utilisateur pour un flipbook donné.
  /// Triés par numéro de page ascendant.
  Future<List<Bookmark>> fetchBookmarks(String flipbookId) async {
    final data = await _client
        .from('bookmarks')
        .select('id, flipbook_id, page, note, created_at')
        .eq('flipbook_id', flipbookId)
        .order('page', ascending: true);

    return (data as List).map((m) => Bookmark.fromMap(m)).toList();
  }

  /// Ajoute un signet pour l'utilisateur courant sur un flipbook.
  /// [page] est 1-based. [note] optionnelle.
  /// Retourne le signet créé.
  Future<Bookmark> addBookmark({
    required String flipbookId,
    required int page,
    String? note,
  }) async {
    if (page < 1) throw ArgumentError('page doit être > 0');

    final data = await _client
        .from('bookmarks')
        .insert({
          'flipbook_id': flipbookId,
          'user_id': currentUser!.id,
          'page': page,
          'note': note,
        })
        .select('id, flipbook_id, page, note, created_at')
        .single();

    return Bookmark.fromMap(data);
  }

  /// Supprime un signet par son ID (vérifie implicitement l'appartenance via RLS).
  Future<void> removeBookmark(String bookmarkId) async {
    await _client.from('bookmarks').delete().eq('id', bookmarkId);
  }
}
