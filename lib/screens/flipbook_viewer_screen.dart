import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/flipbook.dart';
import '../services/offline_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/flipbook_page_view.dart';

const _tutorialSeenKey = 'flipbook_reader_tutorial_seen';

/// Affiche un flipbook avec l'effet de page qui se tourne. Propose aussi
/// le téléchargement pour une lecture hors-ligne (Android/iOS/desktop —
/// pas disponible sur Web), et le téléchargement du PDF associé.
class FlipbookViewerScreen extends StatefulWidget {
  final Flipbook flipbook;

  const FlipbookViewerScreen({super.key, required this.flipbook});

  @override
  State<FlipbookViewerScreen> createState() => _FlipbookViewerScreenState();
}

class _FlipbookViewerScreenState extends State<FlipbookViewerScreen> {
  final _offlineService = OfflineService();
  final _pageViewKey = GlobalKey<FlipbookPageViewState>();

  bool _rotateHintDismissed = false;
  bool _isAvailableOffline = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _localIndexHtmlPath;
  bool _checkedOfflineStatus = false;
  bool _showTutorial = false;

  int _currentPage = 1;
  List<Bookmark> _bookmarks = [];

  bool get _isCurrentPageBookmarked =>
      _bookmarks.any((b) => b.page == _currentPage);

  @override
  void initState() {
    super.initState();
    _checkOfflineStatus();
    _checkTutorialStatus();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    try {
      final bookmarks = await SupabaseService().fetchBookmarks(widget.flipbook.id);
      if (mounted) setState(() => _bookmarks = bookmarks);
    } catch (_) {
      // Table de signets pas encore disponible ou hors-ligne — on continue
      // sans signets plutôt que de bloquer l'ouverture du lecteur.
    }
  }

