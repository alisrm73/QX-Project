import 'package:flutter/material.dart';

import '../models/qx_project.dart';
import '../services/project_store.dart';
import '../services/workspace_store.dart';
import 'file_editor_page.dart';
import 'project_preview_page.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    super.key,
    this.projectStore,
    this.workspaceStore,
  });

  final ProjectStore? projectStore;
  final WorkspaceStore? workspaceStore;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  late Future<List<QxProject>> _projectsFuture;

  ProjectStore get _projects => widget.projectStore ?? ProjectStore();
  WorkspaceStore get _workspace => widget.workspaceStore ?? WorkspaceStore();

  @override
  void initState() {
    super.initState();
    _projectsFuture = _projects.getProjects();
  }

  Future<void> _reload() async {
    setState(() => _projectsFuture = _projects.getProjects());
    await _projectsFuture;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('مساحة العمل / Workspace'),
          backgroundColor: const Color(0xFF0B0D13),
        ),
        backgroundColor: const Color(0xFF0B0D13),
        body: FutureBuilder<List<QxProject>>(
          future: _projectsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _WorkspaceMessage(
                icon: Icons.error_outline_rounded,
                message: 'تعذّر تحميل المشاريع / Could not load projects',
                action: () => _reload(),
              );
            }
            final projects = snapshot.data ?? const <QxProject>[];
            if (projects.isEmpty) {
              return const _WorkspaceMessage(
                icon: Icons.folder_open_rounded,
                message: 'أنشئ مشروعاً أولاً لفتح مساحة العمل / Create a project first to open its workspace',
              );
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'اختر مشروعاً للعمل عليه / Choose a project to work on',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  for (final project in projects)
                    Card(
                      color: const Color(0xFF151923),
                      child: ListTile(
                        leading: const Icon(
                          Icons.folder_copy_rounded,
                          color: Color(0xFF9286FF),
                        ),
                        title: Text(project.name),
                        subtitle: Text(project.type),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProjectWorkspacePage(
                              project: project,
                              store: _workspace,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
}

class ProjectWorkspacePage extends StatefulWidget {
  const ProjectWorkspacePage({
    super.key,
    required this.project,
    required this.store,
  });

  final QxProject project;
  final WorkspaceStore store;

  @override
  State<ProjectWorkspacePage> createState() => _ProjectWorkspacePageState();
}

class _ProjectWorkspacePageState extends State<ProjectWorkspacePage> {
  late Future<List<WorkspaceEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = widget.store.listEntries(widget.project);
  }

  Future<void> _reload() async {
    setState(() => _entriesFuture = widget.store.listEntries(widget.project));
    await _entriesFuture;
  }

  Future<void> _createFile() async {
    final controller = TextEditingController();
    try {
      final fileName = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('ملف جديد / New file'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) =>
                Navigator.of(dialogContext).pop(value.trim()),
            decoration: const InputDecoration(
              labelText: 'اسم الملف / File name',
              hintText: 'مثال: main.dart',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء / Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('إنشاء / Create'),
            ),
          ],
        ),
      );
      if (fileName == null || fileName.isEmpty || !mounted) return;

      await widget.store.createTextFile(
        widget.project,
        fileName: fileName,
      );
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FileEditorPage(
            project: widget.project,
            store: widget.store,
            fileName: fileName,
            initialContent: '',
          ),
        ),
      );
      if (mounted) await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذّر إنشاء الملف. تحقق من الاسم / Could not create file. Check the file name.',
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openFile(WorkspaceEntry entry) async {
    try {
      final content =
          await widget.store.readTextFile(widget.project, entry.relativePath);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FileEditorPage(
            project: widget.project,
            store: widget.store,
            fileName: entry.relativePath,
            initialContent: content,
          ),
        ),
      );
      if (mounted) await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذّر فتح الملف النصي / Could not open this text file',
          ),
        ),
      );
    }
  }

  Future<void> _openPreview() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectPreviewPage(
          project: widget.project,
          store: widget.store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.project.name),
          backgroundColor: const Color(0xFF0B0D13),
          actions: [
            IconButton(
              tooltip: 'معاينة / Preview',
              onPressed: _openPreview,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
            IconButton(
              tooltip: 'ملف جديد / New file',
              onPressed: _createFile,
              icon: const Icon(Icons.note_add_outlined),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0B0D13),
        body: FutureBuilder<List<WorkspaceEntry>>(
          future: _entriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _WorkspaceMessage(
                icon: Icons.error_outline_rounded,
                message: 'تعذّر تحميل ملفات المشروع / Could not load project files',
                action: () => _reload(),
              );
            }
            final entries = snapshot.data ?? const <WorkspaceEntry>[];
            if (entries.isEmpty) {
              return _WorkspaceMessage(
                icon: Icons.folder_open_rounded,
                message: 'مساحة العمل جاهزة، ولا توجد ملفات بعد / Workspace is ready. No files yet',
                detail: 'استخدم زر الملف الجديد لإنشاء ملف وبدء تحريره / Use New file to create and edit a file',
              );
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    leading: Icon(
                      entry.isDirectory
                          ? Icons.folder_rounded
                          : Icons.insert_drive_file_outlined,
                      color: const Color(0xFF9286FF),
                    ),
                    title: Text(entry.name),
                    subtitle: Text(
                      entry.isDirectory
                          ? 'مجلد / Folder'
                          : '${entry.size} bytes · ملف نصي / Text file',
                    ),
                    trailing: entry.isDirectory
                        ? null
                        : const Icon(Icons.edit_outlined),
                    onTap: entry.isDirectory ? null : () => _openFile(entry),
                  );
                },
              ),
            );
          },
        ),
      );
}

class _WorkspaceMessage extends StatelessWidget {
  const _WorkspaceMessage({
    required this.icon,
    required this.message,
    this.detail,
    this.action,
  });

  final IconData icon;
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
              Icon(icon, size: 46, color: const Color(0xFF9286FF)),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF969BAD)),
                ),
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
