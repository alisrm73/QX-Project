import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/services/telegram_settings_store.dart';

void main() {
  late _MemorySecureStorage storage;
  late TelegramSettingsStore store;

  setUp(() {
    storage = _MemorySecureStorage();
    store = TelegramSettingsStore(storage: storage);
  });

  test('returns null when Telegram settings have not been saved', () async {
    expect(await store.read(), isNull);
  });

  test('saves trimmed credentials together and reads them back', () async {
    await store.save(
      botToken: '  test-bot-token  ',
      chatId: '  123456789  ',
    );

    final settings = await store.read();

    expect(settings, isNotNull);
    expect(settings!.botToken, 'test-bot-token');
    expect(settings.chatId, '123456789');
    expect(storage.values, hasLength(1));
  });

  test('rejects an empty bot token without writing settings', () async {
    await expectLater(
      store.save(botToken: '  ', chatId: '123456789'),
      throwsArgumentError,
    );

    expect(storage.values, isEmpty);
  });

  test('rejects an empty chat id without writing settings', () async {
    await expectLater(
      store.save(botToken: 'test-bot-token', chatId: '  '),
      throwsArgumentError,
    );

    expect(storage.values, isEmpty);
  });

  test('returns null after settings are cleared', () async {
    await store.save(botToken: 'test-bot-token', chatId: '123456789');

    await store.clear();

    expect(await store.read(), isNull);
    expect(storage.values, isEmpty);
  });

  test('rejects malformed stored JSON', () async {
    storage.values['qx_studio.telegram.settings.v1'] = '{invalid';

    await expectLater(store.read(), throwsFormatException);
  });

  test('rejects stored settings with missing or invalid fields', () async {
    storage.values['qx_studio.telegram.settings.v1'] =
        '{"botToken":"test-bot-token","chatId":""}';

    await expectLater(store.read(), throwsFormatException);
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
