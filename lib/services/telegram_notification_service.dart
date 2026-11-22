import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'telegram_settings_store.dart';

/// A sanitized result of one Telegram send attempt.
enum TelegramNotificationStatus {
  sent,
  notConfigured,
  invalidMessage,
  rejected,
  invalidResponse,
  timedOut,
  networkError,
}

class TelegramNotificationResult {
  const TelegramNotificationResult(this.status);

  final TelegramNotificationStatus status;

  bool get isSent => status == TelegramNotificationStatus.sent;
}

/// Response shape returned by the injectable HTTP sender.
class TelegramHttpResponse {
  const TelegramHttpResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

/// Injectable boundary so tests never need a real bot token or network access.
///
/// A transport must register its cancellation callback as soon as it creates
/// resources that need to be closed when the request deadline expires.
typedef TelegramRequestSender = Future<TelegramHttpResponse> Function(
  Uri uri, {
  required Map<String, String> headers,
  required String body,
  required void Function(void Function()) registerCancellation,
});

/// Sends one personal notification directly to the Telegram Bot API.
///
/// The bot token is read only from [TelegramSettingsStore]. It is never
/// included in result objects or error messages. Redirects are disabled
/// because the token is part of the fixed Telegram API request path.
class TelegramNotificationService {
  TelegramNotificationService({
    required TelegramSettingsStore settingsStore,
    TelegramRequestSender? requestSender,
    this.timeout = const Duration(seconds: 10),
  }) : _settingsStore = settingsStore {
    _requestSender = requestSender ?? _sendHttpRequest;
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive.');
    }
  }

  static const int _maxResponseBytes = 64 * 1024;

  final TelegramSettingsStore _settingsStore;
  late final TelegramRequestSender _requestSender;
  final Duration timeout;

  /// Attempts to send a single plain-text message.
  ///
  /// Every failure is returned as a non-sensitive status. Callers should
  /// treat notification failure as separate from the build/test result.
  Future<TelegramNotificationResult> sendMessage(String message) async {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      return const TelegramNotificationResult(
        TelegramNotificationStatus.invalidMessage,
      );
    }

    try {
      final settings = await _settingsStore.read();
      if (settings == null || !settings.isConfigured) {
        return const TelegramNotificationResult(
          TelegramNotificationStatus.notConfigured,
        );
      }

      final uri = Uri.https(
        'api.telegram.org',
        '/bot${settings.botToken}/sendMessage',
      );
      final body = jsonEncode(<String, String>{
        'chat_id': settings.chatId,
        'text': cleanMessage,
      });

      void Function()? cancelRequest;
      void registerCancellation(void Function() cancellation) {
        cancelRequest = cancellation;
      }

      final response = await _requestSender(
        uri,
        headers: const <String, String>{
          HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
          HttpHeaders.acceptHeader: 'application/json',
        },
        body: body,
        registerCancellation: registerCancellation,
      ).timeout(
        timeout,
        onTimeout: () {
          // Future.timeout does not cancel its source future. Explicitly close
          // the transport before reporting the deadline to the caller.
          cancelRequest?.call();
          throw TimeoutException('Telegram request timed out.');
        },
      );

      if (response.statusCode != HttpStatus.ok) {
        return const TelegramNotificationResult(
          TelegramNotificationStatus.rejected,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['ok'] is! bool) {
        return const TelegramNotificationResult(
          TelegramNotificationStatus.invalidResponse,
        );
      }

      return TelegramNotificationResult(
        decoded['ok'] == true
            ? TelegramNotificationStatus.sent
            : TelegramNotificationStatus.rejected,
      );
    } on TimeoutException {
      return const TelegramNotificationResult(
        TelegramNotificationStatus.timedOut,
      );
    } on FormatException {
      return const TelegramNotificationResult(
        TelegramNotificationStatus.invalidResponse,
      );
    } catch (_) {
      // Deliberately do not expose exception text: it may contain the token URL.
      return const TelegramNotificationResult(
        TelegramNotificationStatus.networkError,
      );
    }
  }

  Future<TelegramHttpResponse> _sendHttpRequest(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    required void Function(void Function()) registerCancellation,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    // The service deadline can now abort connection, request, and response
    // body work—not only the initial response headers.
    registerCancellation(() => client.close(force: true));

    try {
      final request = await client.postUrl(uri);
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      request.write(body);

      final response = await request.close();
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > _maxResponseBytes) {
          throw const FormatException('Telegram response exceeded the limit.');
        }
        bytes.addAll(chunk);
      }

      return TelegramHttpResponse(
        statusCode: response.statusCode,
        body: utf8.decode(bytes),
      );
    } finally {
      client.close(force: true);
    }
  }
}
