import 'package:flutter/material.dart';

import '../models/qx_project.dart';
import '../services/project_store.dart';

class MyProjectsPage extends StatefulWidget {
  const MyProjectsPage({super.key, this.store});

  final ProjectStore? store;

  @override
  State<MyProjectsPage> createState() => _MyProjectsPageState();
}

class _MyProjectsPageState extends State<MyProjectsPage> {
  late Future<List<QxProject>> _projectsFuture;

  ProjectStore get _store => widget.store ?? ProjectStore();

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  void _loadProjects() {
    _projectsFuture = _store.getProjects();
  }

  Future<void> _refresh() async {
    setState(_loadProjects);
    await _projectsFuture;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('مشاريعي / My projects'),
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
                detail: 'أنشئ مشروعك الأول من الصفحة الرئيسية / Create your first project from Home',
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
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151923),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: .07)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7566F2).withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(Icons.folder_rounded, color: Color(0xFFAA9FFF)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(project.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(project.type, style: const TextStyle(color: Color(0xFFAA9FFF), fontSize: 12)),
                              if (project.description.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(project.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF969BAD), fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                      ],
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
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(detail!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF969BAD), fontSize: 12)),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}
