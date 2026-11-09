import 'package:flutter/material.dart';

import '../models/qx_project.dart';
import '../models/workspace_task.dart';
import '../services/task_store.dart';

class ProjectTasksPage extends StatefulWidget {
  const ProjectTasksPage({
    super.key,
    required this.project,
    this.store,
  });

  final QxProject project;
  final TaskStore? store;

  @override
  State<ProjectTasksPage> createState() => _ProjectTasksPageState();
}

class _ProjectTasksPageState extends State<ProjectTasksPage> {
  late final TaskStore _store = widget.store ?? TaskStore();
  List<WorkspaceTask> _tasks = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    try {
      final tasks = await _store.getTasks(widget.project);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _addTask() async {
    final input = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _AddTaskDialog(),
    );
    if (input == null || !mounted) return;
    if (input.$1.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل عنوان المهمة / Enter a task title'),
        ),
      );
      return;
    }
    try {
      await _store.addTask(
        widget.project,
        title: input.$1,
        notes: input.$2,
      );
      if (mounted) await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّرت إضافة المهمة / Could not add task'),
        ),
      );
    }
  }

  Future<void> _setCompleted(WorkspaceTask task, bool completed) async {
    try {
      await _store.setTaskCompleted(
        widget.project,
        taskId: task.id,
        isCompleted: completed,
      );
      if (mounted) await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر تحديث المهمة / Could not update task'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = _tasks.where((task) => task.isCompleted).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('المهام / Tasks · ${widget.project.name}'),
        backgroundColor: const Color(0xFF0B0D13),
        actions: [
          IconButton(
            tooltip: 'إضافة مهمة / Add task',
            onPressed: _addTask,
            icon: const Icon(Icons.add_task_rounded),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0B0D13),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('مهمة جديدة / New task'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _TaskMessage(
                  message: 'تعذّر تحميل المهام / Could not load tasks',
                  action: _reload,
                )
              : _tasks.isEmpty
                  ? const _TaskMessage(
                      message: 'لا توجد مهام بعد / No tasks yet',
                      detail: 'أضف أول مهمة لتنظيم العمل على هذا المشروع / Add your first task to organize this project',
                    )
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                        children: [
                          Card(
                            color: const Color(0xFF151923),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'التقدم / Progress · $completed / ${_tasks.length}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  LinearProgressIndicator(
                                    value: completed / _tasks.length,
                                    minHeight: 7,
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color(0xFF55C99A),
                                    backgroundColor: const Color(0xFF303544),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (final task in _tasks)
                            Card(
                              color: const Color(0xFF151923),
                              child: CheckboxListTile(
                                value: task.isCompleted,
                                onChanged: (value) {
                                  if (value != null) {
                                    _setCompleted(task, value);
                                  }
                                },
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  task.title,
                                  style: TextStyle(
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: task.notes.isEmpty
                                    ? null
                                    : Text(task.notes),
                                secondary: Icon(
                                  task.isCompleted
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: task.isCompleted
                                      ? const Color(0xFF55C99A)
                                      : const Color(0xFF969BAD),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('مهمة جديدة / New task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'عنوان المهمة / Task title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري) / Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء / Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop((
              _titleController.text,
              _notesController.text,
            )),
            child: const Text('إضافة / Add'),
          ),
        ],
      );
}

class _TaskMessage extends StatelessWidget {
  const _TaskMessage({required this.message, this.detail, this.action});

  final String message;
  final String? detail;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.task_alt_rounded,
                size: 46,
                color: Color(0xFF55C99A),
              ),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(detail!, textAlign: TextAlign.center),
              ],
              if (action != null) ...[
                const SizedBox(height: 14),
                FilledButton.tonal(
                  onPressed: action,
                  child: const Text('إعادة المحاولة / Retry'),
                ),
              ],
            ],
          ),
        ),
      );
}
