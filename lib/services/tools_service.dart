import 'package:http/http.dart' as http;
import 'backend_exception.dart';
import 'conversion_service.dart' show backendBaseUrl, PickedFileData;

/// Résultat renvoyé par un endpoint /tools : l'URL du fichier généré,
/// prêt à être ouvert/téléchargé.
class ToolResult {
  final String downloadUrl;
  final String fileName;

  ToolResult({required this.downloadUrl, required this.fileName});

  factory ToolResult.fromJson(Map<String, dynamic> json) {
    return ToolResult(
      downloadUrl: json['downloadUrl'] as String,
      fileName: json['fileName'] as String,
    );
  }
}

/// Appelle les différents outils de conversion indépendants du flipbook
/// (Word↔PDF, texte→PDF, image→PDF, fusion, division, compression...).
class ToolsService {
  Future<ToolResult> _postSingleFile(
    String endpoint,
    PickedFileData file, {
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('$backendBaseUrl$endpoint');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes('file', file.bytes, filename: file.fileName));
    if (fields != null) request.fields.addAll(fields);
    return _sendAndParse(request);
  }

  Future<ToolResult> _postMultipleFiles(
      String endpoint, List<PickedFileData> files, String fieldName) async {
    final uri = Uri.parse('$backendBaseUrl$endpoint');
    final request = http.MultipartRequest('POST', uri);
    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(fieldName, file.bytes, filename: file.fileName),
      );
    }
    return _sendAndParse(request);
  }

  Future<ToolResult> _sendAndParse(http.MultipartRequest request) async {
    final body = await sendMultipartRequest(request);
    return ToolResult.fromJson(body);
  }

  Future<ToolResult> wordToPdf(PickedFileData file) => _postSingleFile('/tools/word-to-pdf', file);
  Future<ToolResult> pdfToWord(PickedFileData file) => _postSingleFile('/tools/pdf-to-word', file);
  Future<ToolResult> textToPdf(PickedFileData file) => _postSingleFile('/tools/text-to-pdf', file);
  Future<ToolResult> imageToPdf(PickedFileData file) => _postSingleFile('/tools/image-to-pdf', file);
  Future<ToolResult> convertImage(PickedFileData file, String targetFormat) =>
      _postSingleFile('/tools/convert-image', file, fields: {'format': targetFormat});
  Future<ToolResult> compressPdf(PickedFileData file) => _postSingleFile('/tools/compress-pdf', file);
  Future<ToolResult> splitPdf(PickedFileData file) => _postSingleFile('/tools/split-pdf', file);
  Future<ToolResult> pdfToImages(PickedFileData file, String format) =>
      _postSingleFile('/tools/pdf-to-images', file, fields: {'format': format});
  Future<ToolResult> watermarkPdf(PickedFileData file, String text) =>
      _postSingleFile('/tools/watermark-pdf', file, fields: {'text': text});
  Future<ToolResult> protectPdf(PickedFileData file, String password) =>
      _postSingleFile('/tools/protect-pdf', file, fields: {'text': password});

  Future<ToolResult> imagesToPdf(List<PickedFileData> files) =>
      _postMultipleFiles('/tools/images-to-pdf', files, 'files');
  Future<ToolResult> mergePdf(List<PickedFileData> files) =>
      _postMultipleFiles('/tools/merge-pdf', files, 'files');
}
