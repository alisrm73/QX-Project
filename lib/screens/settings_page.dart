import 'package:flutter/material.dart';

import '../services/local_profile_store.dart';
import '../services/telegram_notification_service.dart';
import '../services/telegram_settings_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.store});

  final LocalProfileStore? store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final LocalProfileStore _store;
  late final TelegramSettingsStore _telegramStore;
  late final TelegramNotificationService _telegramService;

  final _nameController = TextEditingController();
  final _tokenController = TextEditingController();
  final _chatIdController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _telegramBusy = false;
  bool _telegramConfigured = false;
  String? _error;
  String? _telegramMessage;
  String? _savedBotToken;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? LocalProfileStore();
    _telegramStore = TelegramSettingsStore();
    _telegramService = TelegramNotificationService(
      settingsStore: _telegramStore,
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _store.load();
      if (!mounted) return;
      _nameController.text = profile.displayName;
    } catch (_) {
      if (!mounted) return;
      _error = 'تعذّر تحميل الملف المحلي / Could not load local profile';
    }

    try {
      final settings = await _telegramStore.read();
      if (!mounted) return;
      _savedBotToken = settings?.botToken;
      _chatIdController.text = settings?.chatId ?? '';
      _telegramConfigured = settings?.isConfigured ?? false;
    } catch (_) {
      if (!mounted) return;
      _telegramMessage = 'تعذّر قراءة إعدادات Telegram المحفوظة';
    }

    if (mounted) setState(() => _loading = false);
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

  Future<void> _saveTelegramSettings() async {
    final token = _tokenController.text.trim().isNotEmpty
        ? _tokenController.text.trim()
        : (_savedBotToken ?? '');
    final chatId = _chatIdController.text.trim();

    if (token.isEmpty || chatId.isEmpty) {
      setState(() {
        _telegramMessage = 'أدخل Bot Token و Chat ID أولاً';
      });
      return;
    }

    setState(() {
      _telegramBusy = true;
      _telegramMessage = null;
    });
    try {
      await _telegramStore.save(botToken: token, chatId: chatId);
      if (!mounted) return;
      setState(() {
        _savedBotToken = token;
        _tokenController.clear();
        _telegramConfigured = true;
        _telegramMessage = 'تم حفظ إعدادات Telegram بأمان';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _telegramMessage = 'تعذّر حفظ إعدادات Telegram';
      });
    } finally {
      if (mounted) setState(() => _telegramBusy = false);
    }
  }

  Future<void> _testTelegram() async {
    setState(() {
      _telegramBusy = true;
      _telegramMessage = null;
    });
    try {
      final result = await _telegramService.sendMessage(
        'اختبار اتصال Telegram من QX Studio',
      );
      if (!mounted) return;

      final message = switch (result.status) {
        TelegramNotificationStatus.sent => 'نجح الاتصال وتم إرسال رسالة الاختبار',
        TelegramNotificationStatus.notConfigured => 'احفظ Bot Token و Chat ID أولاً',
        TelegramNotificationStatus.invalidMessage => 'رسالة الاختبار غير صالحة',
        TelegramNotificationStatus.rejected => 'رفض Telegram الطلب. تحقق من Token و Chat ID',
        TelegramNotificationStatus.invalidResponse => 'استجابة Telegram غير صالحة',
        TelegramNotificationStatus.timedOut => 'انتهت مهلة الاتصال. حاول مرة أخرى',
        TelegramNotificationStatus.networkError => 'تعذّر الاتصال بالشبكة أو بخدمة Telegram',
      };

      setState(() => _telegramMessage = message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _telegramMessage = 'تعذّر اختبار اتصال Telegram';
      });
    } finally {
      if (mounted) setState(() => _telegramBusy = false);
    }
  }

  Future<void> _deleteTelegramSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف إعدادات Telegram؟'),
        content: const Text('سيتم حذف Bot Token و Chat ID من التخزين الآمن على هذا الجهاز.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _telegramBusy = true;
      _telegramMessage = null;
    });
    try {
      await _telegramStore.clear();
      if (!mounted) return;
      setState(() {
        _savedBotToken = null;
        _tokenController.clear();
        _chatIdController.clear();
        _telegramConfigured = false;
        _telegramMessage = 'تم حذف إعدادات Telegram';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _telegramMessage = 'تعذّر حذف إعدادات Telegram';
      });
    } finally {
      if (mounted) setState(() => _telegramBusy = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tokenController.dispose();
    _chatIdController.dispose();
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
                  const SizedBox(height: 32),
                  const Divider(color: Color(0xFF343849)),
                  const SizedBox(height: 16),
                  const Text(
                    'إعدادات Telegram',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _telegramConfigured
                        ? 'الإعدادات محفوظة بأمان على هذا الجهاز'
                        : 'أدخل بيانات بوت Telegram لحفظها على هذا الجهاز',
                    style: const TextStyle(color: Color(0xFF9DA2B4)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tokenController,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Bot Token',
                      hintText: _telegramConfigured ? 'محفوظ — اتركه فارغاً للإبقاء عليه' : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _chatIdController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Chat ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _telegramBusy ? null : _saveTelegramSettings,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('حفظ إعدادات Telegram'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _telegramBusy || !_telegramConfigured ? null : _testTelegram,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('اختبار الاتصال وإرسال رسالة'),
                  ),
                  TextButton.icon(
                    onPressed: _telegramBusy || !_telegramConfigured
                        ? null
                        : _deleteTelegramSettings,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('حذف إعدادات Telegram'),
                  ),
                  if (_telegramMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _telegramMessage!,
                      style: const TextStyle(color: Color(0xFFAA9FFF)),
                    ),
                  ],
                ],
              ),
      );
}
