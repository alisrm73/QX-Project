import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
import 'package:qx_studio/screens/file_editor_page.dart';
import 'package:qx_studio/services/workspace_store.dart';

void main() {
  testWidgets('edits a text file and saves the updated content', (tester) async {
    final project = QxProject(
      id: 'editor-test',
      name: 'Editor test',
      type: 'App',
      description: '',
      createdAt: DateTime(2026, 11, 9),
    );
    final store = _FakeWorkspaceStore();

    await tester.pumpWidget(
      MaterialApp(
        home: FileEditorPage(
          project: project,
          store: store,
          fileName: 'main.dart',
          initialContent: 'void main() {}',
        ),
      ),
    );

    final editor = find.byType(TextField);
    await tester.enterText(editor, 'void main() { print("QX"); }');
    await tester.pump();

    await tester.tap(find.text('حفظ / Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(store.savedFileName, 'main.dart');
    expect(store.savedContent, 'void main() { print("QX"); }');
    expect(
      find.text('تم حفظ الملف محلياً / File saved on this device'),
      findsOneWidget,
    );
  });
}

class _FakeWorkspaceStore extends WorkspaceStore {
  String? savedFileName;
  String? savedContent;

  @override
  Future<void> writeTextFile(
    QxProject project, {
    required String fileName,
    required String content,
  }) async {
    savedFileName = fileName;
    savedContent = content;
  }
}
