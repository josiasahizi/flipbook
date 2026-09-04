import 'package:flutter/material.dart';
import '../models/flipbook.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'upload_screen.dart';
import 'flipbook_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = SupabaseService();
  final _searchController = TextEditingController();
  late Future<List<Flipbook>> _flipbooksFuture;
  late Future<({int createdCount, int bonusSlots, bool isPremium})> _statsFuture;
  String _query = '';

  /// Nombre de flipbooks inclus dans la version gratuite. Au-delà, on
  /// propose de regarder une pub (bientôt) ou de passer premium (bientôt).
  static const int freeFlipbookLimit = 2;

  @override
  void initState() {
    super.initState();
    _flipbooksFuture = _service.fetchMyFlipbooks();
    _statsFuture = _service.fetchUserStats();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _flipbooksFuture = _service.fetchMyFlipbooks();
      _statsFuture = _service.fetchUserStats();
    });
  }

  Future<void> _renameFlipbook(Flipbook flipbook) async {
    final controller = TextEditingController(text: flipbook.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renommer le flipbook'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Titre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != flipbook.title) {
      await _service.renameFlipbook(flipbook.id, newTitle);
      _refresh();
    }
  }

  Future<void> _deleteFlipbook(Flipbook flipbook) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce flipbook ?'),
        content: Text('« ${flipbook.title} » sera définitivement supprimé. '
            'Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.deleteFlipbook(flipbook);
      _refresh();
    }
  }

  void _showFlipbookMenu(Flipbook flipbook) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renommer'),
              onTap: () {
                Navigator.pop(sheetContext);
                _renameFlipbook(flipbook);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.error),
              title: const Text('Supprimer', style: TextStyle(color: AppTheme.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteFlipbook(flipbook);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes flipbooks'),
        actions: [
          FutureBuilder<({int createdCount, int bonusSlots, bool isPremium})>(
            future: _statsFuture,
            builder: (context, snapshot) {
              final createdCount = snapshot.data?.createdCount ?? 0;
              final limit = freeFlipbookLimit + (snapshot.data?.bonusSlots ?? 0);
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${createdCount.clamp(0, limit)}/$limit',
                    style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Flipbook>>(
        future: _flipbooksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          final allFlipbooks = snapshot.data ?? [];
          final flipbooks = _query.isEmpty
              ? allFlipbooks
              : allFlipbooks.where((f) => f.title.toLowerCase().contains(_query)).toList();

          if (allFlipbooks.isEmpty) {
            return _EmptyState(onCreate: () => _openUpload(context));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un flipbook...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: flipbooks.isEmpty
                    ? Center(
                        child: Text('Aucun résultat pour « ${_searchController.text} »',
                            style: Theme.of(context).textTheme.bodyMedium),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _refresh(),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.68,
                          ),
                          itemCount: flipbooks.length,
                          itemBuilder: (context, index) {
                            final fb = flipbooks[index];
                            return _FlipbookCard(
                              flipbook: fb,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => FlipbookViewerScreen(flipbook: fb)),
                                );
                              },
                              onMenuTap: () => _showFlipbookMenu(fb),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openUpload(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau'),
      ),
    );
  }

  Future<void> _openUpload(BuildContext context) async {
    final stats = await _statsFuture;
    final limit = freeFlipbookLimit + stats.bonusSlots;
    if (stats.createdCount >= limit) {
      if (context.mounted) _showLimitReachedSheet(context);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadScreen()),
    );
    _refresh();
  }

  void _showLimitReachedSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 64, height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, color: AppTheme.primary, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Limite de flipbooks atteinte',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'La version gratuite permet de créer jusqu\'à $freeFlipbookLimit '
                'flipbooks au total. Supprimer un flipbook ne libère pas de '
                'place — débloque-en plus avec l\'une des options ci-dessous.',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: null, // bientôt disponible (intégration publicité à venir)
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Regarder une pub pour +1 flipbook'),
              ),
              const SizedBox(height: 4),
              const Text('Bientôt disponible', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: null, // bientôt disponible (abonnement à venir)
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Passer premium (illimité)'),
              ),
              const SizedBox(height: 4),
              const Text('Bientôt disponible', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlipbookCard extends StatelessWidget {
  final Flipbook flipbook;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  const _FlipbookCard({required this.flipbook, required this.onTap, required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
                      child: flipbook.pageImageUrls.isNotEmpty
                          ? Image.network(flipbook.pageImageUrls.first, fit: BoxFit.cover)
                          : const Center(
                              child: Icon(Icons.menu_book, color: Colors.white, size: 40)),
                    ),
                  ),
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        flipbook.pdfUrl != null ? 'PDF' : 'IMG',
                        style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: Material(
                      color: Colors.black.withOpacity(0.35),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onMenuTap,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.more_vert, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flipbook.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${flipbook.pageImageUrls.length} pages',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient, shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu_book, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text('Aucun flipbook pour le moment',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Crée ton premier flipbook à partir d\'un PDF, Word, PPT ou d\'images.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Créer un flipbook'),
            ),
          ],
        ),
      ),
    );
  }
}
