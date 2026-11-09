import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
import 'package:qx_studio/screens/my_projects_page.dart';
import 'package:qx_studio/services/project_store.dart';

void main() {
  testWidgets('shows the empty state when no projects are saved', (tester) async {
    final store = _FakeProjectStore(const []);

    await tester.pumpWidget(MaterialApp(home: MyProjectsPage(store: store)));
    await tester.pump();

    expect(find.text('لا توجد مشاريع بعد / No projects yet'), findsOneWidget);
  });

  testWidgets('shows saved project details', (tester) async {
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

    expect(find.text('Demo app'), findsOneWidget);
    expect(find.text('تطبيق / App'), findsOneWidget);
    expect(find.text('A local project'), findsOneWidget);
  });
}

class _FakeProjectStore extends ProjectStore {
  _FakeProjectStore(this.projects);

  final List<QxProject> projects;

  @override
  Future<List<QxProject>> getProjects() async => projects;
}
