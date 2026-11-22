import 'telegram_notification_service.dart';
import 'telegram_settings_store.dart';

/// Runtime-only coordinator for optional Telegram notifications.
class TelegramNotificationManager {
  TelegramNotificationManager({
    required TelegramSettingsStore settingsStore,
    required TelegramNotificationService notificationService,
  })  : _settingsStore = settingsStore,
        _notificationService = notificationService;

  final TelegramSettingsStore _settingsStore;
  final TelegramNotificationService _notificationService;

  final Set<String> _deliveredEventIds = <String>{};
  final Map<String, Future<TelegramNotificationResult>> _inFlight =
      <String, Future<TelegramNotificationResult>>{};

  Future<TelegramNotificationResult> notifyProjectCreated({
    required String eventId,
  }) =>
      _notify(eventId, 'تم إنشاء مشروع جديد في QX Studio.');

  Future<TelegramNotificationResult> notifyAnalysisCompleted({
    required String eventId,
  }) =>
      _notify(eventId, 'اكتمل تحليل المشروع في QX Studio.');

  Future<TelegramNotificationResult> notifyToolExecuted({
    required String eventId,
  }) =>
      _notify(eventId, 'تم تنفيذ أداة في QX Studio.');

  Future<TelegramNotificationResult> _notify(
    String eventId,
    String message,
  ) async {
    final id = eventId.trim();

    if (id.isEmpty || id.length > 200) {
      return const TelegramNotificationResult(
        TelegramNotificationStatus.invalidMessage,
      );
    }

    if (_deliveredEventIds.contains(id)) {
      return const TelegramNotificationResult(
        TelegramNotificationStatus.rejected,
      );
    }

    final existing = _inFlight[id];
    if (existing != null) return existing;

    final operation = _send(message);
    _inFlight[id] = operation;

    try {
      final result = await operation;
      if (result.status == TelegramNotificationStatus.sent) {
        _deliveredEventIds.add(id);
      }
      return result;
    } finally {
      _inFlight.remove(id);
    }
  }

  Future<TelegramNotificationResult> _send(String message) async {
    try {
      final settings = await _settingsStore.read();
      if (settings == null || !settings.isConfigured) {
        return const TelegramNotificationResult(
          TelegramNotificationStatus.notConfigured,
        );
      }
      return await _notificationService.sendMessage(message);
    } catch (_) {
      return const TelegramNotificationResult(
        TelegramNotificationStatus.networkError,
      );
    }
  }
}
