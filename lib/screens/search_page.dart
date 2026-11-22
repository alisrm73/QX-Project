import 'package:flutter/material.dart';

import '../models/qx_project.dart';
import '../services/project_store.dart';
import '../services/workspace_store.dart';
import 'workspace_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.store});

  final ProjectStore? store;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  late Future<List<QxProject>> _projects;

  @override
  void initState() {
    super.initState();
    _projects = (widget.store ?? ProjectStore()).getProjects();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('البحث / Search')),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'ابحث في مشاريعك / Search your projects',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<QxProject>>(
                future: _projects,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('تعذّر تحميل المشاريع / Could not load projects'));
                  }
                  final query = _controller.text.trim().toLowerCase();
                  final matches = (snapshot.data ?? const <QxProject>[])
                      .where((project) =>
                          project.name.toLowerCase().contains(query) ||
                          project.type.toLowerCase().contains(query) ||
                          project.description.toLowerCase().contains(query))
                      .toList();
                  if (matches.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج / No results'));
                  }
                  return ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final project = matches[index];
                      return ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(project.name),
                        subtitle: Text(project.type),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProjectWorkspacePage(project: project, store: WorkspaceStore()),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
}
