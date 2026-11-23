import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/qx_project.dart';
import '../services/project_backup_service.dart';
import '../services/project_store.dart';
import 'project_editor_page.dart';

class MyProjectsPage extends StatefulWidget {
  const MyProjectsPage({super.key, this.store});

  final ProjectStore? store;

  @override
  State<MyProjectsPage> createState() => _MyProjectsPageState();
}

class _MyProjectsPageState extends State<MyProjectsPage> {
  late Future<List<QxProject>> _projectsFuture;
  bool _backupBusy = false;

  ProjectStore get _store => widget.store ?? ProjectStore();
  ProjectBackupService get _backup =>
      ProjectBackupService(projectStore: _store);

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  void _loadProjects() {
    _projectsFuture = _store.getProjects();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _refresh() async {
    setState(_loadProjects);
    await _projectsFuture;
  }

  Future<void> _openProject(QxProject project) async {
    await Navigator.of(context).push<QxProject>(
      MaterialPageRoute(
        builder: (_) => ProjectEditorPage(
          project: project,
          store: _store,
        ),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _exportProject(QxProject project) async {
    if (_backupBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تصدير نسخة المشروع'),
        content: const Text(
          'سيحتوي الملف على ملفات المشروع وبياناته. ملف النسخة غير مشفّر محلياً من QX؛ لا تضع فيه كلمات مرور أو مفاتيح سرية. بعد حفظه افتح MEGA وارفع الملف إلى حسابك. الحد الأقصى للنسخة 12 MB من الملفات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _backupBusy = true);
    try {
      final bytes = await _backup.createBackup(project);
      final output = await FilePicker.saveFile(
        dialogTitle: 'حفظ نسخة المشروع لرفعها إلى MEGA',
        fileName: 'QX-${project.id}.qxbackup',
        bytes: bytes,
      );
      if (!mounted) return;
      if (output == null) {
        _showMessage('تم إلغاء حفظ النسخة.');
      } else {
        _showMessage(
          'تم إنشاء النسخة. افتح MEGA وارفع ملف QX بصيغة qxbackup من مجلد التنزيلات.',
        );
      }
    } catch (error) {
      _showMessage('تعذّر إنشاء النسخة: $error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      final selected = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['qxbackup'],
        allowMultiple: false,
        withData: true,
      );
      if (selected == null || selected.files.isEmpty) return;

      final bytes = selected.files.single.bytes;
      if (bytes == null) {
        throw const FormatException('تعذّر قراءة ملف النسخة المحدد.');
      }
      final restored = await _backup.restoreAsNewProject(bytes);
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      _showMessage('تمت استعادة «${restored.name}» كمشروع جديد دون استبدال مشروع موجود.');
    } catch (error) {
      _showMessage('تعذّرت استعادة النسخة: $error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('مشاريعي / My projects'),
          backgroundColor: const Color(0xFF0B0D13),
          actions: [
            IconButton(
              tooltip: 'استعادة نسخة من MEGA بعد تنزيلها / Restore downloaded backup',
              onPressed: _backupBusy ? null : _restoreBackup,
              icon: const Icon(Icons.cloud_download_outlined),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0B0D13),
        body: FutureBuilder<List<QxProject>>(
          future: _projectsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MessageState(
                icon: Icons.error_outline_rounded,
                message: 'تعذّر تحميل المشاريع / Could not load projects',
                actionLabel: 'إعادة المحاولة / Retry',
                onAction: () => setState(_loadProjects),
              );
            }

            final projects = snapshot.data ?? const <QxProject>[];
            if (projects.isEmpty) {
              return const _MessageState(
                icon: Icons.folder_open_rounded,
                message: 'لا توجد مشاريع بعد / No projects yet',
                detail:
                    'أنشئ مشروعك الأول من الصفحة الرئيسية / Create your first project from Home',
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: projects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => _openProject(project),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151923),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .07),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7566F2)
                                    .withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.folder_rounded,
                                color: Color(0xFFAA9FFF),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    project.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    project.type,
                                    style: const TextStyle(
                                      color: Color(0xFFAA9FFF),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (project.description.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      project.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF969BAD),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              enabled: !_backupBusy,
                              tooltip: 'إجراءات المشروع',
                              onSelected: (value) {
                                if (value == 'backup') {
                                  _exportProject(project);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem<String>(
                                  value: 'backup',
                                  child: Text('تصدير نسخة لرفعها إلى MEGA'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 46, color: const Color(0xFF9286FF)),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF969BAD),
                    fontSize: 12,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
}
