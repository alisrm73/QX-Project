import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../models/qx_project.dart';
import 'workspace_store.dart';

class ProjectZipBackup {
  const ProjectZipBackup({
    required this.file,
    required this.fileCount,
    required this.directoryCount,
    required this.totalBytes,
    required this.sha256,
    required this.createdAt,
  });

  final File file;
  final int fileCount;
  final int directoryCount;
  final int totalBytes;
  final String sha256;
  final DateTime createdAt;
}

/// Creates independent, local ZIP snapshots of individual QX Studio projects.
///
/// Backups are stored outside the project workspace so a backup can never
/// accidentally include itself. Existing backup files are never overwritten.
class ProjectZipBackupService {
  ProjectZipBackupService({
    WorkspaceStore? workspaceStore,
    Future<Directory> Function()? directoryProvider,
    DateTime Function()? clock,
  })  : _workspaceStore = workspaceStore ?? WorkspaceStore(),
        _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory,
        _clock = clock ?? DateTime.now;

  final WorkspaceStore _workspaceStore;
  final Future<Directory> Function() _directoryProvider;
  final DateTime Function() _clock;

  Future<ProjectZipBackup> createBackup(QxProject project) async {
    final workspace = await _workspaceStore.ensureWorkspace(project);
    final entries = await _workspaceStore.listEntries(project);
    final files = entries.where((entry) => !entry.isDirectory).toList();
    final directories = entries.where((entry) => entry.isDirectory).toList();

    final documents = await _directoryProvider();
    final backupDirectory =
        Directory('${documents.path}/qx_backups/${project.id}');
    await backupDirectory.create(recursive: true);

    final createdAt = _clock().toUtc();
    final timestamp = _timestamp(createdAt);
    final projectSlug = _projectSlug(project.name);
    final baseName = '${projectSlug}_${timestamp}';
    final output = File('${backupDirectory.path}/${baseName}.zip');
    final temporary = File('${backupDirectory.path}/.${baseName}.zip.part');

    if (await output.exists() || await temporary.exists()) {
      throw FileSystemException(
        'A backup with this timestamp already exists. No file was replaced.',
        output.path,
      );
    }

    final encoder = ZipFileEncoder();
    var encoderOpened = false;
    try {
      encoder.create(temporary.path, level: 6);
      encoderOpened = true;

      // Add directory records first so empty folders survive restoration.
      for (final entry in directories) {
        _validateArchivePath(entry.relativePath);
        encoder.addArchiveFile(
          ArchiveFile.directory('${entry.relativePath}/'),
        );
      }

      // WorkspaceStore omits symbolic links. Re-check each entry immediately
      // before opening it to avoid following a link introduced after listing.
      for (final entry in files) {
        _validateArchivePath(entry.relativePath);
        final source = File('${workspace.path}/${entry.relativePath}');
        final type = await FileSystemEntity.type(
          source.path,
          followLinks: false,
        );
        if (type != FileSystemEntityType.file) {
          throw FileSystemException(
            'A workspace entry changed or is not a regular file.',
            source.path,
          );
        }
        await encoder.addFile(source, entry.relativePath);
      }

      await encoder.close();
      encoderOpened = false;

      final verified = _verifyArchive(temporary, files, directories);
      if (verified != files.length + directories.length) {
        throw const FormatException('ZIP verification returned an unexpected entry count.');
      }

      final digest = await sha256.bind(temporary.openRead()).first;
      final totalBytes = files.fold<int>(0, (sum, entry) => sum + entry.size);

      // Rename only after ZIP integrity verification and SHA-256 calculation.
      await temporary.rename(output.path);

      return ProjectZipBackup(
        file: output,
        fileCount: files.length,
        directoryCount: directories.length,
        totalBytes: totalBytes,
        sha256: digest.toString(),
        createdAt: createdAt,
      );
    } catch (_) {
      if (encoderOpened) {
        try {
          await encoder.close();
        } catch (_) {
          // Preserve the original failure; cleanup below removes the partial ZIP.
        }
      }
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
  }

  int _verifyArchive(
    File zipFile,
    List<WorkspaceEntry> files,
    List<WorkspaceEntry> directories,
  ) {
    final input = InputFileStream(zipFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input, verify: true);
      final expectedFiles = files.map((entry) => entry.relativePath).toSet();
      final expectedDirectories =
          directories.map((entry) => '${entry.relativePath}/').toSet();
      final actualFiles = archive.files
          .where((entry) => entry.isFile)
          .map((entry) => entry.name)
          .toSet();
      final actualDirectories = archive.files
          .where((entry) => entry.isDirectory)
          .map((entry) => entry.name)
          .toSet();

      if (actualFiles.length != expectedFiles.length ||
          actualFiles.difference(expectedFiles).isNotEmpty ||
          expectedFiles.difference(actualFiles).isNotEmpty ||
          actualDirectories.length != expectedDirectories.length ||
          actualDirectories.difference(expectedDirectories).isNotEmpty ||
          expectedDirectories.difference(actualDirectories).isNotEmpty) {
        throw const FormatException(
          'The ZIP contents do not match the project workspace.',
        );
      }
      return archive.files.length;
    } finally {
      input.closeSync();
    }
  }

  void _validateArchivePath(String path) {
    final segments = path.split('/');
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.contains('\\') ||
        path.contains('\u0000') ||
        segments.any(
          (segment) =>
              segment.isEmpty ||
              segment == '.' ||
              segment == '..' ||
              segment != segment.trim(),
        )) {
      throw ArgumentError.value(path, 'path', 'Unsafe ZIP entry path.');
    }
  }

  String _projectSlug(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'project' : slug;
  }

  String _timestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    String three(int number) => number.toString().padLeft(3, '0');
    return '${value.year}${two(value.month)}${two(value.day)}_'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}_'
        '${three(value.millisecond)}${three(value.microsecond)}';
  }
}
