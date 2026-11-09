import 'dart:convert';
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

class WorkspacePreviewContent {
  const WorkspacePreviewContent({required this.html, required this.css, required this.js});
  final String html;
  final String css;
  final String js;
}

class WorkspaceStore {
  WorkspaceStore({Future<Directory> Function()? directoryProvider})
      : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  static const maxTextFileBytes = 1024 * 1024;

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
      final name =
          entity.uri.pathSegments.where((part) => part.isNotEmpty).last;
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

  Future<String> readTextFile(QxProject project, String fileName) async {
    final file = await _fileFor(project, fileName);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.file) {
      throw FileSystemException(
        'The selected item is not a regular file.',
        file.path,
      );
    }
    final length = await file.length();
    if (length > maxTextFileBytes) {
      throw FileSystemException(
        'Text file exceeds the 1 MB editor limit.',
        file.path,
      );
    }
    return file.readAsString();
  }

  Future<WorkspacePreviewContent> loadWebPreview(QxProject project) async {
    final html = await readTextFile(project, 'index.html');
    Future<String> optional(String name) async {
      final file = await _fileFor(project, name);
      if (!await file.exists()) return '';
      return readTextFile(project, name);
    }
    return WorkspacePreviewContent(
      html: html,
      css: await optional('style.css'),
      js: await optional('script.js'),
    );
  }

  Future<void> createTextFile(
    QxProject project, {
    required String fileName,
    String content = '',
  }) async {
    _validateFileName(fileName);
    _validateContent(content);
    final workspace = await ensureWorkspace(project);
    final file = File('${workspace.path}/$fileName');
    await file.create(exclusive: true);
    await file.writeAsString(content, flush: true);
  }

  Future<void> writeTextFile(
    QxProject project, {
    required String fileName,
    required String content,
  }) async {
    _validateFileName(fileName);
    _validateContent(content);
    final file = await _fileFor(project, fileName);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.file) {
      throw FileSystemException(
        'The selected item is not a regular file.',
        file.path,
      );
    }
    await file.writeAsString(content, flush: true);
  }

  Future<File> _fileFor(QxProject project, String fileName) async {
    _validateFileName(fileName);
    final workspace = await ensureWorkspace(project);
    return File('${workspace.path}/$fileName');
  }

  void _validateFileName(String fileName) {
    if (fileName.trim().isEmpty ||
        fileName != fileName.trim() ||
        fileName == '.' ||
        fileName == '..' ||
        fileName.contains('/') ||
        fileName.contains(String.fromCharCode(92)) ||
        fileName.contains('\u0000')) {
      throw ArgumentError.value(fileName, 'fileName', 'Invalid file name.');
    }
  }

  void _validateContent(String content) {
    if (utf8.encode(content).length > maxTextFileBytes) {
      throw ArgumentError.value(content, 'content', 'Text file is too large.');
    }
  }
}
