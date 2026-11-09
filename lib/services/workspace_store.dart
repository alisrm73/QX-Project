import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/qx_project.dart';

class WorkspaceEntry {
  const WorkspaceEntry({
    required this.name,
    required this.relativePath,
    required this.isDirectory,
    required this.size,
  });

  final String name;
  final String relativePath;
  final bool isDirectory;
  final int size;
}

class WorkspaceStore {
  WorkspaceStore({Future<Directory> Function()? directoryProvider})
      : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<Directory> ensureWorkspace(QxProject project) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(project.id)) {
      throw ArgumentError.value(project.id, 'project.id', 'Invalid project id.');
    }
    final base = await _directoryProvider();
    final workspace = Directory(
      '${base.path}/qx_workspaces/${project.id}',
    );
    if (!await workspace.exists()) {
      await workspace.create(recursive: true);
    }
    return workspace;
  }

  Future<List<WorkspaceEntry>> listEntries(QxProject project) async {
    final workspace = await ensureWorkspace(project);
    final entries = <WorkspaceEntry>[];
    await for (final entity in workspace.list(followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.directory) {
        continue;
      }
      final name = entity.uri.pathSegments.where((part) => part.isNotEmpty).last;
      final isDirectory = type == FileSystemEntityType.directory;
      final size = isDirectory ? 0 : await File(entity.path).length();
      entries.add(
        WorkspaceEntry(
          name: name,
          relativePath: name,
          isDirectory: isDirectory,
          size: size,
        ),
      );
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }
}
