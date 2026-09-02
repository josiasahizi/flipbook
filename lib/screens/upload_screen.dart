import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/conversion_service.dart';
import '../theme/app_theme.dart';
import '../widgets/upload_widgets.dart';

enum _UploadMode { singleFile, multipleImages }

/// Écran permettant de créer un flipbook de deux façons :
/// - à partir d'UN fichier (PDF, Word, PPT, TXT, EPUB ou image)
/// - à partir de PLUSIEURS images fusionnées en un seul PDF (comme un scanner)
///
/// Le contenu est envoyé directement au backend Node.js, qui fait la
/// conversion et stocke lui-même le résultat dans Supabase Storage. L'app
/// n'a plus qu'à récupérer les URLs et créer le flipbook en base.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _service = SupabaseService();
  final _conversionService = ConversionService();
  final _titleController = TextEditingController();

  _UploadMode _mode = _UploadMode.singleFile;

  PlatformFile? _pickedFile;
  List<PlatformFile> _pickedImages = [];

  bool _isUploading = false;
  String _statusMessage = '';

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'epub', 'jpg', 'jpeg', 'png',
      ],
      withData: true, // nécessaire pour le web
    );
    if (result != null) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: true,
    );
    if (result != null) {
      setState(() => _pickedImages = [..._pickedImages, ...result.files]);
    }
  }

  void _removeImageAt(int index) {
    setState(() => _pickedImages.removeAt(index));
  }

  bool get _canSubmit {
    if (_titleController.text.trim().isEmpty) return false;
    if (_mode == _UploadMode.singleFile) return _pickedFile != null;
    return _pickedImages.isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() {
      _isUploading = true;
      _statusMessage = 'Conversion en cours (peut prendre quelques secondes)...';
    });

    try {
      final result = _mode == _UploadMode.singleFile
          ? await _conversionService.convertFile(_pickedFile!.name, _pickedFile!.bytes!)
          : await _conversionService.convertImages(
              _pickedImages
                  .map((f) => PickedFileData(fileName: f.name, bytes: f.bytes!))
                  .toList(),
            );

      setState(() => _statusMessage = 'Enregistrement du flipbook...');

      await _service.createFlipbook(
        title: _titleController.text.trim(),
        pageImageUrls: result.pageUrls,
        pdfUrl: result.pdfUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Flipbook créé avec ${result.pageUrls.length} pages !')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: Theme.of(context).textTheme.labelMedium);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un flipbook')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_UploadMode>(
                    segments: const [
                      ButtonSegment(value: _UploadMode.singleFile, label: Text('Un fichier')),
                      ButtonSegment(
                          value: _UploadMode.multipleImages, label: Text('Plusieurs images')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (selection) => setState(() => _mode = selection.first),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('TITRE DU DOCUMENT'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: 'Ex: Rapport Annuel 2024'),
                  ),
                  const SizedBox(height: 24),
                  if (_mode == _UploadMode.singleFile) ...[
                    _sectionLabel('DOCUMENT SOURCE'),
                    const SizedBox(height: 8),
                    DropZone(
                      onTap: _pickFile,
                      subtitle: 'PDF, DOC, TXT, EPUB ou image (Max 50MB)',
                    ),
                    const SizedBox(height: 12),
                    const _InfoBanner(
                      text: 'La durée de conversion dépend de la taille et du nombre '
                          'de pages de ton fichier — ça peut prendre quelques secondes '
                          'à quelques minutes pour un document volumineux.',
                    ),
                    if (_pickedFile != null) ...[
                      const SizedBox(height: 20),
                      _sectionLabel('FICHIER SÉLECTIONNÉ'),
                      const SizedBox(height: 8),
                      SelectedFileCard(
                        name: _pickedFile!.name,
                        onRemove: () => setState(() => _pickedFile = null),
                      ),
                    ],
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                            child: _sectionLabel('IMAGES SÉLECTIONNÉES (${_pickedImages.length})')),
                        TextButton(onPressed: _pickImages, child: const Text('Ajouter')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_pickedImages.isEmpty)
                      DropZone(onTap: _pickImages, subtitle: 'JPG ou PNG, plusieurs à la fois')
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (int i = 0; i < _pickedImages.length; i++)
                            ImageThumb(
                              file: _pickedImages[i],
                              index: i + 1,
                              onRemove: () => _removeImageAt(i),
                            ),
                          AddMoreTile(onTap: _pickImages),
                        ],
                      ),
                  ],
                  if (_isUploading) ...[
                    const SizedBox(height: 20),
                    Text(_statusMessage,
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
          // ---------- Bouton fixé en bas ----------
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: AppTheme.background,
              border: Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: (_isUploading || !_canSubmit) ? null : _submit,
                child: _isUploading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Créer le flipbook  ✨'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Petite bannière d'information discrète (icône + texte), utilisée pour
/// prévenir que le temps de conversion varie selon le fichier.
class _InfoBanner extends StatelessWidget {
  final String text;

  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
