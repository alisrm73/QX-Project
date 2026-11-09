import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
import 'package:qx_studio/services/task_store.dart';
import 'package:qx_studio/services/workspace_store.dart';

void main() {
  late Directory directory;
  late TaskStore store;
  final project = QxProject(
    id: 'task-project',
    name: 'Task project',
    type: 'App',
    description: '',
    createdAt: DateTime(2026, 11, 9),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qx-tasks-');
    store = TaskStore(
      workspaceStore: WorkspaceStore(directoryProvider: () async => directory),
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('adds tasks and persists them across store instances', () async {
    final task = await store.addTask(
      project,
      title: '  Build workspace  ',
      notes: '  Keep data local  ',
    );

    final reloaded = await TaskStore(
      workspaceStore:
          WorkspaceStore(directoryProvider: () async => directory),
    ).getTasks(project);

    expect(reloaded, hasLength(1));
    expect(reloaded.single.id, task.id);
    expect(reloaded.single.title, 'Build workspace');
    expect(reloaded.single.notes, 'Keep data local');
    expect(reloaded.single.isCompleted, isFalse);
  });

  test('updates task completion and persists the change', () async {
    final task = await store.addTask(project, title: 'Verify tests');

    await store.setTaskCompleted(
      project,
      taskId: task.id,
      isCompleted: true,
    );

    expect((await store.getTasks(project)).single.isCompleted, isTrue);
  });

  test('rejects an empty task title', () async {
    await expectLater(
      store.addTask(project, title: '  '),
      throwsArgumentError,
    );
  });

  test('does not silently replace malformed task data', () async {
    final workspace = await storeFor(directory).then(
      (value) => value.ensureWorkspace(project),
    );
    await File('${workspace.path}/tasks.json').writeAsString('{broken');

    await expectLater(store.getTasks(project), throwsFormatException);
  });

  test('rejects updates for unknown task identifiers', () async {
    await expectLater(
      store.setTaskCompleted(
        project,
        taskId: 'missing',
        isCompleted: true,
      ),
      throwsStateError,
    );
  });
}

WorkspaceStore storeFor(Directory directory) =>
    WorkspaceStore(directoryProvider: () async => directory);