  Future<void> _toggleBookmark() async {
    final existing = _bookmarks.where((b) => b.page == _currentPage).toList();
    try {
      if (existing.isNotEmpty) {
        await SupabaseService().removeBookmark(existing.first.id);
        if (mounted) {
          setState(() => _bookmarks.removeWhere((b) => b.id == existing.first.id));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signet supprimé.')),
          );
        }
      } else {
        final bookmark = await SupabaseService().addBookmark(
          flipbookId: widget.flipbook.id,
          page: _currentPage,
        );
        if (mounted) {
          setState(() => _bookmarks = [..._bookmarks, bookmark]);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Page $_currentPage ajoutée aux signets.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de mettre à jour le signet : $e')),
        );
      }
    }
  }

  Future<void> _deleteBookmark(Bookmark bookmark) async {
    try {
      await SupabaseService().removeBookmark(bookmark.id);
      if (mounted) setState(() => _bookmarks.removeWhere((b) => b.id == bookmark.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de supprimer le signet : $e')),
        );
      }
    }
  }

  void _goToPage(int page) {
    _pageViewKey.currentState?.goToPage(page);
  }

  void _showPagesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PagesSheet(
        pageImageUrls: widget.flipbook.pageImageUrls,
        bookmarks: _bookmarks,
        currentPage: _currentPage,
        onJumpToPage: _goToPage,
        onDeleteBookmark: _deleteBookmark,
      ),
    );
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySeen = prefs.getBool(_tutorialSeenKey) ?? false;
    if (!alreadySeen && mounted) {
      setState(() => _showTutorial = true);
    }
  }

  Future<void> _dismissTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialSeenKey, true);
    if (mounted) setState(() => _showTutorial = false);
  }

  Future<void> _checkOfflineStatus() async {
    if (kIsWeb) {
      setState(() => _checkedOfflineStatus = true);
      return;
    }
    final path = await _offlineService.getOfflineIndexPath(widget.flipbook.id);
    if (mounted) {
      setState(() {
        _isAvailableOffline = path != null;
        _localIndexHtmlPath = path;
        _checkedOfflineStatus = true;
      });
    }
  }

  Future<void> _downloadOffline() async {
    final stats = await SupabaseService().fetchUserStats();
    if (!stats.isPremium) {
      if (mounted) _showPremiumRequiredSheet();
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      await _offlineService.downloadForOffline(
        widget.flipbook,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      final path = await _offlineService.getOfflineIndexPath(widget.flipbook.id);
      if (mounted) {
        setState(() {
          _isAvailableOffline = true;
          _localIndexHtmlPath = path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flipbook disponible hors-ligne !')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec du téléchargement : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showPremiumRequiredSheet() {
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
                child: const Icon(Icons.workspace_premium_outlined,
                    color: AppTheme.primary, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Fonctionnalité premium',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'La lecture hors-ligne est réservée aux membres premium. '
                'Passe premium pour télécharger tes flipbooks et les lire '
                'sans connexion internet.',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: null, // bientôt disponible (abonnement à venir)
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Passer premium'),
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

  Future<void> _removeOfflineCopy() async {
    await _offlineService.removeOfflineCopy(widget.flipbook.id);
    if (mounted) {
      setState(() {
        _isAvailableOffline = false;
        _localIndexHtmlPath = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copie hors-ligne supprimée.')),
      );
    }
  }

  void _showOfflineMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isAvailableOffline)
              ListTile(
                iconColor: Colors.white,
                textColor: Colors.white,
                leading: const Icon(Icons.delete_outline),
                title: const Text('Supprimer la copie hors-ligne'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removeOfflineCopy();
                },
              )
            else
              ListTile(
                iconColor: Colors.white,
                textColor: Colors.white,
                leading: const Icon(Icons.download_for_offline_outlined),
                title: const Text('Télécharger pour le hors-ligne'),
                subtitle: const Text('Lisible sans connexion internet ensuite',
                    style: TextStyle(color: Colors.white60)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _downloadOffline();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    final url = widget.flipbook.pdfUrl;
    if (url == null) return;

    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir le PDF.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.55), Colors.transparent],
            ),
          ),
        ),
        title: Row(
          children: [
            _CircleIconButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.flipbook.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            _CircleIconButton(
              icon: _isCurrentPageBookmarked ? Icons.bookmark : Icons.bookmark_border,
              onTap: _toggleBookmark,
            ),
            const SizedBox(width: 8),
            _CircleIconButton(
              icon: Icons.grid_view_rounded,
              onTap: _showPagesSheet,
            ),
            const SizedBox(width: 8),
            if (!kIsWeb) ...[
              _CircleIconButton(
                icon: _isAvailableOffline
                    ? Icons.offline_pin
                    : Icons.download_for_offline_outlined,
                onTap: _isDownloading ? () {} : _showOfflineMenu,
              ),
              const SizedBox(width: 8),
            ],
            if (widget.flipbook.pdfUrl != null)
              _CircleIconButton(
                icon: Icons.download,
                onTap: () => _downloadPdf(context),
              ),
          ],
        ),
        titleSpacing: 12,
      ),
      body: !_checkedOfflineStatus
          ? const Center(child: CircularProgressIndicator())
          : OrientationBuilder(
              builder: (context, orientation) {
                final showHint = orientation == Orientation.portrait && !_rotateHintDismissed;
                return Stack(
                  children: [
                    FlipbookPageView(
                      key: _pageViewKey,
                      pageImageUrls: widget.flipbook.pageImageUrls,
                      localIndexHtmlPath: _localIndexHtmlPath,
                      onPageChanged: (page, total) {
                        if (mounted) setState(() => _currentPage = page);
                      },
                    ),
                    if (_isDownloading)
                      Positioned(
                        left: 20, right: 20, bottom: 28,
                        child: _DownloadProgressBanner(progress: _downloadProgress),
                      )
                    else if (showHint)
                      Positioned(
                        left: 20, right: 20, bottom: 28,
                        child: _RotateDeviceHint(
                          onDismiss: () => setState(() => _rotateHintDismissed = true),
                        ),
                      ),
                    if (_showTutorial) _TutorialOverlay(onDismiss: _dismissTutorial),
                  ],
                );
              },
            ),
    );
  }
}

/// Bannière affichant la progression du téléchargement hors-ligne.
class _DownloadProgressBanner extends StatelessWidget {
  final double progress;

