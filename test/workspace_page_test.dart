import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
import 'package:qx_studio/screens/workspace_page.dart';
import 'package:qx_studio/services/project_store.dart';
import 'package:qx_studio/services/workspace_store.dart';

void main() {
  testWidgets('shows saved projects and opens the selected workspace',
      (tester) async {
    final directory = await Directory.systemTemp.createTemp('qx-workspace-ui-');
    addTearDown(() => directory.delete(recursive: true));
    final project = QxProject(
      id: 'demo-1',
      name: 'Demo workspace',
      type: 'App',
      description: '',
      createdAt: DateTime(2026, 11, 9),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspacePage(
          projectStore: _FakeProjectStore([project]),
          workspaceStore: WorkspaceStore(directoryProvider: () async => directory),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo workspace'), findsOneWidget);
    await tester.tap(find.text('Demo workspace'));
    await tester.pumpAndSettle();

    expect(find.text('مساحة العمل جاهزة، ولا توجد ملفات بعد / Workspace is ready. No files yet'), findsOneWidget);
    expect(
      await Directory('${directory.path}/qx_workspaces/demo-1').exists(),
      isTrue,
    );
  });

  testWidgets('shows a helpful message when no projects exist', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WorkspacePage(projectStore: _FakeProjectStore([]))),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('أنشئ مشروعاً أولاً لفتح مساحة العمل / Create a project first to open its workspace'),
      findsOneWidget,
    );
  });
}

class _FakeProjectStore extends ProjectStore {
  _FakeProjectStore(this.projects);

  final List<QxProject> projects;

  @override
  Future<List<QxProject>> getProjects() async => projects;
}
