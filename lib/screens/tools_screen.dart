import 'package:flutter/material.dart';
import '../services/conversion_service.dart' show PickedFileData;
import '../services/tools_service.dart';
import 'tool_runner_screen.dart';

/// Décrit un outil de conversion : titre, formats acceptés, et la fonction
/// du service à appeler pour l'exécuter.
class ToolDefinition {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> allowedExtensions;
  final bool allowMultiple;
  // Non-null si l'outil demande de choisir un format cible avant de lancer
  // la conversion (ex: convertisseur d'image) — voir ToolRunnerScreen.
  final List<String>? formatOptions;
  // Non-null si l'outil demande un texte libre avant de lancer la
  // conversion (ex: texte du filigrane, mot de passe) — voir ToolRunnerScreen.
  final String? textInputLabel;
  final String? textInputHint;
  final bool obscureTextInput;
  final int minTextInputLength;
  final Future<ToolResult> Function(List<PickedFileData> files, {String? format, String? text}) run;

  ToolDefinition({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.allowedExtensions,
    required this.run,
    this.allowMultiple = false,
    this.formatOptions,
    this.textInputLabel,
    this.textInputHint,
    this.obscureTextInput = false,
    this.minTextInputLength = 1,
  });
}

/// Écran présentant tous les outils de conversion indépendants du flipbook,
/// inspiré des convertisseurs de fichiers en ligne classiques.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  List<ToolDefinition> _buildTools() {
    final service = ToolsService();

    return [
      ToolDefinition(
        title: 'Word en PDF',
        subtitle: 'Convertissez vos fichiers Word en PDF',
        icon: Icons.description,
        color: const Color(0xFF3B82F6),
        allowedExtensions: ['doc', 'docx'],
        run: (files, {format, text}) => service.wordToPdf(files.first),
      ),
      ToolDefinition(
        title: 'PDF en Word',
        subtitle: 'Convertissez vos fichiers PDF en Word',
        icon: Icons.picture_as_pdf,
        color: const Color(0xFFE1445E),
        allowedExtensions: ['pdf'],
        run: (files, {format, text}) => service.pdfToWord(files.first),
      ),
      ToolDefinition(
        title: 'Texte en PDF',
        subtitle: 'Convertissez vos fichiers texte en PDF',
        icon: Icons.notes,
        color: const Color(0xFF9B5DE5),
        allowedExtensions: ['txt'],
        run: (files, {format, text}) => service.textToPdf(files.first),
      ),
      ToolDefinition(
        title: 'Image en PDF',
        subtitle: 'Convertissez une image en PDF',
        icon: Icons.image,
        color: const Color(0xFF2CB67D),
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        run: (files, {format, text}) => service.imageToPdf(files.first),
      ),
      ToolDefinition(
        title: 'Plusieurs images en PDF',
        subtitle: 'Fusionnez plusieurs images en un seul PDF',
        icon: Icons.perm_media,
        color: const Color(0xFF14B8A6),
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: true,
        run: (files, {format, text}) => service.imagesToPdf(files),
      ),
      ToolDefinition(
        title: 'Convertir une image',
        subtitle: 'Changez le format de votre image (JPG, PNG, WEBP)',
        icon: Icons.photo_size_select_actual_outlined,
        color: const Color(0xFFF97316),
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        formatOptions: const ['jpg', 'png', 'webp'],
        run: (files, {format, text}) => service.convertImage(files.first, format ?? 'png'),
      ),
      ToolDefinition(
        title: 'PDF en image(s)',
        subtitle: 'Extrait chaque page en JPG ou PNG (.zip si plusieurs pages)',
        icon: Icons.image_outlined,
        color: const Color(0xFF06B6D4),
        allowedExtensions: ['pdf'],
        formatOptions: const ['jpg', 'png'],
        run: (files, {format, text}) => service.pdfToImages(files.first, format ?? 'jpg'),
      ),
      ToolDefinition(
        title: 'Filigrane PDF',
        subtitle: 'Ajoute un texte en filigrane sur toutes les pages',
        icon: Icons.branding_watermark_outlined,
        color: const Color(0xFF8B5CF6),
        allowedExtensions: ['pdf'],
        textInputLabel: 'Texte du filigrane',
        textInputHint: 'Ex : CONFIDENTIEL',
        run: (files, {format, text}) => service.watermarkPdf(files.first, text ?? ''),
      ),
      ToolDefinition(
        title: 'Protéger un PDF',
        subtitle: 'Ajoute un mot de passe pour ouvrir le fichier',
        icon: Icons.lock_outline,
        color: const Color(0xFF0EA5E9),
        allowedExtensions: ['pdf'],
        textInputLabel: 'Mot de passe',
        textInputHint: 'Au moins 4 caractères',
        obscureTextInput: true,
        minTextInputLength: 4,
        run: (files, {format, text}) => service.protectPdf(files.first, text ?? ''),
      ),
      ToolDefinition(
        title: 'Regrouper des PDF',
        subtitle: 'Combinez plusieurs PDF en un seul fichier',
        icon: Icons.merge_type,
        color: const Color(0xFFF59E0B),
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        run: (files, {format, text}) => service.mergePdf(files),
      ),
      ToolDefinition(
        title: 'Diviser un PDF',
        subtitle: 'Séparez les pages de votre PDF (résultat en .zip)',
        icon: Icons.call_split,
        color: const Color(0xFFEF4444),
        allowedExtensions: ['pdf'],
        run: (files, {format, text}) => service.splitPdf(files.first),
      ),
      ToolDefinition(
        title: 'Compresser un PDF',
        subtitle: 'Réduisez la taille de votre fichier PDF',
        icon: Icons.compress,
        color: const Color(0xFF64748B),
        allowedExtensions: ['pdf'],
        run: (files, {format, text}) => service.compressPdf(files.first),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tools = _buildTools();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outils'),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: tools.length,
        itemBuilder: (context, index) {
          final tool = tools[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ToolRunnerScreen(tool: tool)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: tool.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(tool.icon, color: tool.color, size: 22),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tool.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tool.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
