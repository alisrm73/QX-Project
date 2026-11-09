import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
import 'package:qx_studio/screens/tools_page.dart';
import 'package:qx_studio/services/project_store.dart';
import 'package:qx_studio/services/workspace_store.dart';

void main() {
  final project = QxProject(
    id: 'tools-1',
    name: 'Tools demo',
    type: 'Website',
    description: '',
    createdAt: DateTime(2026, 11, 9),
  );

  testWidgets('shows saved projects and opens project tools', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ToolsPage(
          projectStore: _FakeProjectStore([project]),
          workspaceStore: _FakeWorkspaceStore(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tools demo'), findsOneWidget);
    await tester.tap(find.text('Tools demo'));
    await tester.pumpAndSettle();

    expect(find.text('فحص ملفات المشروع / Project file check'), findsOneWidget);
    expect(find.text('الملفات: 0 / Files'), findsOneWidget);
    expect(find.text('المجلدات: 0 / Folders'), findsOneWidget);
    expect(find.text('أنشئ index.html لتفعيل المعاينة / Create index.html to enable preview'), findsOneWidget);
    expect(find.text('تحليل مساحة العمل / Workspace analysis'), findsOneWidget);

    await tester.tap(find.text('تشغيل / Run'));
    await tester.pumpAndSettle();
    expect(find.textContaining('اكتمل التحليل:'), findsOneWidget);
  });

  testWidgets('detects web preview files and enables preview action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectToolsPage(
          project: project,
          store: _FakeWorkspaceStore(const [
            WorkspaceEntry(name: 'index.html', relativePath: 'index.html', isDirectory: false, size: 20),
            WorkspaceEntry(name: 'style.css', relativePath: 'style.css', isDirectory: false, size: 10),
            WorkspaceEntry(name: 'lib', relativePath: 'lib', isDirectory: true, size: 0),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('موجود / Found'), findsOneWidget);
    expect(find.text('اختياري وموجود / Optional · Found'), findsOneWidget);
    expect(find.text('مفقود / Missing'), findsNothing);

    final previewButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'فتح المعاينة / Open preview'),
    );
    expect(previewButton.onPressed, isNotNull);
  });
}

class _FakeProjectStore extends ProjectStore {
  _FakeProjectStore(this.projects);

  final List<QxProject> projects;

  @override
  Future<List<QxProject>> getProjects() async => projects;
}

class _FakeWorkspaceStore extends WorkspaceStore {
  _FakeWorkspaceStore(this.entries);

  final List<WorkspaceEntry> entries;

  @override
  Future<List<WorkspaceEntry>> listEntries(QxProject project) async => entries;

  @override
  Future<WorkspaceAnalysis> analyzeWorkspace(QxProject project) async =>
      WorkspaceAnalysis(
        fileCount: entries.where((entry) => !entry.isDirectory).length,
        directoryCount: entries.where((entry) => entry.isDirectory).length,
        totalBytes: entries.fold<int>(0, (total, entry) => total + entry.size),
        extensionCounts: const {},
        hasIndexHtml: entries.any((entry) => entry.relativePath == 'index.html'),
        hasStyleCss: entries.any((entry) => entry.relativePath == 'style.css'),
        hasScriptJs: entries.any((entry) => entry.relativePath == 'script.js'),
      );
}
