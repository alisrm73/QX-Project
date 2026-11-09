import 'package:flutter/material.dart';

import '../models/qx_project.dart';
import '../services/project_store.dart';
import '../services/workspace_store.dart';
import '../services/tool_engine.dart';
import 'project_preview_page.dart';
import 'assistant_connector_page.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({
    super.key,
    this.projectStore,
    this.workspaceStore,
  });

  final ProjectStore? projectStore;
  final WorkspaceStore? workspaceStore;

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  late Future<List<QxProject>> _projectsFuture;

  ProjectStore get _projects => widget.projectStore ?? ProjectStore();
  WorkspaceStore get _workspace => widget.workspaceStore ?? WorkspaceStore();

  @override
  void initState() {
    super.initState();
    _projectsFuture = _projects.getProjects();
  }

  Future<void> _reload() async {
    setState(() => _projectsFuture = _projects.getProjects());
    await _projectsFuture;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('الأدوات / Tools'),
          backgroundColor: const Color(0xFF0B0D13),
        ),
        backgroundColor: const Color(0xFF0B0D13),
        body: FutureBuilder<List<QxProject>>(
          future: _projectsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ToolsMessage(
                message: 'تعذّر تحميل المشاريع / Could not load projects',
                action: _reload,
              );
            }
            final projects = snapshot.data ?? const <QxProject>[];
            if (projects.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ChatGptConnectorCard(),
                  const SizedBox(height: 12),
                  const _ToolsMessage(
                    message: 'أنشئ مشروعاً أولاً لاستخدام أدوات المشروع / Create a project first to use project tools',
                  ),
                ],
              );
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ChatGptConnectorCard(),
                  const SizedBox(height: 16),
                  const Text(
                    'اختر مشروعاً لفحص ملفاته وأدواته / Choose a project to inspect its files and tools',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  for (final project in projects)
                    Card(
                      color: const Color(0xFF151923),
                      child: ListTile(
                        leading: const Icon(
                          Icons.build_circle_outlined,
                          color: Color(0xFFD477B8),
                        ),
                        title: Text(project.name),
                        subtitle: Text(project.type),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProjectToolsPage(
                              project: project,
                              store: _workspace,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
}

class ProjectToolsPage extends StatefulWidget {
  const ProjectToolsPage({
    super.key,
    required this.project,
    required this.store,
    this.toolRegistry,
  });

  final QxProject project;
  final WorkspaceStore store;
  final QxToolRegistry? toolRegistry;

  @override
  State<ProjectToolsPage> createState() => _ProjectToolsPageState();
}

class _ProjectToolsPageState extends State<ProjectToolsPage> {
  late Future<List<WorkspaceEntry>> _entriesFuture;
  late final QxToolRegistry _toolRegistry =
      widget.toolRegistry ?? QxToolRegistry.standard();
  QxToolResult? _lastToolResult;
  bool _isRunningTool = false;

  Future<void> _runTool(String toolId) async {
    setState(() => _isRunningTool = true);
    try {
      final result = await _toolRegistry.run(
        toolId,
        QxToolContext(project: widget.project, workspaceStore: widget.store),
      );
      if (!mounted) return;
      setState(() => _lastToolResult = result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastToolResult = QxToolResult(
          toolId: toolId,
          success: false,
          messageAr: 'فشل تشغيل الأداة. تحقق من مساحة العمل وحاول مجدداً.',
          messageEn: 'Tool execution failed. Check the workspace and try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _isRunningTool = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _entriesFuture = widget.store.listEntries(widget.project);
  }

  Future<void> _reload() async {
    setState(() => _entriesFuture = widget.store.listEntries(widget.project));
    await _entriesFuture;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('أدوات المشروع / Project tools · ' + widget.project.name),
          backgroundColor: const Color(0xFF0B0D13),
        ),
        backgroundColor: const Color(0xFF0B0D13),
        body: FutureBuilder<List<WorkspaceEntry>>(
          future: _entriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ToolsMessage(
                message: 'تعذّر فحص ملفات المشروع / Could not inspect project files',
                action: _reload,
              );
            }

            final entries = snapshot.data ?? const <WorkspaceEntry>[];
            final files = entries.where((entry) => !entry.isDirectory).toList();
            final folders = entries.where((entry) => entry.isDirectory).toList();
            final hasIndex = files.any((entry) => entry.name == 'index.html');
            final hasCss = files.any((entry) => entry.name == 'style.css');
            final hasJs = files.any((entry) => entry.name == 'script.js');

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: const Color(0xFF151923),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'فحص ملفات المشروع / Project file check',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Text('الملفات: ' + files.length.toString() + ' / Files'),
                          Text('المجلدات: ' + folders.length.toString() + ' / Folders'),
                          const SizedBox(height: 8),
                          Text(
                            entries.isEmpty
                                ? 'مساحة العمل فارغة / Workspace is empty'
                                : 'تمت قراءة عناصر مساحة العمل / Workspace entries were read',
                            style: const TextStyle(color: Color(0xFF9DA2B4)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final tool in _toolRegistry.tools)
                    Card(
                      color: const Color(0xFF17231F),
                      child: ListTile(
                        leading: const Icon(Icons.play_circle_outline,
                            color: Color(0xFF55C99A)),
                        title: Text('${tool.nameAr} / ${tool.nameEn}'),
                        subtitle: Text(tool.descriptionAr),
                        trailing: FilledButton(
                          onPressed: _isRunningTool ? null : () => _runTool(tool.id),
                          child: Text(_isRunningTool
                              ? 'جارٍ التنفيذ / Running'
                              : 'تشغيل / Run'),
                        ),
                      ),
                    ),
                  if (_lastToolResult != null)
                    Card(
                      color: const Color(0xFF151923),
                      child: ListTile(
                        leading: Icon(
                          _lastToolResult!.success
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: _lastToolResult!.success
                              ? const Color(0xFF55C99A)
                              : const Color(0xFFE28A8A),
                        ),
                        title: Text(_lastToolResult!.messageAr),
                        subtitle: Text(_lastToolResult!.messageEn),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF151923),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'جاهزية معاينة الويب / Web preview readiness',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          _ToolStatus(
                            label: 'index.html',
                            ready: hasIndex,
                            readyText: 'موجود / Found',
                            missingText: 'مفقود / Missing',
                          ),
                          _ToolStatus(
                            label: 'style.css',
                            ready: hasCss,
                            readyText: 'اختياري وموجود / Optional · Found',
                            missingText: 'اختياري / Optional',
                          ),
                          _ToolStatus(
                            label: 'script.js',
                            ready: hasJs,
                            readyText: 'اختياري وموجود / Optional · Found',
                            missingText: 'اختياري / Optional',
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: hasIndex
                                ? () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ProjectPreviewPage(
                                          project: widget.project,
                                          store: widget.store,
                                        ),
                                      ),
                                    )
                                : null,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('فتح المعاينة / Open preview'),
                          ),
                          if (!hasIndex)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'أنشئ index.html لتفعيل المعاينة / Create index.html to enable preview',
                                style: TextStyle(color: Color(0xFF9DA2B4)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة الفحص / Run check again'),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'هذه الأدوات تفحص ملفات المشروع محلياً فقط، ولا تشغّل أوامر نظام أو تتصل بالشبكة.',
                      style: TextStyle(color: Color(0xFF858B9D), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
}

class _ToolStatus extends StatelessWidget {
  const _ToolStatus({
    required this.label,
    required this.ready,
    required this.readyText,
    required this.missingText,
  });

  final String label;
  final bool ready;
  final String readyText;
  final String missingText;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              ready ? Icons.check_circle_outline : Icons.info_outline,
              color: ready ? const Color(0xFF55C99A) : const Color(0xFF9DA2B4),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Text(
              ready ? readyText : missingText,
              style: const TextStyle(color: Color(0xFF9DA2B4), fontSize: 12),
            ),
          ],
        ),
      );
}

class _ToolsMessage extends StatelessWidget {
  const _ToolsMessage({required this.message, this.action});

  final String message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.build_circle_outlined,
                size: 44,
                color: Color(0xFFD477B8),
              ),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
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

class _ChatGptConnectorCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF17231F),
        child: ListTile(
          leading: const Icon(Icons.auto_awesome, color: Color(0xFF55C99A)),
          title: const Text('ChatGPT · مساعد QX'),
          subtitle: const Text('أول أداة ربط · جاهز للاتصال لاحقاً / First assistant connector · prepared'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AssistantConnectorPage(),
            ),
          ),
        ),
      );
}
