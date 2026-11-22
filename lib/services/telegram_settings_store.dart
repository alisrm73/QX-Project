import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Telegram credentials stored as one encrypted value to avoid partial updates.
class TelegramSettings {
  const TelegramSettings({
    required this.botToken,
    required this.chatId,
  });

  final String botToken;
  final String chatId;

  bool get isConfigured => botToken.isNotEmpty && chatId.isNotEmpty;
}

/// Stores personal Telegram bot settings in the platform secure storage.
///
/// The token is never written to project files, logs, or ordinary preferences.
class TelegramSettingsStore {
  TelegramSettingsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _settingsKey = 'qx_studio.telegram.settings.v1';

  final FlutterSecureStorage _storage;

  Future<void> save({
    required String botToken,
    required String chatId,
  }) async {
    final normalizedToken = botToken.trim();
    final normalizedChatId = chatId.trim();

    if (normalizedToken.isEmpty) {
      throw ArgumentError.value(botToken, 'botToken', 'Must not be empty.');
    }
    if (normalizedChatId.isEmpty) {
      throw ArgumentError.value(chatId, 'chatId', 'Must not be empty.');
    }

    final value = jsonEncode(<String, String>{
      'botToken': normalizedToken,
      'chatId': normalizedChatId,
    });

    await _storage.write(key: _settingsKey, value: value);
  }

  Future<TelegramSettings?> read() async {
    final value = await _storage.read(key: _settingsKey);
    if (value == null || value.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Stored Telegram settings are invalid.');
    }

    final botToken = decoded['botToken'];
    final chatId = decoded['chatId'];
    if (botToken is! String ||
        chatId is! String ||
        botToken.trim().isEmpty ||
        chatId.trim().isEmpty) {
      throw const FormatException('Stored Telegram settings are incomplete.');
    }

    return TelegramSettings(
      botToken: botToken,
      chatId: chatId,
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _settingsKey);
  }
}
