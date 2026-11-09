import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
import 'package:qx_studio/models/workspace_task.dart';
import 'package:qx_studio/screens/project_tasks_page.dart';
import 'package:qx_studio/services/task_store.dart';

void main() {
  final project = QxProject(
    id: 'task-ui',
    name: 'Task UI project',
    type: 'App',
    description: '',
    createdAt: DateTime(2026, 11, 9),
  );

  testWidgets('shows empty state and adds a task', (tester) async {
    final store = _FakeTaskStore();

    await tester.pumpWidget(
      MaterialApp(home: ProjectTasksPage(project: project, store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('لا توجد مهام بعد / No tasks yet'), findsOneWidget);
    await tester.tap(find.text('مهمة جديدة / New task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Prepare release');
    await tester.tap(find.text('إضافة / Add'));
    await tester.pumpAndSettle();

    expect(find.text('Prepare release'), findsOneWidget);
    expect(store.tasks, hasLength(1));
  });

  testWidgets('marks a task completed', (tester) async {
    final store = _FakeTaskStore()
      ..tasks.add(
        WorkspaceTask(
          id: 'task-1',
          title: 'Run tests',
          notes: '',
          isCompleted: false,
          createdAt: DateTime(2026, 11, 9),
        ),
      );

    await tester.pumpWidget(
      MaterialApp(home: ProjectTasksPage(project: project, store: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(store.tasks.single.isCompleted, isTrue);
    expect(find.text('التقدم / Progress · 1 / 1'), findsOneWidget);
  });
}

class _FakeTaskStore extends TaskStore {
  final List<WorkspaceTask> tasks = [];

  @override
  Future<List<WorkspaceTask>> getTasks(QxProject project) async =>
      List<WorkspaceTask>.of(tasks);

  @override
  Future<WorkspaceTask> addTask(
    QxProject project, {
    required String title,
    String notes = '',
  }) async {
    final task = WorkspaceTask(
      id: 'task-${tasks.length + 1}',
      title: title.trim(),
      notes: notes.trim(),
      isCompleted: false,
      createdAt: DateTime(2026, 11, 9),
    );
    tasks.add(task);
    return task;
  }

  @override
  Future<void> setTaskCompleted(
    QxProject project, {
    required String taskId,
    required bool isCompleted,
  }) async {
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) throw StateError('Task not found.');
    tasks[index] = tasks[index].copyWith(isCompleted: isCompleted);
  }
}
