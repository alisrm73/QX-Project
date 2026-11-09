import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

abstract interface class AssistantSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureAssistantSecretStore implements AssistantSecretStore {
  SecureAssistantSecretStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class AssistantApiClient {
  AssistantApiClient({AssistantSecretStore? secretStore, http.Client? httpClient})
      : _secretStore = secretStore ?? SecureAssistantSecretStore(),
        _httpClient = httpClient ?? http.Client();

  static const _endpointKey = 'qx_assistant_endpoint';
  static const _tokenKey = 'qx_assistant_connector_token';

  final AssistantSecretStore _secretStore;
  final http.Client _httpClient;

  Future<void> saveConnection({required String endpoint, required String token}) async {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const FormatException('استخدم رابط HTTPS صالحاً للخادم / Enter a valid HTTPS Worker URL');
    }
    if (token.trim().length < 24) {
      throw const FormatException('رمز الربط قصير جداً / Connector token is too short');
    }
    final cleanEndpoint = uri.replace(path: '', query: null, fragment: null).toString().replaceFirst(RegExp(r'/$'), '');
    await _secretStore.write(_endpointKey, cleanEndpoint);
    await _secretStore.write(_tokenKey, token.trim());
  }

  Future<String?> loadEndpoint() => _secretStore.read(_endpointKey);
  Future<String?> loadToken() => _secretStore.read(_tokenKey);

  Future<void> testConnection() async {
    final endpoint = await loadEndpoint();
    if (endpoint == null || endpoint.isEmpty) {
      throw StateError('احفظ رابط الخادم أولاً / Save the Worker URL first');
    }
    final response = await _httpClient.get(_route(endpoint, '/health')).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('تعذّر الوصول إلى الخادم / Worker health check failed (${response.statusCode})');
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map || payload['ok'] != true) {
      throw StateError('استجابة الخادم غير صالحة / Invalid Worker response');
    }
  }

  Future<String> sendMessages(List<Map<String, String>> messages) async {
    final endpoint = await loadEndpoint();
    final token = await loadToken();
    if (endpoint == null || endpoint.isEmpty || token == null || token.isEmpty) {
      throw StateError('أكمل إعدادات الاتصال أولاً / Complete connection settings first');
    }
    final response = await _httpClient.post(
      _route(endpoint, '/v1/chat'),
      headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
      body: jsonEncode({'messages': messages}),
    ).timeout(const Duration(seconds: 90));
    final payload = jsonDecode(response.body);
    if (response.statusCode != 200 || payload is! Map || payload['ok'] != true) {
      final message = payload is Map && payload['error'] is String
          ? payload['error'] as String
          : 'فشل طلب المساعد / Assistant request failed';
      throw StateError(message);
    }
    final answer = payload['answer'];
    if (answer is! String || answer.isEmpty) {
      throw StateError('لم يصل رد صالح / No valid assistant response');
    }
    return answer;
  }

  Uri _route(String endpoint, String path) {
    final base = Uri.parse(endpoint);
    return base.replace(path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$path', query: null, fragment: null);
  }
}
