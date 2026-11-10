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

class WorkspaceAnalysis {
  const WorkspaceAnalysis({
    required this.fileCount,
    required this.directoryCount,
    required this.totalBytes,
    required this.extensionCounts,
    required this.hasIndexHtml,
    required this.hasStyleCss,
    required this.hasScriptJs,
  });

  final int fileCount;
  final int directoryCount;
  final int totalBytes;
  final Map<String, int> extensionCounts;
  final bool hasIndexHtml;
  final bool hasStyleCss;
  final bool hasScriptJs;
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
    final workspace = Directory('${base.path}/qx_workspaces/${project.id}');
    if (!await workspace.exists()) await workspace.create(recursive: true);
    return workspace;
  }

  Future<List<WorkspaceEntry>> listEntries(QxProject project) async {
    final workspace = await ensureWorkspace(project);
    final entries = <WorkspaceEntry>[];
    await for (final entity in workspace.list(recursive: true, followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.directory) continue;
      final relativePath = entity.path.substring(workspace.path.length + 1);
      final name = relativePath.split(Platform.pathSeparator).last;
      final isDirectory = type == FileSystemEntityType.directory;
      entries.add(WorkspaceEntry(
        name: name,
        relativePath: relativePath.replaceAll(Platform.pathSeparator, '/'),
        isDirectory: isDirectory,
        size: isDirectory ? 0 : await File(entity.path).length(),
      ));
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.relativePath.toLowerCase().compareTo(b.relativePath.toLowerCase());
    });
    return entries;
  }

  Future<WorkspaceAnalysis> analyzeWorkspace(QxProject project) async {
    final entries = await listEntries(project);
    final files = entries.where((entry) => !entry.isDirectory).toList();
    final extensions = <String, int>{};
    var totalBytes = 0;
    for (final file in files) {
      totalBytes += file.size;
      final dot = file.name.lastIndexOf('.');
      final extension = dot <= 0 ? '(no extension)' : file.name.substring(dot).toLowerCase();
      extensions.update(extension, (count) => count + 1, ifAbsent: () => 1);
    }
    final rootFiles = files.map((file) => file.relativePath).toSet();
    return WorkspaceAnalysis(
      fileCount: files.length,
      directoryCount: entries.where((entry) => entry.isDirectory).length,
      totalBytes: totalBytes,
      extensionCounts: Map.unmodifiable(extensions),
      hasIndexHtml: rootFiles.contains('index.html'),
      hasStyleCss: rootFiles.contains('style.css'),
      hasScriptJs: rootFiles.contains('script.js'),
    );
  }

  Future<String> readTextFile(QxProject project, String fileName) async {
    final file = await _fileFor(project, fileName);
    if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.file) {
      throw FileSystemException('The selected item is not a regular file.', file.path);
    }
    if (await file.length() > maxTextFileBytes) {
      throw FileSystemException('Text file exceeds the 1 MB editor limit.', file.path);
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

  Future<void> createDirectory(QxProject project, {required String directoryPath}) async {
    final path = await _pathFor(project, directoryPath);
    if (await FileSystemEntity.type(path, followLinks: false) != FileSystemEntityType.notFound) {
      throw FileSystemException('The selected path already exists.', path);
    }
    await Directory(path).create(recursive: true);
  }

  Future<void> createTextFile(QxProject project, {
    required String fileName,
    String content = '',
  }) async {
    _validateRelativePath(fileName);
    _validateContent(content);
    final file = await _fileFor(project, fileName);
    await file.parent.create(recursive: true);
    await file.create(exclusive: true);
    await file.writeAsString(content, flush: true);
  }

  Future<void> writeTextFile(QxProject project, {
    required String fileName,
    required String content,
  }) async {
    _validateRelativePath(fileName);
    _validateContent(content);
    final file = await _fileFor(project, fileName);
    if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.file) {
      throw FileSystemException('The selected item is not a regular file.', file.path);
    }
    await file.writeAsString(content, flush: true);
  }

  Future<File> _fileFor(QxProject project, String relativePath) async =>
      File(await _pathFor(project, relativePath));

  Future<String> _pathFor(QxProject project, String relativePath) async {
    _validateRelativePath(relativePath);
    final workspace = await ensureWorkspace(project);
    final segments = relativePath.split('/');
    var parent = workspace.path;
    for (final segment in segments.take(segments.length - 1)) {
      parent = '$parent/$segment';
      final type = await FileSystemEntity.type(parent, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw FileSystemException('Symbolic links are not allowed in workspace paths.', parent);
      }
      if (type != FileSystemEntityType.directory && type != FileSystemEntityType.notFound) {
        throw FileSystemException('A path segment is not a directory.', parent);
      }
    }
    final target = '$parent/${segments.last}';
    if (await FileSystemEntity.type(target, followLinks: false) == FileSystemEntityType.link) {
      throw FileSystemException('Symbolic links are not allowed in workspace paths.', target);
    }
    return target;
  }

  void _validateRelativePath(String path) {
    if (path.isEmpty || path != path.trim() ||
        path.contains(String.fromCharCode(92)) || path.contains('\u0000')) {
      throw ArgumentError.value(path, 'path', 'Invalid relative path.');
    }
    final segments = path.split('/');
    if (segments.any((part) => part.isEmpty || part == '.' || part == '..' || part != part.trim())) {
      throw ArgumentError.value(path, 'path', 'Invalid relative path.');
    }
  }

  void _validateContent(String content) {
    if (utf8.encode(content).length > maxTextFileBytes) {
      throw ArgumentError.value(content, 'content', 'Text file is too large.');
    }
  }
}
