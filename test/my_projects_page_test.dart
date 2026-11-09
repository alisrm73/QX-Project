import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/models/qx_project.dart';
import 'package:qx_studio/screens/my_projects_page.dart';
import 'package:qx_studio/services/project_store.dart';

void main() {
  late Directory directory;
  late ProjectStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qx-my-projects-');
    store = ProjectStore(directoryProvider: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  testWidgets('shows the empty state when no projects are saved', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MyProjectsPage(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('لا توجد مشاريع بعد / No projects yet'), findsOneWidget);
  });

  testWidgets('shows locally saved project details', (tester) async {
    await store.createProject(
      name: 'Demo app',
      type: 'تطبيق / App',
      description: 'A local project',
    );

    await tester.pumpWidget(MaterialApp(home: MyProjectsPage(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Demo app'), findsOneWidget);
    expect(find.text('تطبيق / App'), findsOneWidget);
    expect(find.text('A local project'), findsOneWidget);
  });
}
