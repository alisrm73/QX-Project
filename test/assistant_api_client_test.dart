import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qx_studio/services/assistant_api_client.dart';

void main() {
  late _MemorySecretStore store;

  setUp(() => store = _MemorySecretStore());

  test('rejects non-HTTPS Worker URLs', () async {
    final api = AssistantApiClient(secretStore: store, httpClient: MockClient((_) async => http.Response('{}', 200)));
    expect(
      () => api.saveConnection(endpoint: 'http://example.com', token: 'a' * 32),
      throwsFormatException,
    );
  });

  test('stores Worker URL and connector token separately', () async {
    final api = AssistantApiClient(secretStore: store, httpClient: MockClient((_) async => http.Response('{}', 200)));
    await api.saveConnection(endpoint: 'https://qx.example.workers.dev/', token: 't' * 32);
    expect(await api.loadEndpoint(), 'https://qx.example.workers.dev');
    expect(await api.loadToken(), 't' * 32);
  });

  test('checks the Worker health endpoint', () async {
    final api = AssistantApiClient(
      secretStore: store,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/health');
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );
    await api.saveConnection(endpoint: 'https://qx.example.workers.dev', token: 't' * 32);
    await expectLater(api.testConnection(), completes);
  });

  test('sends chat with bearer token and returns assistant answer', () async {
    final api = AssistantApiClient(
      secretStore: store,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/chat');
        expect(request.headers['authorization'], 'Bearer ${'t' * 32}');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['messages'], hasLength(1));
        return http.Response(jsonEncode({'ok': true, 'answer': 'Hello from QX'}), 200);
      }),
    );
    await api.saveConnection(endpoint: 'https://qx.example.workers.dev', token: 't' * 32);
    final answer = await api.sendMessages([{'role': 'user', 'content': 'Hello'}]);
    expect(answer, 'Hello from QX');
  });
}

class _MemorySecretStore implements AssistantSecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
