import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/qx_project.dart';

class ProjectStore {
  ProjectStore({Future<Directory> Function()? directoryProvider})
      : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  static const _fileName = 'qx_projects.json';

  final Future<Directory> Function() _directoryProvider;

  Future<List<QxProject>> getProjects() async {
    final file = await _projectsFile();
    if (!await file.exists()) return const [];

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      throw const FormatException('Invalid local projects file format.');
    }

    return decoded
        .map((item) => QxProject.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<QxProject> createProject({
    required String name,
    required String type,
    String description = '',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Project name cannot be empty.');
    }

    final projects = (await getProjects()).toList();
    final project = QxProject(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: cleanName,
      type: type.trim().isEmpty ? 'مشروع عام' : type.trim(),
      description: description.trim(),
      createdAt: DateTime.now(),
    );

    projects.add(project);
    final file = await _projectsFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        projects.map((item) => item.toJson()).toList(),
      ),
      flush: true,
    );
    return project;
  }

  Future<File> _projectsFile() async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/$_fileName');
  }
}
