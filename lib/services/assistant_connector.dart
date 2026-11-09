enum AssistantConnectionStatus { prepared, connected, unavailable }

class AssistantCapability {
  const AssistantCapability({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
}

/// Local contract for assistant integrations.
/// This first-stage adapter performs no network requests and stores no credentials.
abstract interface class AssistantConnector {
  String get id;
  String get displayName;
  AssistantConnectionStatus get status;
  List<AssistantCapability> get capabilities;
}

class ChatGptConnectorPreparation implements AssistantConnector {
  const ChatGptConnectorPreparation();

  @override
  String get id => 'chatgpt';

  @override
  String get displayName => 'ChatGPT';

  @override
  AssistantConnectionStatus get status => AssistantConnectionStatus.prepared;

  @override
  List<AssistantCapability> get capabilities => const [
        AssistantCapability(
          id: 'project-planning',
          nameAr: 'تخطيط المشاريع',
          nameEn: 'Project planning',
          descriptionAr: 'تحويل الفكرة إلى خطة ومراحل عمل.',
          descriptionEn: 'Turn an idea into a plan and work stages.',
        ),
        AssistantCapability(
          id: 'project-building',
          nameAr: 'بناء المشاريع',
          nameEn: 'Project building',
          descriptionAr: 'تجهيز مهام البناء ومتابعة الملفات والنتائج.',
          descriptionEn: 'Prepare build tasks and track files and results.',
        ),
        AssistantCapability(
          id: 'review-testing',
          nameAr: 'المراجعة والاختبار',
          nameEn: 'Review and testing',
          descriptionAr: 'تنظيم الفحوصات وعرض ما تم التحقق منه.',
          descriptionEn: 'Organize checks and report verified outcomes.',
        ),
      ];
}
