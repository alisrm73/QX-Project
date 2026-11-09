import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
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

  test('updates a saved project and persists the changes', () async {
    final created = await store.createProject(
      name: 'Before edit',
      type: 'تطبيق',
      description: 'Original description',
    );

    final updated = await store.updateProject(
      QxProject(
        id: created.id,
        name: 'After edit',
        type: 'موقع إلكتروني',
        description: 'Updated description',
        createdAt: created.createdAt,
      ),
    );

    final reopenedStore =
        ProjectStore(directoryProvider: () async => directory);
    final projects = await reopenedStore.getProjects();

    expect(projects, hasLength(1));
    expect(projects.single.id, created.id);
    expect(projects.single.name, 'After edit');
    expect(projects.single.type, 'موقع إلكتروني');
    expect(projects.single.description, 'Updated description');
    expect(projects.single.createdAt, created.createdAt);
    expect(updated.name, 'After edit');
  });

  test('rejects an empty project name', () async {
    expect(
      store.createProject(name: '   ', type: 'مشروع عام'),
      throwsArgumentError,
    );
  });

  test('rejects updating a project that does not exist', () async {
    expect(
      store.updateProject(
        QxProject(
          id: 'missing',
          name: 'Unknown',
          type: 'مشروع عام',
          description: '',
          createdAt: DateTime(2026, 11, 9),
        ),
      ),
      throwsStateError,
    );
  });
}
