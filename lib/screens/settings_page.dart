import 'package:flutter/material.dart';

import '../services/local_profile_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.store});

  final LocalProfileStore? store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final LocalProfileStore _store;
  final _nameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? LocalProfileStore();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _store.load();
      if (!mounted) return;
      _nameController.text = profile.displayName;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل الملف المحلي / Could not load local profile';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _store.save(LocalProfile(displayName: _nameController.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الملف على الهاتف / Profile saved on this device')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر الحفظ / Could not save profile');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الإعدادات والملف الشخصي / Settings & profile')),
        backgroundColor: const Color(0xFF0B0D13),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(Icons.person_outline_rounded, size: 52, color: Color(0xFFAA9FFF)),
                  const SizedBox(height: 14),
                  const Text('ملف مستخدم محلي / Local user profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                    'لا يوجد تسجيل دخول أو كلمة سر أو اتصال بخادم. تُحفظ البيانات على هذا الهاتف فقط.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9DA2B4)),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الظاهر / Display name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'جارٍ الحفظ / Saving' : 'حفظ على الهاتف / Save locally'),
                  ),
                ],
              ),
      );
}
