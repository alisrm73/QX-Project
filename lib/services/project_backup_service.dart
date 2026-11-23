import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/qx_project.dart';
import 'project_store.dart';
import 'workspace_store.dart';

/// Creates and restores a portable, integrity-checked QX project backup.
///
/// The .qxbackup format is JSON with Base64 file contents and SHA-256 hashes.
/// It is intentionally not a ZIP archive and has no dependency on a cloud API.
class ProjectBackupService {
  ProjectBackupService({
    ProjectStore? projectStore,
    WorkspaceStore? workspaceStore,
  })  : _projectStore = projectStore ?? ProjectStore(),
        _workspaceStore = workspaceStore ?? WorkspaceStore();

  static const formatName = 'qxstudio-project-backup';
  static const schemaVersion = 1;
  static const maxTotalFileBytes = 12 * 1024 * 1024;
  static const maxBackupBytes = 18 * 1024 * 1024;
  static const maxFiles = 3000;
  static const maxDirectories = 3000;

  final ProjectStore _projectStore;
  final WorkspaceStore _workspaceStore;

  Future<Uint8List> createBackup(QxProject project) async {
    final workspace = await _workspaceStore.ensureWorkspace(project);
    final entries = await _workspaceStore.listEntries(project);
    final directories = <String>[];
    final files = <Map<String, Object?>>[];
    var totalBytes = 0;

    for (final entry in entries) {
      _validateRelativePath(entry.relativePath);
      if (entry.isDirectory) {
        directories.add(entry.relativePath);
        continue;
      }

      final filePath = _absolutePath(workspace, entry.relativePath);
      final type = await FileSystemEntity.type(filePath, followLinks: false);
      if (type != FileSystemEntityType.file) {
        throw FileSystemException(
          'Backup stopped because a workspace entry is not a regular file.',
          filePath,
        );
      }

      final data = await File(filePath).readAsBytes();
      totalBytes += data.length;
      if (totalBytes > maxTotalFileBytes) {
        throw StateError('Project backup exceeds the 12 MB safety limit.');
      }

      files.add({
        'path': entry.relativePath,
        'size': data.length,
        'sha256': sha256.convert(data).toString(),
        'data': base64Encode(data),
      });
      if (files.length > maxFiles) {
        throw StateError('Project backup contains too many files.');
      }
    }

    if (directories.length > maxDirectories) {
      throw StateError('Project backup contains too many directories.');
    }

    final payload = <String, Object?>{
      'format': formatName,
      'schemaVersion': schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'project': project.toJson(),
      'directories': directories,
      'files': files,
      'integrity': 'sha256-per-file',
    };
    final encoded = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    if (encoded.length > maxBackupBytes) {
      throw StateError('Generated backup exceeds the 18 MB safety limit.');
    }
    return Uint8List.fromList(encoded);
  }

