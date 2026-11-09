import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
import 'package:qx_studio/services/workspace_store.dart';

void main() {
  late Directory directory;
  late WorkspaceStore store;
  final project = QxProject(
    id: 'project-123',
    name: 'Workspace test',
    type: 'App',
    description: '',
    createdAt: DateTime(2026, 11, 9),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qx-workspace-');
    store = WorkspaceStore(directoryProvider: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('creates an isolated local workspace for a project', () async {
    final workspace = await store.ensureWorkspace(project);

    expect(await workspace.exists(), isTrue);
    expect(workspace.path, '${directory.path}/qx_workspaces/project-123');
  });

  test('lists existing files and folders without following links', () async {
    final workspace = await store.ensureWorkspace(project);
    await Directory('${workspace.path}/lib').create();
    await File('${workspace.path}/README.md').writeAsString('QX');

    final entries = await store.listEntries(project);

    expect(entries, hasLength(2));
    expect(entries.first.name, 'lib');
    expect(entries.first.isDirectory, isTrue);
    expect(entries.last.name, 'README.md');
    expect(entries.last.isDirectory, isFalse);
    expect(entries.last.size, 2);
  });

  test('rejects project identifiers that could escape workspace storage', () async {
    final invalid = QxProject(
      id: '../outside',
      name: 'Invalid',
      type: 'App',
      description: '',
      createdAt: DateTime(2026, 11, 9),
    );

    expect(store.ensureWorkspace(invalid), throwsArgumentError);
  });
}
