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
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('creates an isolated local workspace for a project', () async {
    final workspace = await store.ensureWorkspace(project);
    expect(await workspace.exists(), isTrue);
    expect(workspace.path, '${directory.path}/qx_workspaces/project-123');
  });

  test('lists existing files and folders recursively without following links', () async {
    final workspace = await store.ensureWorkspace(project);
    await Directory('${workspace.path}/lib/models').create(recursive: true);
    await File('${workspace.path}/README.md').writeAsString('QX');
    await File('${workspace.path}/lib/models/item.dart').writeAsString('class Item {}');

    final entries = await store.listEntries(project);

    expect(entries.map((entry) => entry.relativePath),
        containsAll(['lib', 'lib/models', 'README.md', 'lib/models/item.dart']));
    final nestedFile = entries.singleWhere((entry) => entry.relativePath == 'lib/models/item.dart');
    expect(nestedFile.isDirectory, isFalse);
    expect(nestedFile.size, greaterThan(0));
  });

  test('creates nested folders and files without replacing existing content', () async {
    await store.createDirectory(project, directoryPath: 'lib/models');
    await store.createTextFile(project, fileName: 'lib/models/main.dart', content: 'first');

    expect(await store.readTextFile(project, 'lib/models/main.dart'), 'first');
    await expectLater(
      store.createTextFile(project, fileName: 'lib/models/main.dart', content: 'second'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await store.readTextFile(project, 'lib/models/main.dart'), 'first');
  });

  test('creates, reads, and updates a local text file', () async {
    await store.createTextFile(project, fileName: 'main.dart', content: 'void main() {}');
    expect(await store.readTextFile(project, 'main.dart'), 'void main() {}');
    await store.writeTextFile(project, fileName: 'main.dart', content: 'void main() { print("QX"); }');
    expect(await store.readTextFile(project, 'main.dart'), 'void main() { print("QX"); }');
  });

  test('analyzing a missing workspace does not create it', () async {
    final workspacePath = '${directory.path}/qx_workspaces/project-123';

    final report = await store.analyzeWorkspace(project);

    expect(report.fileCount, 0);
    expect(report.directoryCount, 0);
    expect(report.totalBytes, 0);
    expect(report.extensionCounts, isEmpty);
    expect(report.hasIndexHtml, isFalse);
    expect(report.hasStyleCss, isFalse);
    expect(report.hasScriptJs, isFalse);
    expect(await Directory(workspacePath).exists(), isFalse);
    expect(await Directory('${directory.path}/qx_workspaces').exists(), isFalse);
  });

  test('analyzes project files, folders, extensions, and web entry points', () async {
    await store.createDirectory(project, directoryPath: 'assets');
    await store.createTextFile(project, fileName: 'index.html', content: '<html></html>');
    await store.createTextFile(project, fileName: 'style.css', content: 'body {}');
    await store.createTextFile(project, fileName: 'assets/data.json', content: '{}');

    final report = await store.analyzeWorkspace(project);

    expect(report.fileCount, 3);
    expect(report.directoryCount, 1);
    expect(report.totalBytes, greaterThan(0));
    expect(report.extensionCounts['.html'], 1);
    expect(report.extensionCounts['.json'], 1);
    expect(report.hasIndexHtml, isTrue);
    expect(report.hasStyleCss, isTrue);
    expect(report.hasScriptJs, isFalse);
  });

  test('loads the web preview entry point and optional local assets', () async {
    await store.createTextFile(project, fileName: 'index.html', content: '<html><head></head><body>QX</body></html>');
    await store.createTextFile(project, fileName: 'style.css', content: 'body { color: purple; }');
    await store.createTextFile(project, fileName: 'script.js', content: 'document.title = "QX";');
    final preview = await store.loadWebPreview(project);
    expect(preview.html, contains('<body>QX</body>'));
    expect(preview.css, 'body { color: purple; }');
    expect(preview.js, 'document.title = "QX";');
  });

  test('requires index.html to open a web preview', () async {
    await expectLater(store.loadWebPreview(project), throwsA(isA<FileSystemException>()));
  });

  test('rejects paths that could escape workspace storage', () async {
    await expectLater(store.createTextFile(project, fileName: '../outside.txt'), throwsArgumentError);
    await expectLater(store.readTextFile(project, '..\\outside.txt'), throwsArgumentError);
    await expectLater(store.createDirectory(project, directoryPath: 'lib/../../outside'), throwsArgumentError);
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
