import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/services/project_store.dart';

void main() {
  late Directory directory;
  late ProjectStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qx-project-store-');
    store = ProjectStore(directoryProvider: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('creates a project and keeps it available after reopening the store',
      () async {
    final created = await store.createProject(
      name: 'My first project',
      type: 'تطبيق',
      description: 'Local project test',
    );

    final reopenedStore =
        ProjectStore(directoryProvider: () async => directory);
    final projects = await reopenedStore.getProjects();

    expect(projects, hasLength(1));
    expect(projects.single.id, created.id);
    expect(projects.single.name, 'My first project');
    expect(projects.single.type, 'تطبيق');
    expect(projects.single.description, 'Local project test');
    expect(projects.single.createdAt, created.createdAt);
  });

  test('rejects an empty project name', () async {
    expect(
      store.createProject(name: '   ', type: 'مشروع عام'),
      throwsArgumentError,
    );
  });
}
