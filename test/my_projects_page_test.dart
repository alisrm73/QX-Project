import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
import 'package:qx_studio/screens/my_projects_page.dart';
import 'package:qx_studio/services/project_store.dart';

void main() {
  testWidgets('shows the empty state when no projects are saved', (tester) async {
    final store = _FakeProjectStore([]);

    await tester.pumpWidget(MaterialApp(home: MyProjectsPage(store: store)));
    await tester.pump();

    expect(find.text('لا توجد مشاريع بعد / No projects yet'), findsOneWidget);
  });

  testWidgets('opens a saved project and persists edited details',
      (tester) async {
    final store = _FakeProjectStore([
      QxProject(
        id: 'demo-1',
        name: 'Demo app',
        type: 'تطبيق / App',
        description: 'A local project',
        createdAt: DateTime(2026, 11, 9),
      ),
    ]);

    await tester.pumpWidget(MaterialApp(home: MyProjectsPage(store: store)));
    await tester.pump();

    await tester.tap(find.text('Demo app'));
    await tester.pumpAndSettle();

    expect(find.text('فتح المشروع / Open project'), findsOneWidget);
    expect(find.text('تفاصيل المشروع / Project details'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Updated app');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Updated local project',
    );
    await tester.tap(find.text('حفظ التعديلات / Save changes'));
    await tester.pumpAndSettle();

    expect(store.projects.single.name, 'Updated app');
    expect(store.projects.single.description, 'Updated local project');
    expect(find.text('Updated app'), findsOneWidget);
  });
}

class _FakeProjectStore extends ProjectStore {
  _FakeProjectStore(this.projects);

  final List<QxProject> projects;

  @override
  Future<List<QxProject>> getProjects() async => projects;

  @override
  Future<QxProject> updateProject(QxProject updatedProject) async {
    final index = projects.indexWhere(
      (project) => project.id == updatedProject.id,
    );
    if (index == -1) {
      throw StateError('Project not found: ${updatedProject.id}');
    }
    projects[index] = updatedProject;
    return updatedProject;
  }
}
