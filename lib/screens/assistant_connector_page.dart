import 'package:flutter/material.dart';

import '../services/assistant_api_client.dart';

class AssistantConnectorPage extends StatefulWidget {
  const AssistantConnectorPage({super.key});

  @override
  State<AssistantConnectorPage> createState() => _AssistantConnectorPageState();
}

class _AssistantConnectorPageState extends State<AssistantConnectorPage> {
  final _api = AssistantApiClient();
  final _endpoint = TextEditingController();
  final _token = TextEditingController();
  final _message = TextEditingController();
  final List<_ChatLine> _messages = [];
  bool _loadingSettings = true;
  bool _busy = false;
  bool _connected = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _token.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final endpoint = await _api.loadEndpoint();
    final token = await _api.loadToken();
    if (!mounted) return;
    setState(() {
      _endpoint.text = endpoint ?? '';
      _token.text = token ?? '';
      _loadingSettings = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _busy = true);
    try {
      await _api.saveConnection(endpoint: _endpoint.text, token: _token.text);
      if (!mounted) return;
      setState(() {
        _status = 'تم حفظ الإعدادات بأمان على الجهاز / Settings saved securely on this device';
        _connected = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = error.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _busy = true;
      _status = 'جارٍ فحص الخادم / Checking Worker...';
    });
    try {
      await _api.testConnection();
      if (!mounted) return;
      setState(() {
        _connected = true;
        _status = 'الخادم متاح / Worker is reachable';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _status = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _message.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _messages.add(_ChatLine(role: 'user', content: text));
      _message.clear();
      _busy = true;
      _status = null;
    });
    try {
      final history = _messages
          .take(20)
          .map((line) => {'role': line.role, 'content': line.content})
          .toList();
      final answer = await _api.sendMessages(history);
      if (!mounted) return;
      setState(() => _messages.add(_ChatLine(role: 'assistant', content: answer)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مساعد QX / QX Assistant')),
      backgroundColor: const Color(0xFF0B0D13),
      body: _loadingSettings
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: const Color(0xFF151923),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFF203B35),
                              child: Icon(Icons.auto_awesome, color: Color(0xFF55C99A)),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text('ChatGPT · أول موصل في QX',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            ),
                            Icon(
                              _connected ? Icons.check_circle : Icons.link_rounded,
                              color: _connected ? const Color(0xFF55C99A) : const Color(0xFF9DA2B4),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'أدخل رابط خادم QX ورمز الربط. مفتاح OpenAI يبقى داخل Cloudflare ولا يُحفظ في الهاتف.',
                          style: TextStyle(height: 1.55, color: Color(0xFFB8BDCC)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Enter the QX Worker URL and connector token. The OpenAI key stays on Cloudflare and is never stored in the app.',
                          style: TextStyle(height: 1.45, color: Color(0xFF858B9D), fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _endpoint,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'رابط الخادم / Worker URL',
                            hintText: 'https://qx-assistant-worker....workers.dev',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _token,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'رمز الربط / Connector token',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _busy ? null : _saveSettings,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('حفظ / Save'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _testConnection,
                              icon: const Icon(Icons.wifi_tethering_rounded),
                              label: const Text('اختبار الخادم / Test server'),
                            ),
                          ],
                        ),
                        if (_status != null) ...[
                          const SizedBox(height: 10),
                          Text(_status!, style: const TextStyle(color: Color(0xFFB8BDCC))),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('محادثة QX / QX Chat',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 8),
                if (_messages.isEmpty)
                  const Card(
                    color: Color(0xFF151923),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'بعد إعداد الخادم، اكتب رسالتك هنا لبدء المحادثة. / Configure the Worker, then send a message to start chatting.',
                        style: TextStyle(color: Color(0xFFB8BDCC), height: 1.5),
                      ),
                    ),
                  ),
                for (final line in _messages)
                  Align(
                    alignment: line.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: line.role == 'user' ? const Color(0xFF282344) : const Color(0xFF151923),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(line.content, style: const TextStyle(height: 1.5)),
                    ),
                  ),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                TextField(
                  controller: _message,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك / Write a message',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: _busy ? null : _sendMessage,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'الاتصال الفعلي يحتاج نشر Worker وإضافة أسراره في Cloudflare. لا توجد صلاحية لتنفيذ أو تعديل ملفات المشروع عبر المحادثة حتى نضيف أدوات تنفيذ منفصلة ومصرّحاً بها.',
                  style: TextStyle(color: Color(0xFF858B9D), fontSize: 12, height: 1.5),
                ),
              ],
            ),
    );
  }
}

class _ChatLine {
  const _ChatLine({required this.role, required this.content});
  final String role;
  final String content;
}
