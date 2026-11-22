import 'package:flutter/material.dart';

import '../models/qx_project.dart';
import '../services/project_store.dart';
import '../services/workspace_store.dart';
import 'tools_page.dart';

class QxCorePage extends StatefulWidget {
  const QxCorePage({super.key, this.store, this.workspaceStore});

  final ProjectStore? store;
  final WorkspaceStore? workspaceStore;

  @override
  State<QxCorePage> createState() => _QxCorePageState();
}

class _QxCorePageState extends State<QxCorePage> {
  late final ProjectStore _store;
  late final WorkspaceStore _workspaceStore;
  late Future<List<({QxProject project, WorkspaceAnalysis analysis})>> _report;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ProjectStore();
    _workspaceStore = widget.workspaceStore ?? WorkspaceStore();
    _report = _loadReport();
  }

  Future<List<({QxProject project, WorkspaceAnalysis analysis})>> _loadReport() async {
    final projects = await _store.getProjects();
    final results = <({QxProject project, WorkspaceAnalysis analysis})>[];
    for (final project in projects) {
      results.add((project: project, analysis: await _workspaceStore.analyzeWorkspace(project)));
    }
    return results;
  }

  Future<void> _refresh() async {
    setState(() => _report = _loadReport());
    await _report;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('QX Core'),
          actions: [
            IconButton(
              tooltip: 'تحديث التقرير / Refresh report',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: FutureBuilder<List<({QxProject project, WorkspaceAnalysis analysis})>>(
          future: _report,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('تعذّر إنشاء تقرير المشاريع / Could not analyze projects'));
            }
            final reports = snapshot.data ?? const [];
            final totalFiles = reports.fold<int>(0, (sum, item) => sum + item.analysis.fileCount);
            final totalFolders = reports.fold<int>(0, (sum, item) => sum + item.analysis.directoryCount);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.hub_outlined, size: 54, color: Color(0xFF25B99A)),
                const SizedBox(height: 12),
                Text(
                  'مركز إدارة وتحليل المشاريع المحلي / Local project analysis hub',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'يعرض هذا التقرير بنية الملفات المحلية ومؤشرات الجاهزية الأساسية. لا يتضمن تحليلاً بالذكاء الاصطناعي أو اتصالاً بالإنترنت.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9DA2B4)),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _MetricCard(label: 'المشاريع / Projects', value: reports.length)),
                    const SizedBox(width: 8),
                    Expanded(child: _MetricCard(label: 'الملفات / Files', value: totalFiles)),
                    const SizedBox(width: 8),
                    Expanded(child: _MetricCard(label: 'المجلدات / Folders', value: totalFolders)),
                  ],
                ),
                const SizedBox(height: 16),
                if (reports.isEmpty)
                  Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('لا توجد مشاريع لتحليلها حالياً / No projects to analyze yet'),
                    ),
                  ),
                for (final report in reports)
                  Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(report.project.name, style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text('${report.analysis.fileCount} ملفات · ${report.analysis.directoryCount} مجلدات · ${report.analysis.totalBytes} bytes'),
                          const SizedBox(height: 8),
                          _CheckLine(label: 'index.html', present: report.analysis.hasIndexHtml),
                          _CheckLine(label: 'style.css', present: report.analysis.hasStyleCss),
                          _CheckLine(label: 'script.js', present: report.analysis.hasScriptJs),
                          if (report.analysis.extensionCounts.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('أنواع الملفات / File types: ${report.analysis.extensionCounts.entries.map((e) => '${e.key}: ${e.value}').join(' · ')}',
                                style: TextStyle(color: Color(0xFF9DA2B4))),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ToolsPage()),
                  ),
                  icon: const Icon(Icons.build_circle_outlined),
                  label: Text('فتح أدوات الفحص / Open project tools'),
                ),
              ],
            );
          },
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(value.toString(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.label, required this.present});
  final String label;
  final bool present;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(present ? Icons.check_circle_outline : Icons.radio_button_unchecked,
              size: 17, color: present ? const Color(0xFF25B99A) : Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 7),
          Text(label),
          const Spacer(),
          Text(present ? 'موجود / Found' : 'غير موجود / Missing',
              style: TextStyle(color: Color(0xFF9DA2B4), fontSize: 12)),
        ],
      );
}
