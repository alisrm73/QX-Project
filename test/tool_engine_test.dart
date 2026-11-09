import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
import 'package:qx_studio/services/tool_engine.dart';
import 'package:qx_studio/services/workspace_store.dart';

void main() {
  late Directory directory;
  late WorkspaceStore workspaceStore;
  final project = QxProject(
    id: 'engine-test',
    name: 'Engine test',
    type: 'Website',
    description: '',
    createdAt: DateTime(2026, 11, 10),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qx-tool-engine-');
    workspaceStore = WorkspaceStore(directoryProvider: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('registers and runs the built-in read-only workspace analysis tool', () async {
    await workspaceStore.createTextFile(
      project,
      fileName: 'index.html',
      content: '<main>QX</main>',
    );
    await workspaceStore.createDirectory(project, directoryPath: 'assets');

    final registry = QxToolRegistry.standard();
    expect(registry.tools.map((tool) => tool.id), ['workspace-analysis']);

    final result = await registry.run(
      'workspace-analysis',
      QxToolContext(project: project, workspaceStore: workspaceStore),
    );

    expect(result.success, isTrue);
    expect(result.toolId, 'workspace-analysis');
    expect(result.messageAr, contains('1 ملف'));
    expect(result.messageAr, contains('1 مجلد'));
    expect(result.messageEn, contains('1 files'));
    expect(await workspaceStore.readTextFile(project, 'index.html'),
        '<main>QX</main>');
  });

  test('rejects execution of an unregistered tool', () async {
    final registry = QxToolRegistry.standard();

    await expectLater(
      registry.run(
        'unknown-tool',
        QxToolContext(project: project, workspaceStore: workspaceStore),
      ),
      throwsArgumentError,
    );
  });

  test('rejects duplicate tool identifiers', () {
    const tool = _TestTool();
    expect(
      () => QxToolRegistry([tool, tool]),
      throwsArgumentError,
    );
  });
}

class _TestTool implements QxTool {
  const _TestTool();

  @override
  String get id => 'duplicate';

  @override
  String get nameAr => 'اختبار';

  @override
  String get nameEn => 'Test';

  @override
  String get descriptionAr => 'أداة اختبار';

  @override
  Future<QxToolResult> run(QxToolContext context) async => const QxToolResult(
        toolId: 'duplicate',
        success: true,
        messageAr: 'نجاح',
        messageEn: 'Success',
      );
}
