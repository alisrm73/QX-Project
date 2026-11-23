import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/services/telegram_notification_service.dart';
import 'package:qx_studio/services/telegram_settings_store.dart';

void main() {
  late _MemorySecureStorage storage;
  late TelegramSettingsStore settingsStore;

  setUp(() {
    storage = _MemorySecureStorage();
    settingsStore = TelegramSettingsStore(storage: storage);
  });

  test('does not send when Telegram settings are missing', () async {
    var called = false;
    final service = TelegramNotificationService(
      settingsStore: settingsStore,
      requestSender: (_, {required headers, required body, required registerCancellation}) async {
        called = true;
        return const TelegramHttpResponse(statusCode: 200, body: '{"ok":true}');
      },
    );

    final result = await service.sendMessage('Build complete');

    expect(result.status, TelegramNotificationStatus.notConfigured);
    expect(called, isFalse);
  });

  test('rejects an empty message without making a request', () async {
    await _saveSettings(settingsStore);
    var called = false;
    final service = TelegramNotificationService(
      settingsStore: settingsStore,
      requestSender: (_, {required headers, required body, required registerCancellation}) async {
        called = true;
        return const TelegramHttpResponse(statusCode: 200, body: '{"ok":true}');
      },
    );

    final result = await service.sendMessage('   ');

    expect(result.status, TelegramNotificationStatus.invalidMessage);
    expect(called, isFalse);
  });

  test('sends one JSON message to the fixed Telegram API host', () async {
    await _saveSettings(settingsStore);
    Uri? requestedUri;
    Map<String, String>? requestedHeaders;
    Map<String, dynamic>? requestedBody;
    var calls = 0;

    final service = TelegramNotificationService(
      settingsStore: settingsStore,
      requestSender: (uri, {required headers, required body, required registerCancellation}) async {
        calls++;
        requestedUri = uri;
        requestedHeaders = headers;
        requestedBody = jsonDecode(body) as Map<String, dynamic>;
        return const TelegramHttpResponse(statusCode: 200, body: '{"ok":true}');
      },
    );

    final result = await service.sendMessage('  Build complete  ');

    expect(result.status, TelegramNotificationStatus.sent);
    expect(result.isSent, isTrue);
    expect(calls, 1);
    expect(requestedUri!.scheme, 'https');
    expect(requestedUri!.host, 'api.telegram.org');
    expect(requestedUri!.path, '/botTEST_TOKEN/sendMessage');
    expect(requestedHeaders!['content-type'], contains('application/json'));
    expect(requestedBody, <String, dynamic>{
      'chat_id': '123456789',
      'text': 'Build complete',
    });
  });

  test('returns rejected for a non-success HTTP status', () async {
    await _saveSettings(settingsStore);
    final service = TelegramNotificationService(
      settingsStore: settingsStore,
      requestSender: (_, {required headers, required body, required registerCancellation}) async =>
          const TelegramHttpResponse(statusCode: 401, body: '{"ok":false}'),
    );

    final result = await service.sendMessage('Build failed');

    expect(result.status, TelegramNotificationStatus.rejected);
  });

  test('returns rejected when Telegram reports ok false', () async {
    await _saveSettings(settingsStore);
    final service = TelegramNotificationService(
      settingsStore: settingsStore,
      requestSender: (_, {required headers, required body, required registerCancellation}) async =>
          const TelegramHttpResponse(
        statusCode: 200,
        body: '{"ok":false,"description":"Unauthorized"}',
      ),
    );

    final result = await service.sendMessage('Build failed');

    expect(result.status, TelegramNotificationStatus.rejected);
  });

  test('returns invalidResponse for malformed Telegram JSON', () async {
    await _saveSettings(settingsStore);
    final service = TelegramNotificationService(
      settingsStore: settingsStore,
      requestSender: (_, {required headers, required body, required registerCancellation}) async =>
          const TelegramHttpResponse(statusCode: 200, body: '<html>bad</html>'),
    );

    final result = await service.sendMessage('Build complete');

    expect(result.status, TelegramNotificationStatus.invalidResponse);
  });

  test('cancels the transport when the request exceeds its deadline', () async {
    await _saveSettings(settingsStore);
    final neverCompletes = Completer<TelegramHttpResponse>();
    var transportCancelled = false;
    final service = TelegramNotificationService(
      settingsStore: settingsStore,
      timeout: const Duration(milliseconds: 1),
      requestSender: (
        _,
        {
          required headers,
          required body,
          required registerCancellation,
        }
      ) {
        registerCancellation(() => transportCancelled = true);
        return neverCompletes.future;
      },
    );

    final result = await service.sendMessage('Build complete');

    expect(result.status, TelegramNotificationStatus.timedOut);
    expect(transportCancelled, isTrue);
  });

  test('returns a sanitized networkError when transport throws', () async {
    await _saveSettings(settingsStore);
    final service = TelegramNotificationService(
      settingsStore: settingsStore,
      requestSender: (_, {required headers, required body, required registerCancellation}) {
        throw StateError('request failed for https://api.telegram.org/botTEST_TOKEN/sendMessage');
      },
    );

    final result = await service.sendMessage('Build failed');

    expect(result.status, TelegramNotificationStatus.networkError);
    expect(result.toString(), isNot(contains('TEST_TOKEN')));
  });
}

Future<void> _saveSettings(TelegramSettingsStore store) => store.save(
      botToken: 'TEST_TOKEN',
      chatId: '123456789',
    );

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
