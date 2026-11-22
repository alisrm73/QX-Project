import 'package:flutter/material.dart';

import '../models/qx_project.dart';
import '../services/project_store.dart';
import '../services/workspace_store.dart';
import 'workspace_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, this.store});

  final ProjectStore? store;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final ProjectStore _store;
  late Future<List<QxProject>> _projects;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ProjectStore();
    _projects = _store.getProjects();
  }

  Future<void> _reload() async {
    setState(() => _projects = _store.getProjects());
    await _projects;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('المكتبة / Library')),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: FutureBuilder<List<QxProject>>(
          future: _projects,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('تعذّر تحميل المكتبة / Could not load library'));
            }
            final projects = snapshot.data ?? const <QxProject>[];
            if (projects.isEmpty) {
              return const Center(
                child: Text('المكتبة فارغة حالياً. أنشئ مشروعاً لتظهر ملفاته هنا.\nThe library is empty. Create a project to see its workspace here.',
                    textAlign: TextAlign.center),
              );
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('مشاريعك المحلية / Your local projects',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  for (final project in projects)
                    Card(
                      color: Theme.of(context).cardColor,
                      child: ListTile(
                        leading: const Icon(Icons.folder_copy_outlined, color: Color(0xFF5D9EAA)),
                        title: Text(project.name),
                        subtitle: Text(project.type),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProjectWorkspacePage(project: project, store: WorkspaceStore()),
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
