import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/qx_project.dart';
import '../services/workspace_store.dart';

typedef PreviewContentBuilder = Widget Function(
  BuildContext context,
  WorkspacePreviewContent content,
);

class ProjectPreviewPage extends StatefulWidget {
  const ProjectPreviewPage({
    super.key,
    required this.project,
    required this.store,
    this.previewContentBuilder,
  });

  final QxProject project;
  final WorkspaceStore store;
  final PreviewContentBuilder? previewContentBuilder;

  @override
  State<ProjectPreviewPage> createState() => _ProjectPreviewPageState();
}

class _ProjectPreviewPageState extends State<ProjectPreviewPage> {
  late Future<WorkspacePreviewContent> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = widget.store.loadWebPreview(widget.project);
  }

  Future<void> _reload() async {
    setState(() {
      _contentFuture = widget.store.loadWebPreview(widget.project);
    });
    await _contentFuture;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('معاينة المشروع / Project preview'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          actions: [
            IconButton(
              tooltip: 'تحديث / Refresh',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: FutureBuilder<WorkspacePreviewContent>(
          future: _contentFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _PreviewMessage(
                message: 'لم يتم العثور على index.html أو تعذّرت قراءته / index.html is missing or could not be read',
                detail: 'أنشئ ملف index.html داخل مساحة المشروع ثم حدّث المعاينة / Create index.html in the project workspace, then refresh',
                action: _reload,
              );
            }
            final content = snapshot.data!;
            final builder = widget.previewContentBuilder;
            if (builder != null) return builder(context, content);
            return _PreviewWebView(content: content);
          },
        ),
      );
}

class _PreviewWebView extends StatefulWidget {
  const _PreviewWebView({required this.content});

  final WorkspacePreviewContent content;

  @override
  State<_PreviewWebView> createState() => _PreviewWebViewState();
}

class _PreviewWebViewState extends State<_PreviewWebView> {
  late final WebViewController _controller;
  bool _isReady = false;
  bool _assetsApplied = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setBackgroundColor(const Color(0xFFFFFFFF));
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            final isLocalDocument =
                uri != null && uri.scheme == 'about' && uri.path == 'blank';
            return isLocalDocument
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (_) => _applyLocalAssets(),
        ),
      );
      await _controller.loadHtmlString(
        _withContentSecurityPolicy(widget.content.html),
      );
      if (mounted) setState(() => _isReady = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'تعذّر تشغيل المعاينة / Could not start the preview');
      }
    }
  }

  String _withContentSecurityPolicy(String html) {
    const policy = "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; img-src data: blob:; media-src data: blob:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; font-src data:; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'\">";
    final headPattern = RegExp('<head[^>]*>', caseSensitive: false);
    final htmlPattern = RegExp('<html[^>]*>', caseSensitive: false);
    if (headPattern.hasMatch(html)) {
      return html.replaceFirstMapped(
        headPattern,
        (match) => (match.group(0) ?? '') + policy,
      );
    }
    if (htmlPattern.hasMatch(html)) {
      return html.replaceFirstMapped(
        htmlPattern,
        (match) => (match.group(0) ?? '') + '<head>' + policy + '</head>',
      );
    }
    return '<!doctype html><html><head>' +
        policy +
        '</head><body>' +
        html +
        '</body></html>';
  }

  Future<void> _applyLocalAssets() async {
    if (_assetsApplied) return;
    _assetsApplied = true;
    try {
      if (widget.content.css.isNotEmpty) {
        await _controller.runJavaScript(
          '(() => { const style = document.createElement("style"); ' +
          'style.textContent = ' +
          jsonEncode(widget.content.css) +
          '; document.head.appendChild(style); })();',
        );
      }
      if (widget.content.js.isNotEmpty) {
        await _controller.runJavaScript(widget.content.js);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'تعذّر تطبيق CSS أو JavaScript / Could not apply CSS or JavaScript');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _PreviewMessage(message: _error!);
    }
    if (!_isReady) {
      return const Center(child: CircularProgressIndicator());
    }
    return WebViewWidget(controller: _controller);
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({
    required this.message,
    this.detail,
    this.action,
  });

  final String message;
  final String? detail;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.preview_outlined,
                size: 46,
                color: Color(0xFF9286FF),
              ),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 14),
                FilledButton.tonal(
                  onPressed: action,
                  child: const Text('إعادة المحاولة / Retry'),
                ),
              ],
            ],
          ),
        ),
      );
}
