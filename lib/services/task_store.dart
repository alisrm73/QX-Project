import 'dart:convert';
import 'dart:io';

import '../models/qx_project.dart';
import '../models/workspace_task.dart';
import 'workspace_store.dart';

class TaskStore {
  TaskStore({WorkspaceStore? workspaceStore})
      : _workspaceStore = workspaceStore ?? WorkspaceStore();

  final WorkspaceStore _workspaceStore;

  Future<File> _taskFile(QxProject project) async {
    final workspace = await _workspaceStore.ensureWorkspace(project);
    return File('${workspace.path}/tasks.json');
  }

  Future<List<WorkspaceTask>> getTasks(QxProject project) async {
    final file = await _taskFile(project);
    if (!await file.exists()) return <WorkspaceTask>[];

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      throw const FormatException('Task data must be a JSON list.');
    }
    return decoded
        .map((item) => WorkspaceTask.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<WorkspaceTask> addTask(
    QxProject project, {
    required String title,
    String notes = '',
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Task title is required.');
    }

    final tasks = await getTasks(project);
    final now = DateTime.now();
    final task = WorkspaceTask(
      id: now.microsecondsSinceEpoch.toString(),
      title: normalizedTitle,
      notes: notes.trim(),
      isCompleted: false,
      createdAt: now,
    );
    await _writeTasks(project, [...tasks, task]);
    return task;
  }

  Future<void> setTaskCompleted(
    QxProject project, {
    required String taskId,
    required bool isCompleted,
  }) async {
    final tasks = await getTasks(project);
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) {
      throw StateError('Task not found.');
    }
    final updated = [...tasks];
    updated[index] = updated[index].copyWith(isCompleted: isCompleted);
    await _writeTasks(project, updated);
  }

  Future<void> _writeTasks(
    QxProject project,
    List<WorkspaceTask> tasks,
  ) async {
    final file = await _taskFile(project);
    await file.writeAsString(
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
      flush: true,
    );
  }
}
