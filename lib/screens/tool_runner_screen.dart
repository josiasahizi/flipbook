import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/conversion_service.dart' show PickedFileData;
import '../services/tools_service.dart';
import '../widgets/upload_widgets.dart';
import 'tools_screen.dart';

/// Écran générique : choisir un ou plusieurs fichiers selon l'outil,
/// lancer la conversion, puis proposer le téléchargement du résultat.
class ToolRunnerScreen extends StatefulWidget {
  final ToolDefinition tool;

  const ToolRunnerScreen({super.key, required this.tool});

  @override
  State<ToolRunnerScreen> createState() => _ToolRunnerScreenState();
}

class _ToolRunnerScreenState extends State<ToolRunnerScreen> {
  List<PlatformFile> _pickedFiles = [];
  bool _isProcessing = false;
  ToolResult? _result;
  String? _errorMessage;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: widget.tool.allowedExtensions,
      allowMultiple: widget.tool.allowMultiple,
      withData: true,
    );
    if (result != null) {
      setState(() {
        _pickedFiles = widget.tool.allowMultiple
            ? [..._pickedFiles, ...result.files]
            : [result.files.first];
        _result = null;
        _errorMessage = null;
      });
    }
  }

  void _removeFileAt(int index) {
    setState(() => _pickedFiles.removeAt(index));
  }

  bool get _canRun {
    if (_pickedFiles.isEmpty) return false;
    if (widget.tool.allowMultiple && widget.tool.title.contains('Regrouper')) {
      return _pickedFiles.length >= 2; // fusionner nécessite au moins 2 PDF
    }
    return true;
  }

  Future<void> _run() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final files = _pickedFiles
          .map((f) => PickedFileData(fileName: f.name, bytes: f.bytes!))
          .toList();
      final result = await widget.tool.run(files);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _openResult() async {
    if (_result == null) return;
    final uri = Uri.parse(_result!.downloadUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: Theme.of(context).textTheme.labelMedium);
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    final extensionsLabel = tool.allowedExtensions.map((e) => '.$e').join(', ');

    return Scaffold(
      appBar: AppBar(title: Text(tool.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tool.subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            if (_pickedFiles.isEmpty)
              DropZone(
                onTap: _pickFiles,
                title: 'Sélectionnez un document',
                subtitle: extensionsLabel,
              )
            else ...[
              Row(
                children: [
                  Expanded(
                      child: _sectionLabel(
                          tool.allowMultiple
                              ? 'FICHIERS SÉLECTIONNÉS (${_pickedFiles.length})'
                              : 'FICHIER SÉLECTIONNÉ')),
                  if (tool.allowMultiple)
                    TextButton(onPressed: _pickFiles, child: const Text('Ajouter')),
                ],
              ),
              const SizedBox(height: 8),
              ..._pickedFiles.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SelectedFileCard(
                    name: file.name,
                    onRemove: () => _removeFileAt(index),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_isProcessing || !_canRun) ? null : _run,
              child: _isProcessing
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Convertir'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text('Erreur : $_errorMessage',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_result != null) ...[
              const SizedBox(height: 24),
              ResultCard(fileName: _result!.fileName, onDownload: _openResult),
            ],
          ],
        ),
      ),
    );
  }
}
