import 'package:flutter/material.dart';

import '../services/assistant_connector.dart';

class AssistantConnectorPage extends StatelessWidget {
  const AssistantConnectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    const connector = ChatGptConnectorPreparation();
    return Scaffold(
      appBar: AppBar(title: const Text('مساعد QX / QX Assistant')),
      backgroundColor: const Color(0xFF0B0D13),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            color: const Color(0xFF151923),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(0xFF203B35),
                        child: Icon(Icons.auto_awesome, color: Color(0xFF55C99A)),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('ChatGPT', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                      ),
                      Chip(
                        avatar: Icon(Icons.hourglass_top_rounded, size: 16),
                        label: Text('جاهز للربط'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تم تجهيز نقطة الربط الأولى داخل QX. الاتصال الفعلي غير مفعّل حالياً، لذلك لا يتم إرسال بيانات أو إجراء اتصالات بالإنترنت.',
                    style: TextStyle(height: 1.6, color: Color(0xFFB8BDCC)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ChatGPT connector slot is prepared. Live connection is not enabled, and this screen sends no data.',
                    style: TextStyle(height: 1.5, color: Color(0xFF858B9D), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('المهام التي سيُتاح للمساعد تنفيذها / Assistant capabilities',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final capability in connector.capabilities)
            Card(
              color: const Color(0xFF151923),
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Color(0xFF55C99A)),
                title: Text(capability.nameAr),
                subtitle: Text(capability.nameEn + '\n' + capability.descriptionAr),
                isThreeLine: true,
              ),
            ),
          const SizedBox(height: 12),
          const Card(
            color: Color(0xFF151923),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'المرحلة الحالية محلية وبسيطة: لا مفاتيح سرية، لا تسجيل دخول، ولا خادم. عند تفعيل الاتصال لاحقاً سنضيف قناة آمنة دون وضع الأسرار داخل التطبيق.',
                style: TextStyle(height: 1.6, color: Color(0xFFB8BDCC)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
