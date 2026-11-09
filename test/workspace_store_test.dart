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

  test('creates, reads, and updates a local text file', () async {
    await store.createTextFile(
      project,
      fileName: 'main.dart',
      content: 'void main() {}',
    );

    expect(await store.readTextFile(project, 'main.dart'), 'void main() {}');

    await store.writeTextFile(
      project,
      fileName: 'main.dart',
      content: 'void main() { print("QX"); }',
    );

    expect(
      await store.readTextFile(project, 'main.dart'),
      'void main() { print("QX"); }',
    );
  });

  test('loads the web preview entry point and optional local assets', () async {
    await store.createTextFile(
      project,
      fileName: 'index.html',
      content: '<html><head></head><body>QX</body></html>',
    );
    await store.createTextFile(
      project,
      fileName: 'style.css',
      content: 'body { color: purple; }',
    );
    await store.createTextFile(
      project,
      fileName: 'script.js',
      content: 'document.title = "QX";',
    );

    final preview = await store.loadWebPreview(project);

    expect(preview.html, contains('<body>QX</body>'));
    expect(preview.css, 'body { color: purple; }');
    expect(preview.js, 'document.title = "QX";');
  });

  test('requires index.html to open a web preview', () async {
    await expectLater(
      store.loadWebPreview(project),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('does not overwrite an existing file when creating a file', () async {
    await store.createTextFile(project, fileName: 'README.md', content: 'first');

    await expectLater(
      store.createTextFile(project, fileName: 'README.md', content: 'second'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await store.readTextFile(project, 'README.md'), 'first');
  });

  test('rejects file names that could escape workspace storage', () async {
    await expectLater(
      store.createTextFile(project, fileName: '../outside.txt'),
      throwsArgumentError,
    );
    await expectLater(
      store.readTextFile(project, '..\\outside.txt'),
      throwsArgumentError,
    );
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
