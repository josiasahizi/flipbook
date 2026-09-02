import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Boîte à bordure pointillée réutilisable (dessinée à la main, car Flutter
/// n'a pas de style de bordure "dashed" natif).
class DottedBorderBox extends StatelessWidget {
  final Widget child;

  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DashedBorderPainter(), child: child);
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20));
    final paint = Paint()
      ..color = AppTheme.primary.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final path = Path()..addRRect(rrect);
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dashWidth), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Zone de dépôt/sélection de fichier — bordure pointillée, icône dans un
/// carré arrondi, titre + sous-titre d'invite.
class DropZone extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String subtitle;

  const DropZone({
    super.key,
    required this.onTap,
    this.title = 'Appuyez pour sélectionner',
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: DottedBorderBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          child: Column(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusIconContainer),
                ),
                child: const Icon(Icons.upload_file_outlined, color: AppTheme.primary, size: 26),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primary)),
              const SizedBox(height: 6),
              Text(subtitle,
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte affichant un fichier sélectionné (icône + nom + bouton X).
class SelectedFileCard extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;

  const SelectedFileCard({super.key, required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.insert_drive_file, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
            IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
          ],
        ),
      ),
    );
  }
}

/// Vignette numérotée pour une image sélectionnée (sélection multiple).
class ImageThumb extends StatelessWidget {
  final PlatformFile file;
  final int index;
  final VoidCallback onRemove;

  const ImageThumb({super.key, required this.file, required this.index, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 84, height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            image: file.bytes != null
                ? DecorationImage(image: MemoryImage(file.bytes!), fit: BoxFit.cover)
                : null,
            color: AppTheme.divider,
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$index',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        Positioned(
          top: -8, right: -8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle, boxShadow: AppTheme.cardShadow),
              child: const Icon(Icons.close, size: 14, color: AppTheme.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tuile "+" pour ajouter d'autres fichiers, à la fin d'une rangée de vignettes.
class AddMoreTile extends StatelessWidget {
  final VoidCallback onTap;

  const AddMoreTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: DottedBorderBox(
        child: SizedBox(
          width: 84, height: 100,
          child: Icon(Icons.add, color: AppTheme.primary.withOpacity(0.7)),
        ),
      ),
    );
  }
}

/// Carte de résultat (succès) affichant le fichier généré + bouton téléchargement.
class ResultCard extends StatelessWidget {
  final String fileName;
  final VoidCallback onDownload;

  const ResultCard({super.key, required this.fileName, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.success.withOpacity(0.08),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const Icon(Icons.check_circle, color: AppTheme.success),
        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: const Text('Conversion terminée'),
        trailing: IconButton(icon: const Icon(Icons.download), onPressed: onDownload),
        onTap: onDownload,
      ),
    );
  }
}
