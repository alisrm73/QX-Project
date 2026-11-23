import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/services/telegram_notification_manager.dart';
import 'package:qx_studio/services/telegram_notification_service.dart';
import 'package:qx_studio/services/telegram_settings_store.dart';

void main() {
  late _MemorySecureStorage storage;
  late TelegramSettingsStore settingsStore;

  setUp(() async {
    storage = _MemorySecureStorage();
    settingsStore = TelegramSettingsStore(storage: storage);
    await settingsStore.save(
      botToken: 'TEST_TOKEN',
      chatId: '123456789',
    );
  });

  TelegramNotificationManager createManager(
    TelegramRequestSender sender,
  ) {
    return TelegramNotificationManager(
      settingsStore: settingsStore,
      notificationService: TelegramNotificationService(
        settingsStore: settingsStore,
        requestSender: sender,
      ),
    );
  }

  test('prevents duplicate event delivery across manager instances', () async {
    var calls = 0;
    Future<TelegramHttpResponse> sender(
      Uri uri, {
      required Map<String, String> headers,
      required String body,
      required void Function(void Function()) registerCancellation,
    }) async {
      registerCancellation(() {});
      calls++;
      return const TelegramHttpResponse(
        statusCode: 200,
        body: '{"ok":true}',
      );
    }

    final firstManager = createManager(sender);
    final secondManager = createManager(sender);

    final first = await firstManager.notifyAnalysisCompleted(
      eventId: 'manager-test-cross-instance-duplicate',
    );
    final second = await secondManager.notifyAnalysisCompleted(
      eventId: 'manager-test-cross-instance-duplicate',
    );

    expect(first.status, TelegramNotificationStatus.sent);
    expect(second.status, TelegramNotificationStatus.rejected);
    expect(calls, 1);
  });

  test('shares an in-flight event across manager instances', () async {
    final completer = Completer<TelegramHttpResponse>();
    var calls = 0;

    Future<TelegramHttpResponse> sender(
      Uri uri, {
      required Map<String, String> headers,
      required String body,
      required void Function(void Function()) registerCancellation,
    }) {
      registerCancellation(() {});
      calls++;
      return completer.future;
    }

    final firstManager = createManager(sender);
    final secondManager = createManager(sender);

    final firstFuture = firstManager.notifyToolExecuted(
      eventId: 'manager-test-concurrent-event',
    );
    final secondFuture = secondManager.notifyToolExecuted(
      eventId: 'manager-test-concurrent-event',
    );

    completer.complete(const TelegramHttpResponse(
      statusCode: 200,
      body: '{"ok":true}',
    ));

    final results = await Future.wait([firstFuture, secondFuture]);

    expect(calls, 1);
    expect(results[0].status, TelegramNotificationStatus.sent);
    expect(results[1].status, TelegramNotificationStatus.sent);
  });

  test('allows retry after an unsuccessful delivery', () async {
    var calls = 0;

    Future<TelegramHttpResponse> sender(
      Uri uri, {
      required Map<String, String> headers,
      required String body,
      required void Function(void Function()) registerCancellation,
    }) async {
      registerCancellation(() {});
      calls++;
      if (calls == 1) {
        return const TelegramHttpResponse(
          statusCode: 503,
          body: '{"ok":false}',
        );
      }
      return const TelegramHttpResponse(
        statusCode: 200,
        body: '{"ok":true}',
      );
    }

    final manager = createManager(sender);

    final first = await manager.notifyProjectCreated(
      eventId: 'manager-test-retry-event',
    );
    final second = await manager.notifyProjectCreated(
      eventId: 'manager-test-retry-event',
    );

    expect(first.status, TelegramNotificationStatus.rejected);
    expect(second.status, TelegramNotificationStatus.sent);
    expect(calls, 2);
  });

  test('rejects an empty event id without sending', () async {
    var calls = 0;

    Future<TelegramHttpResponse> sender(
      Uri uri, {
      required Map<String, String> headers,
      required String body,
      required void Function(void Function()) registerCancellation,
    }) async {
      registerCancellation(() {});
      calls++;
      return const TelegramHttpResponse(
        statusCode: 200,
        body: '{"ok":true}',
      );
    }

    final manager = createManager(sender);
    final result = await manager.notifyProjectCreated(eventId: '   ');

    expect(result.status, TelegramNotificationStatus.invalidMessage);
    expect(calls, 0);
  });
}

class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}
