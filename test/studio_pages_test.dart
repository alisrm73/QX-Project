import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
import 'package:qx_studio/screens/library_page.dart';
import 'package:qx_studio/screens/qx_core_page.dart';
import 'package:qx_studio/screens/search_page.dart';
import 'package:qx_studio/screens/settings_page.dart';
import 'package:qx_studio/services/local_profile_store.dart';
import 'package:qx_studio/services/project_store.dart';
import 'package:qx_studio/services/workspace_store.dart';

void main() {
  final projects = [
    QxProject(
      id: 'demo-1',
      name: 'QX Demo',
      type: 'Website',
      description: 'Studio test project',
      createdAt: DateTime(2026, 11, 10),
    ),
    QxProject(
      id: 'demo-2',
      name: 'Mobile App',
      type: 'App',
      description: 'Second project',
      createdAt: DateTime(2026, 11, 9),
    ),
  ];

  testWidgets('QX Core shows project and workspace metrics', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: QxCorePage(
        store: _MemoryProjectStore(projects),
        workspaceStore: _MemoryWorkspaceStore(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('QX Core'), findsOneWidget);
    expect(find.text('QX Demo'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('Library lists the saved local projects', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LibraryPage(store: _MemoryProjectStore(projects)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('المكتبة / Library'), findsOneWidget);
    expect(find.text('QX Demo'), findsOneWidget);
    expect(find.text('Mobile App'), findsOneWidget);
  });

  testWidgets('Search filters saved projects by name and description', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SearchPage(store: _MemoryProjectStore(projects)),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'studio');
    await tester.pumpAndSettle();

    expect(find.text('QX Demo'), findsOneWidget);
    expect(find.text('Mobile App'), findsNothing);
  });

  testWidgets('Settings loads and persists the local display name', (tester) async {
    final store = _MemoryProfileStore();

    await tester.pumpWidget(MaterialApp(home: SettingsPage(store: store)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'QX Operator');
    await tester.tap(find.text('حفظ على الهاتف / Save locally'));
    await tester.pumpAndSettle();

    expect(store.saved?.displayName, 'QX Operator');
    expect(find.text('تم حفظ الملف على الهاتف / Profile saved on this device'),
        findsOneWidget);
  });
}

class _MemoryProjectStore extends ProjectStore {
  _MemoryProjectStore(this.projects);

  final List<QxProject> projects;

  @override
  Future<List<QxProject>> getProjects() async => projects;
}

class _MemoryWorkspaceStore extends WorkspaceStore {
  @override
  Future<WorkspaceAnalysis> analyzeWorkspace(QxProject project) async =>
      const WorkspaceAnalysis(
        fileCount: 3,
        directoryCount: 1,
        totalBytes: 128,
        extensionCounts: {'.html': 1, '.css': 1, '.js': 1},
        hasIndexHtml: true,
        hasStyleCss: true,
        hasScriptJs: true,
      );
}

class _MemoryProfileStore extends LocalProfileStore {
  LocalProfile saved = const LocalProfile(displayName: 'Existing user');

  @override
  Future<LocalProfile> load() async => saved;

  @override
  Future<LocalProfile> save(LocalProfile profile) async {
    saved = LocalProfile(displayName: profile.displayName.trim());
    return saved;
  }
}
