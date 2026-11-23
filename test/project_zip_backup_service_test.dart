import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
import 'package:qx_studio/services/project_zip_backup_service.dart';
import 'package:qx_studio/services/workspace_store.dart';

void main() {
  late Directory directory;
  late WorkspaceStore workspaceStore;
  late ProjectZipBackupService backupService;
  final project = QxProject(
    id: 'project-zip-123',
    name: 'Sample Project',
    type: 'App',
    description: 'ZIP backup test',
    createdAt: DateTime(2026, 11, 23),
  );
  final fixedTime = DateTime(2026, 11, 23, 10, 11, 12, 123, 456);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qx-zip-backup-');
    workspaceStore = WorkspaceStore(directoryProvider: () async => directory);
    backupService = ProjectZipBackupService(
      workspaceStore: workspaceStore,
      directoryProvider: () async => directory,
      clock: () => fixedTime,
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('creates a verified ZIP containing only the selected project', () async {
    final workspace = await workspaceStore.ensureWorkspace(project);
    await Directory('${workspace.path}/lib/models').create(recursive: true);
    await Directory('${workspace.path}/empty-folder').create();
    await File('${workspace.path}/README.md').writeAsString('QX Studio');
    await File('${workspace.path}/lib/models/item.dart')
        .writeAsString('class Item {}');

    final backup = await backupService.createBackup(project);

    expect(await backup.file.exists(), isTrue);
    expect(backup.file.path, contains('/qx_backups/project-zip-123/'));
    expect(backup.file.path.endsWith('.zip'), isTrue);
    expect(backup.fileCount, 2);
    expect(backup.directoryCount, 2);
    expect(backup.totalBytes, 'QX Studio'.length + 'class Item {}'.length);
    expect(backup.sha256, await sha256.bind(backup.file.openRead()).first.then((value) => value.toString()));

    final archive = ZipDecoder().decodeBytes(
      await backup.file.readAsBytes(),
      verify: true,
    );
    expect(
      archive.files.where((entry) => entry.isFile).map((entry) => entry.name),
      containsAll(['README.md', 'lib/models/item.dart']),
    );
    expect(
      archive.files.where((entry) => entry.isDirectory).map((entry) => entry.name),
      containsAll(['lib/', 'lib/models/', 'empty-folder/']),
    );

    expect(
      await File('${workspace.path}/README.md').readAsString(),
      'QX Studio',
    );
    expect(await File('${workspace.path}/lib/models/item.dart').exists(), isTrue);
  });

  test('creates a valid empty ZIP for a project with no files', () async {
    await workspaceStore.ensureWorkspace(project);

    final backup = await backupService.createBackup(project);
    final archive = ZipDecoder().decodeBytes(
      await backup.file.readAsBytes(),
      verify: true,
    );

    expect(backup.fileCount, 0);
    expect(backup.directoryCount, 0);
    expect(archive.files, isEmpty);
  });

  test('never overwrites an existing backup with the same timestamp', () async {
    final workspace = await workspaceStore.ensureWorkspace(project);
    final source = File('${workspace.path}/README.md');
    await source.writeAsString('original');

    final firstBackup = await backupService.createBackup(project);
    final firstBytes = await firstBackup.file.readAsBytes();

    await source.writeAsString('changed');
    await expectLater(
      backupService.createBackup(project),
      throwsA(isA<FileSystemException>()),
    );

    expect(await firstBackup.file.readAsBytes(), firstBytes);
    expect(await source.readAsString(), 'changed');
  });
}