  const _DownloadProgressBanner({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.75),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Téléchargement pour le hors-ligne... ${(progress * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bannière invitant à passer en mode paysage pour profiter du flipbook
/// en double page. Se ferme automatiquement dès que l'écran tourne, ou
/// manuellement via le bouton de fermeture.
class _RotateDeviceHint extends StatefulWidget {
  final VoidCallback onDismiss;

  const _RotateDeviceHint({required this.onDismiss});

  @override
  State<_RotateDeviceHint> createState() => _RotateDeviceHintState();
}

class _RotateDeviceHintState extends State<_RotateDeviceHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _rotation = Tween<double>(begin: -0.05, end: 0.42)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.75),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _rotation,
              builder: (context, child) => Transform.rotate(
                angle: _rotation.value,
                child: child,
              ),
              child: const Icon(Icons.stay_current_portrait, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Tourne ton téléphone pour profiter du flipbook en plein écran !',
                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 18),
              onPressed: widget.onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

/// Petit tuto affiché une seule fois (la toute première fois qu'un
/// flipbook est ouvert) pour expliquer comment tourner les pages :
/// glisser, ou taper à droite/gauche de l'écran.
class _TutorialOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const _TutorialOverlay({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.82),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book, color: Colors.white, size: 48),
                  const SizedBox(height: 20),
                  const Text(
                    'Comment lire ton flipbook',
                    style: TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _TutorialTip(
                          icon: Icons.arrow_back,
                          title: 'Page précédente',
                          subtitle: 'Tape ou glisse sur la partie gauche',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _TutorialTip(
                          icon: Icons.arrow_forward,
                          title: 'Page suivante',
                          subtitle: 'Tape ou glisse sur la partie droite',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Astuce : pince avec deux doigts pour zoomer, double-tape pour dézoomer.',
                    style: TextStyle(color: Colors.white60, fontSize: 12.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: onDismiss,
                    child: const Text('J\'ai compris'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialTip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TutorialTip({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 10),
        Text(title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 11.5),
            textAlign: TextAlign.center),
      ],
    );
  }
}

/// Petit bouton circulaire translucide, comme les boutons "retour" utilisés
/// sur les bandeaux dégradés des écrans de connexion.
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Panneau (bottom sheet) combinant la grille de miniatures des pages et la
/// liste des signets — deux façons de naviguer rapidement dans le flipbook.
class _PagesSheet extends StatefulWidget {
  final List<String> pageImageUrls;
  final List<Bookmark> bookmarks;
  final int currentPage;
  final ValueChanged<int> onJumpToPage;
  final Future<void> Function(Bookmark) onDeleteBookmark;

  const _PagesSheet({
    required this.pageImageUrls,
    required this.bookmarks,
    required this.currentPage,
    required this.onJumpToPage,
    required this.onDeleteBookmark,
  });

  @override
  State<_PagesSheet> createState() => _PagesSheetState();
}

class _PagesSheetState extends State<_PagesSheet> {
  late List<Bookmark> _bookmarks;
  int _tab = 0; // 0 = miniatures, 1 = signets

  @override
  void initState() {
    super.initState();
    _bookmarks = widget.bookmarks;
  }

  Future<void> _delete(Bookmark bookmark) async {
    await widget.onDeleteBookmark(bookmark);
    if (mounted) setState(() => _bookmarks.removeWhere((b) => b.id == bookmark.id));
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkedPages = _bookmarks.map((b) => b.page).toSet();
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _SheetTabButton(
                        label: 'Miniatures',
                        icon: Icons.grid_view_rounded,
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SheetTabButton(
                        label: 'Signets',
                        icon: Icons.bookmark,
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: _tab == 0
                    ? _buildThumbnailGrid(scrollController, bookmarkedPages)
                    : _buildBookmarksList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnailGrid(ScrollController controller, Set<int> bookmarkedPages) {
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: widget.pageImageUrls.length,
      itemBuilder: (context, index) {
        final page = index + 1;
        final isCurrent = page == widget.currentPage;
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            widget.onJumpToPage(page);
          },
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCurrent ? AppTheme.primary : Colors.white12,
                      width: isCurrent ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          widget.pageImageUrls[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white10,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined, color: Colors.white38),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: Colors.white10,
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                              ),
                            );
                          },
                        ),
                        if (bookmarkedPages.contains(page))
                          const Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              Icons.bookmark,
                              color: AppTheme.primary,
                              size: 18,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$page',
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookmarksList(ScrollController controller) {
    if (_bookmarks.isEmpty) {
      return ListView(
        controller: controller,
        children: const [
          SizedBox(height: 60),
          Icon(Icons.bookmark_border, color: Colors.white24, size: 48),
          SizedBox(height: 16),
          Text(
            'Aucun signet pour l\'instant',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
          SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Touche l\'icône signet en haut de l\'écran pendant la lecture pour marquer une page.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12.5),
            ),
          ),
        ],
      );
    }
    final sorted = [..._bookmarks]..sort((a, b) => a.page.compareTo(b.page));
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
      itemBuilder: (context, index) {
        final bookmark = sorted[index];
        return ListTile(
          leading: const Icon(Icons.bookmark, color: AppTheme.primary),
          title: Text('Page ${bookmark.page}', style: const TextStyle(color: Colors.white)),
          subtitle: bookmark.note != null && bookmark.note!.isNotEmpty
              ? Text(bookmark.note!, style: const TextStyle(color: Colors.white54))
              : null,
          onTap: () {
            Navigator.pop(context);
            widget.onJumpToPage(bookmark.page);
          },
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white54),
            onPressed: () => _delete(bookmark),
          ),
        );
      },
    );
  }
}

class _SheetTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SheetTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primary.withOpacity(0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? AppTheme.primary : Colors.white54),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.primary : Colors.white54,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}