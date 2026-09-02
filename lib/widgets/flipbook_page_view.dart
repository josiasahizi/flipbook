import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_win_floating.dart';

class FlipbookPageView extends StatefulWidget {
  final List<String> pageImageUrls;
  final String? localIndexHtmlPath;
  final void Function(int page, int total)? onPageChanged;
  final Future<int> Function()? getCurrentPage;
  final Future<void> Function(int page)? goToPage;

  const FlipbookPageView({
    super.key,
    required this.pageImageUrls,
    this.localIndexHtmlPath,
    this.onPageChanged,
    this.getCurrentPage,
    this.goToPage,
  });

  @override
  State<FlipbookPageView> createState() => FlipbookPageViewState();
}

class FlipbookPageViewState extends State<FlipbookPageView> {
  late final WebViewController _controller;
  final GlobalKey<_WindowsFlipbookViewState> _windowsKey = GlobalKey<_WindowsFlipbookViewState>();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      _controller = WebViewController();
      _load();
    }
  }

  Future<void> _load() async {
    if (!kIsWeb) {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    }

    _controller.addJavaScriptChannel(
      'FlipbookChannel',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = jsonDecode(message.message);
          if (data['type'] == 'pageChanged' && widget.onPageChanged != null) {
            widget.onPageChanged!(data['page'] as int, data['total'] as int);
          }
        } catch (_) {}
      },
    );

    if (widget.localIndexHtmlPath != null && !kIsWeb) {
      await _controller.loadFile(widget.localIndexHtmlPath!);
    } else {
      final html = await _buildFlipbookHtml(widget.pageImageUrls);
      await _controller.loadHtmlString(html);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void didUpdateWidget(FlipbookPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageImageUrls != widget.pageImageUrls ||
        oldWidget.localIndexHtmlPath != widget.localIndexHtmlPath) {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
        _load();
      }
    }
  }

  Future<int> getCurrentPage() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return await _windowsKey.currentState?.getCurrentPage() ?? 1;
    }
    final result = await _controller.runJavaScriptReturningResult(
        'window.flipbookGetCurrentPage ? window.flipbookGetCurrentPage() : 1');
    final cleanResult = result.toString().replaceAll('"', '');
    return int.tryParse(cleanResult) ?? 1;
  }

  Future<void> goToPage(int page) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await _windowsKey.currentState?.goToPage(page);
      return;
    }
    await _controller.runJavaScript(
        'window.flipbookGoToPage && window.flipbookGoToPage($page)');
  }


  @override
  Widget build(BuildContext context) {
    if (widget.pageImageUrls.isEmpty && widget.localIndexHtmlPath == null) {
      return const Center(
        child: Text('Ce flipbook n\'a pas encore de pages.',
            style: TextStyle(color: Colors.white)),
      );
    }

    // Gestion native de la plateforme Windows
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _WindowsFlipbookView(
        key: _windowsKey,
        pageImageUrls: widget.pageImageUrls,
        localIndexHtmlPath: widget.localIndexHtmlPath,
        onPageChanged: widget.onPageChanged,
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return WebViewWidget(controller: _controller);
  }
}

/// Windows — via webview_win_floating (Microsoft Edge WebView2)
class _WindowsFlipbookView extends StatefulWidget {
  final List<String> pageImageUrls;
  final String? localIndexHtmlPath;
  final void Function(int page, int total)? onPageChanged;

  const _WindowsFlipbookView({
    super.key,
    required this.pageImageUrls,
    this.localIndexHtmlPath,
    this.onPageChanged,
  });

  @override
  State<_WindowsFlipbookView> createState() => _WindowsFlipbookViewState();
}

class _WindowsFlipbookViewState extends State<_WindowsFlipbookView> {
  late final WinWebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WinWebViewController();
    _load();
  }

  Future<void> _load() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);

    _controller.addJavaScriptChannel(
      'FlipbookChannel',
      onMessageReceived: (message) {
        try {
          final data = jsonDecode(message as String);
          if (data['type'] == 'pageChanged' && widget.onPageChanged != null) {
            widget.onPageChanged!(data['page'] as int, data['total'] as int);
          }
        } catch (_) {}
      },
    );

    if (widget.localIndexHtmlPath != null) {
      await _controller.loadRequest(Uri.file(widget.localIndexHtmlPath!));
    } else {
      final html = await _buildFlipbookHtml(widget.pageImageUrls);
      await _controller.loadHtmlString(html);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void didUpdateWidget(_WindowsFlipbookView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageImageUrls != widget.pageImageUrls ||
        oldWidget.localIndexHtmlPath != widget.localIndexHtmlPath) {
      _load();
    }
  }

  Future<int> getCurrentPage() async {
    final result = await _controller.runJavaScriptReturningResult(
        'window.flipbookGetCurrentPage ? window.flipbookGetCurrentPage() : 1');
    final cleanResult = result.toString().replaceAll('"', '');
    return int.tryParse(cleanResult) ?? 1;
  }

  Future<void> goToPage(int page) async {
    await _controller.runJavaScript(
        'window.flipbookGoToPage && window.flipbookGoToPage($page)');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return WinWebViewWidget(controller: _controller);
  }
}

Future<String> _buildFlipbookHtml(List<String> pageImageUrls) async {
  final template = await rootBundle.loadString('assets/flipbook_viewer/index.html');
  final pagesJson = jsonEncode(pageImageUrls);
  return template.replaceFirst('%%PAGES_JSON%%', pagesJson);
}
