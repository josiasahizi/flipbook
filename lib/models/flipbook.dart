/// Représente un flipbook stocké dans la base de données Supabase.
class Flipbook {
  final String id;
  final String title;
  final String ownerId;
  final List<String> pageImageUrls; // URLs des images de chaque page
  final String? pdfUrl; // URL du PDF téléchargeable (null si non disponible)
  final bool isPublic;
  final DateTime createdAt;

  Flipbook({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.pageImageUrls,
    this.pdfUrl,
    required this.isPublic,
    required this.createdAt,
  });

  /// Construit un Flipbook à partir d'une ligne renvoyée par Supabase.
  factory Flipbook.fromMap(Map<String, dynamic> map) {
    return Flipbook(
      id: map['id'] as String,
      title: map['title'] as String,
      ownerId: map['owner_id'] as String,
      pageImageUrls: List<String>.from(map['page_image_urls'] ?? []),
      pdfUrl: map['pdf_url'] as String?,
      isPublic: map['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convertit ce Flipbook en Map pour l'insertion/mise à jour dans Supabase.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'owner_id': ownerId,
      'page_image_urls': pageImageUrls,
      'pdf_url': pdfUrl,
      'is_public': isPublic,
    };
  }
}

/// Représente un signet (bookmark) dans un flipbook.
class Bookmark {
  final String id;
  final String flipbookId;
  final int page; // 1-based
  final String? note;
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.flipbookId,
    required this.page,
    this.note,
    required this.createdAt,
  });

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as String,
      flipbookId: map['flipbook_id'] as String,
      page: map['page'] as int,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
