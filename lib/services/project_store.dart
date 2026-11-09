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
    await _writeProjects(projects);
    return project;
  }

  Future<QxProject> updateProject(QxProject updatedProject) async {
    final projects = (await getProjects()).toList();
    final index = projects.indexWhere(
      (project) => project.id == updatedProject.id,
    );
    if (index == -1) {
      throw StateError('Project not found: ${updatedProject.id}');
    }

    final cleanName = updatedProject.name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(
        updatedProject.name,
        'name',
        'Project name cannot be empty.',
      );
    }

    final savedProject = QxProject(
      id: updatedProject.id,
      name: cleanName,
      type: updatedProject.type.trim().isEmpty
          ? 'مشروع عام'
          : updatedProject.type.trim(),
      description: updatedProject.description.trim(),
      createdAt: updatedProject.createdAt,
    );
    projects[index] = savedProject;
    await _writeProjects(projects);
    return savedProject;
  }

  Future<void> _writeProjects(List<QxProject> projects) async {
    final file = await _projectsFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        projects.map((item) => item.toJson()).toList(),
      ),
      flush: true,
    );
  }

  Future<File> _projectsFile() async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/$_fileName');
  }
}
