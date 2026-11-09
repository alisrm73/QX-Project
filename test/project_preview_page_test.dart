import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
import 'package:qx_studio/screens/project_preview_page.dart';
import 'package:qx_studio/services/workspace_store.dart';

void main() {
  final project = QxProject(
    id: 'preview-1',
    name: 'Preview test',
    type: 'Website',
    description: '',
    createdAt: DateTime(2026, 11, 9),
  );

  testWidgets('loads saved HTML, CSS, and JavaScript for the preview',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectPreviewPage(
          project: project,
          store: _FakePreviewStore(
            const WorkspacePreviewContent(
              html: '<h1>QX Preview</h1>',
              css: 'h1 { color: purple; }',
              js: 'document.title = "QX";',
            ),
          ),
          previewContentBuilder: (_, content) => Text(
            content.html + '|' + content.css + '|' + content.js,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        '<h1>QX Preview</h1>|h1 { color: purple; }|document.title = "QX";',
      ),
      findsOneWidget,
    );
  });
}

class _FakePreviewStore extends WorkspaceStore {
  _FakePreviewStore(this.content);

  final WorkspacePreviewContent content;

  @override
  Future<WorkspacePreviewContent> loadWebPreview(QxProject project) async =>
      content;
}
