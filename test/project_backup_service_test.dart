import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/services/project_backup_service.dart';
import 'package:qx_studio/services/project_store.dart';
import 'package:qx_studio/services/workspace_store.dart';

void main() {
  late Directory tempDirectory;
  late ProjectStore projectStore;
  late WorkspaceStore workspaceStore;
  late ProjectBackupService backupService;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('qx-backup-test-');
    projectStore = ProjectStore(directoryProvider: () async => tempDirectory);
    workspaceStore = WorkspaceStore(directoryProvider: () async => tempDirectory);
    backupService = ProjectBackupService(
      projectStore: projectStore,
      workspaceStore: workspaceStore,
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('exports and restores text, binary files, and empty directories', () async {
    final original = await projectStore.createProject(
      name: 'Backup test',
      type: 'Website',
      description: 'Round-trip test',
    );
    final workspace = await workspaceStore.ensureWorkspace(original);
    await workspaceStore.createTextFile(
      original,
      fileName: 'index.html',
      content: '<h1>QX</h1>',
    );
    await workspaceStore.createDirectory(
      original,
      directoryPath: 'empty-folder',
    );
    final binary = File('${workspace.path}/assets/logo.bin');
    await binary.parent.create(recursive: true);
    await binary.writeAsBytes([0, 1, 2, 127, 255], flush: true);

    final backup = await backupService.createBackup(original);
    final restored = await backupService.restoreAsNewProject(backup);

    expect(restored.id, isNot(original.id));
    expect(restored.name, original.name);
    expect(restored.type, original.type);
    expect(restored.description, original.description);
    expect(
      await workspaceStore.readTextFile(restored, 'index.html'),
      '<h1>QX</h1>',
    );

    final restoredWorkspace = await workspaceStore.ensureWorkspace(restored);
    expect(
      await File('${restoredWorkspace.path}/assets/logo.bin').readAsBytes(),
      [0, 1, 2, 127, 255],
    );
    expect(
      await Directory('${restoredWorkspace.path}/empty-folder').exists(),
      isTrue,
    );
  });

  test('rejects a backup whose file hash does not match', () async {
    final project = await projectStore.createProject(
      name: 'Integrity test',
      type: 'General',
    );
    await workspaceStore.createTextFile(
      project,
      fileName: 'readme.txt',
      content: 'original',
    );
    final backup = await backupService.createBackup(project);
    final payload =
        jsonDecode(utf8.decode(backup)) as Map<String, dynamic>;
    final files = payload['files'] as List<dynamic>;
    final firstFile = files.first as Map<String, dynamic>;
    firstFile['data'] = base64Encode(utf8.encode('tampered'));
    final tampered = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

    await expectLater(
      backupService.restoreAsNewProject(tampered),
      throwsA(isA<FormatException>()),
    );
    expect(await projectStore.getProjects(), hasLength(1));
  });

  test('rejects path traversal before creating a project', () async {
    final project = await projectStore.createProject(
      name: 'Path test',
      type: 'General',
    );
    await workspaceStore.createTextFile(
      project,
      fileName: 'readme.txt',
      content: 'safe',
    );
    final backup = await backupService.createBackup(project);
    final payload =
        jsonDecode(utf8.decode(backup)) as Map<String, dynamic>;
    final files = payload['files'] as List<dynamic>;
    final firstFile = files.first as Map<String, dynamic>;
    firstFile['path'] = '../outside.txt';
    final invalid = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

    await expectLater(
      backupService.restoreAsNewProject(invalid),
      throwsA(isA<FormatException>()),
    );
    expect(await projectStore.getProjects(), hasLength(1));
  });
}