  Future<QxProject> restoreAsNewProject(Uint8List backupBytes) async {
    if (backupBytes.isEmpty || backupBytes.length > maxBackupBytes) {
      throw const FormatException('Backup file size is invalid.');
    }

    final decoded = jsonDecode(utf8.decode(backupBytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != formatName ||
        decoded['schemaVersion'] != schemaVersion ||
        decoded['integrity'] != 'sha256-per-file') {
      throw const FormatException('Unsupported or invalid QX backup format.');
    }

    final projectData = decoded['project'];
    if (projectData is! Map<String, dynamic>) {
      throw const FormatException('Backup project metadata is missing.');
    }
    final name = projectData['name'];
    final type = projectData['type'];
    final description = projectData['description'];
    if (name is! String || name.trim().isEmpty ||
        type is! String ||
        (description != null && description is! String)) {
      throw const FormatException('Backup project metadata is invalid.');
    }

    final rawDirectories = decoded['directories'];
    final rawFiles = decoded['files'];
    if (rawDirectories is! List || rawFiles is! List ||
        rawDirectories.length > maxDirectories ||
        rawFiles.length > maxFiles) {
      throw const FormatException('Backup file and directory lists are invalid.');
    }

    final directories = <String>{};
    for (final value in rawDirectories) {
      if (value is! String) {
        throw const FormatException('Backup contains an invalid directory path.');
      }
      _validateRelativePath(value);
      if (!directories.add(value)) {
        throw const FormatException('Backup contains duplicate directory paths.');
      }
    }

    final files = <_RestoredFile>[];
    final filePaths = <String>{};
    var totalBytes = 0;
    for (final value in rawFiles) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Backup contains an invalid file entry.');
      }
      final path = value['path'];
      final size = value['size'];
      final digest = value['sha256'];
      final encodedData = value['data'];
      if (path is! String || size is! int || size < 0 ||
          digest is! String || encodedData is! String) {
        throw const FormatException('Backup file metadata is invalid.');
      }
      _validateRelativePath(path);
      if (!filePaths.add(path) || directories.contains(path)) {
        throw const FormatException('Backup contains duplicate or conflicting paths.');
      }

      final data = base64Decode(encodedData);
      if (data.length != size ||
          sha256.convert(data).toString() != digest.toLowerCase()) {
        throw FormatException('Backup integrity check failed for: $path');
      }
      totalBytes += data.length;
      if (totalBytes > maxTotalFileBytes) {
        throw const FormatException('Backup exceeds the 12 MB restore limit.');
      }
      files.add(_RestoredFile(path: path, bytes: data));
    }

    for (final path in filePaths) {
      final segments = path.split('/');
      for (var i = 1; i < segments.length; i++) {
        final parent = segments.take(i).join('/');
        if (filePaths.contains(parent)) {
          throw const FormatException('A file path conflicts with a parent path.');
        }
      }
    }
    for (final directory in directories) {
      final segments = directory.split('/');
      for (var i = 1; i < segments.length; i++) {
        final parent = segments.take(i).join('/');
        if (filePaths.contains(parent)) {
          throw const FormatException('A directory conflicts with a file path.');
        }
      }
    }

    final project = await _projectStore.createProject(
      name: name.trim(),
      type: type,
      description: description is String ? description : '',
    );

    Directory? workspace;
    var workspaceIsSafeToRollback = false;
    try {
      workspace = await _workspaceStore.ensureWorkspace(project);
      final existingEntries = await _workspaceStore.listEntries(project);
      if (existingEntries.isNotEmpty) {
        throw StateError('Refusing to restore over an existing workspace.');
      }
      workspaceIsSafeToRollback = true;

      for (final directory in directories) {
        final path = _absolutePath(workspace, directory);
        await Directory(path).create(recursive: true);
      }
      for (final file in files) {
        final path = _absolutePath(workspace, file.path);
        final target = File(path);
        await target.parent.create(recursive: true);
        await target.create(exclusive: true);
        await target.writeAsBytes(file.bytes, flush: true);
      }
      return project;
    } catch (_) {
      if (workspace != null && workspaceIsSafeToRollback &&
          await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
      await _projectStore.deleteProject(project.id);
      rethrow;
    }
  }

  String _absolutePath(Directory workspace, String relativePath) {
    _validateRelativePath(relativePath);
    final platformPath =
        relativePath.replaceAll('/', Platform.pathSeparator);
    return '${workspace.path}${Platform.pathSeparator}$platformPath';
  }

  void _validateRelativePath(String path) {
    if (path.isEmpty || path != path.trim() ||
        path.startsWith('/') ||
        path.contains(String.fromCharCode(92)) ||
        path.contains('\u0000')) {
      throw FormatException('Invalid relative path: $path');
    }
    final segments = path.split('/');
    if (segments.any((part) =>
        part.isEmpty || part == '.' || part == '..' || part != part.trim())) {
      throw FormatException('Invalid relative path: $path');
    }
  }
}

class _RestoredFile {
  const _RestoredFile({required this.path, required this.bytes});

  final String path;
  final List<int> bytes;
}
