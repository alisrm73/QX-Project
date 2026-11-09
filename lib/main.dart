import 'package:flutter/material.dart';

import 'models/qx_project.dart';
import 'services/project_store.dart';

void main() => runApp(const QxStudioApp());

class QxStudioApp extends StatelessWidget {
  const QxStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF7C6CFF);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QX Studio',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF11131B),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0D13),
        fontFamily: 'Roboto',
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: QxHomePage(),
      ),
    );
  }
}

class QxHomePage extends StatelessWidget {
  const QxHomePage({super.key});

  static const _cards = <_StudioCardData>[
    _StudioCardData('مشروع جديد', 'ابدأ فكرة وحوّلها إلى مشروع', Icons.add_rounded, Color(0xFF7868F6)),
    _StudioCardData('مشاريعي', 'تابع أعمالك من مكان واحد', Icons.folder_open_rounded, Color(0xFF3D9BE9)),
    _StudioCardData('QX Core', 'محرك التحليل والتخطيط', Icons.hub_rounded, Color(0xFF25B99A)),
    _StudioCardData('مساحة العمل', 'طوّر مشروعك خطوة بخطوة', Icons.dashboard_customize_rounded, Color(0xFFE39A4D)),
    _StudioCardData('الأدوات', 'أدوات البناء والإنتاج', Icons.widgets_rounded, Color(0xFFD477B8)),
    _StudioCardData('المكتبة', 'ملفاتك ومكوّناتك', Icons.auto_awesome_mosaic_rounded, Color(0xFF5D9EAA)),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 390;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _TopBar(compact: compact)),
                  SliverToBoxAdapter(
                    child: _WelcomePanel(
                      onCreateProject: () => _showCreateProjectDialog(context),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          const Text('مساحتك في QX', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Text('عرض الكل', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _FeatureCard(
                          data: _cards[index],
                          onTap: index == 0
                              ? () => _showCreateProjectDialog(context)
                              : null,
                        ),
                        childCount: _cards.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: compact ? 1 : 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 142,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const _SideRail(),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCreateProjectDialog(BuildContext context) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  var projectType = 'مشروع عام';
  var isSaving = false;

  try {
    final input = await showDialog<_NewProjectInput>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إنشاء مشروع جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم المشروع',
                    hintText: 'اكتب اسم مشروعك',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: projectType,
                  decoration: const InputDecoration(
                    labelText: 'نوع المشروع',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'مشروع عام', child: Text('مشروع عام')),
                    DropdownMenuItem(value: 'تطبيق', child: Text('تطبيق')),
                    DropdownMenuItem(value: 'موقع إلكتروني', child: Text('موقع إلكتروني')),
                    DropdownMenuItem(value: 'أداة', child: Text('أداة')),
                  ],
                  onChanged: isSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            setDialogState(() => projectType = value);
                          }
                        },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'وصف مختصر (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى إدخال اسم المشروع')),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      Navigator.of(dialogContext).pop(
                        _NewProjectInput(
                          name: name,
                          type: projectType,
                          description: descriptionController.text.trim(),
                        ),
                      );
                    },
              child: const Text('إنشاء وحفظ'),
            ),
          ],
        ),
      ),
    );

    if (input == null || !context.mounted) return;

    try {
      final project = await ProjectStore().createProject(
        name: input.name,
        type: input.type,
        description: input.description,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ المشروع «${project.name}» على الهاتف')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ المشروع. تحقق من مساحة التخزين ثم حاول مجدداً.')),
      );
    }
  } finally {
    nameController.dispose();
    descriptionController.dispose();
  }
}

class _NewProjectInput {
  const _NewProjectInput({
    required this.name,
    required this.type,
    required this.description,
  });

  final String name;
  final String type;
  final String description;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(colors: [Color(0xFF9587FF), Color(0xFF5544D8)]),
              ),
              child: const Icon(Icons.bubble_chart_rounded, color: Colors.white, size: 25),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QX Studio', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: .2)),
                Text('حوّل أفكارك إلى واقع', style: TextStyle(color: Color(0xFF9296A8), fontSize: 10)),
              ],
            ),
            const Spacer(),
            _RoundAction(icon: Icons.search_rounded),
            const SizedBox(width: 8),
            _RoundAction(icon: Icons.notifications_none_rounded),
          ],
        ),
      );
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.onCreateProject});

  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF29234F), Color(0xFF171A2B), Color(0xFF151923)],
          ),
          border: Border.all(color: const Color(0xFF7165D8).withValues(alpha: .28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFF796AF4).withValues(alpha: .18), borderRadius: BorderRadius.circular(20)),
              child: const Text('من الفكرة إلى الإنجاز', style: TextStyle(color: Color(0xFFC2BAFF), fontSize: 10, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 13),
            const Text('أهلاً بك في QX Studio', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('أنشئ مشاريعك، نظّم أفكارك، وطوّرها ضمن مساحة واحدة.', style: TextStyle(color: Color(0xFFB4B7C7), fontSize: 12, height: 1.6)),
            const SizedBox(height: 15),
            FilledButton.icon(
              onPressed: onCreateProject,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('ابدأ مشروعاً جديداً'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7566F2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.data, this.onTap});
  final _StudioCardData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF151923),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .065)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: data.color.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(data.icon, color: data.color, size: 21),
                ),
                const Spacer(),
                Text(data.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(data.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF969BAD), fontSize: 10)),
              ],
            ),
          ),
        ),
      );
}

class _SideRail extends StatelessWidget {
  const _SideRail();

  @override
  Widget build(BuildContext context) => Container(
        width: 68,
        margin: const EdgeInsets.fromLTRB(0, 10, 8, 10),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF151823),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: const Column(
          children: [
            _RailButton(icon: Icons.home_rounded, selected: true),
            SizedBox(height: 13),
            _RailButton(icon: Icons.folder_copy_outlined),
            SizedBox(height: 13),
            _RailButton(icon: Icons.hub_outlined),
            SizedBox(height: 13),
            _RailButton(icon: Icons.grid_view_rounded),
            Spacer(),
            _RailButton(icon: Icons.settings_outlined),
            SizedBox(height: 10),
            CircleAvatar(radius: 15, backgroundColor: Color(0xFF393451), child: Icon(Icons.person_outline_rounded, size: 17, color: Color(0xFFD1CBFF))),
          ],
        ),
      );
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, this.selected = false});
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7566F2).withValues(alpha: .2) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: selected ? const Color(0xFFAA9FFF) : const Color(0xFF85899B), size: 21),
      );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: const Color(0xFF171A25), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white.withValues(alpha: .06))),
        child: Icon(icon, color: const Color(0xFFB8BACC), size: 19),
      );
}

class _StudioCardData {
  const _StudioCardData(this.title, this.subtitle, this.icon, this.color);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}
