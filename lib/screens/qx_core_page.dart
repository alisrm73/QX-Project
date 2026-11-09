import 'package:flutter/material.dart';

import '../models/qx_project.dart';
import '../services/project_store.dart';
import 'tools_page.dart';

class QxCorePage extends StatefulWidget {
  const QxCorePage({super.key, this.store});

  final ProjectStore? store;

  @override
  State<QxCorePage> createState() => _QxCorePageState();
}

class _QxCorePageState extends State<QxCorePage> {
  late final ProjectStore _store;
  late Future<List<QxProject>> _projects;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ProjectStore();
    _projects = _store.getProjects();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('QX Core')),
        backgroundColor: const Color(0xFF0B0D13),
        body: FutureBuilder<List<QxProject>>(
          future: _projects,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('تعذّر قراءة بيانات المشاريع / Could not read project data'));
            }
            final projects = snapshot.data ?? const <QxProject>[];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.hub_outlined, size: 54, color: Color(0xFF25B99A)),
                const SizedBox(height: 12),
                const Text('مركز إدارة المشاريع المحلي / Local project hub',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'هذه النسخة تعرض بيانات مشاريعك المحلية وتفتح أدوات الفحص. محرك الذكاء الاصطناعي والاتصال بالإنترنت مؤجلان إلى مرحلة الربط اللاحقة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9DA2B4)),
                ),
                const SizedBox(height: 20),
                Card(
                  color: const Color(0xFF151923),
                  child: ListTile(
                    leading: const Icon(Icons.folder_open_rounded),
                    title: const Text('المشاريع المحفوظة / Saved projects'),
                    trailing: Text(projects.length.toString()),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ToolsPage()),
                  ),
                  icon: const Icon(Icons.build_circle_outlined),
                  label: const Text('فتح أدوات الفحص / Open project tools'),
                ),
              ],
            );
          },
        ),
      );
}
