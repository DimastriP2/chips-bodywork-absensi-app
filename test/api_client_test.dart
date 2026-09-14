import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_flutter_app/services/api_client.dart';

import 'helpers.dart';

void main() {
  test('authenticated requests carry a bearer token and preserve JSON payloads', () async {
    final api = ApiClient(
      tokens: MemoryTokenStore('secret'),
      baseUrl: 'https://example.test/api/',
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://example.test/api/checkin');
        expect(request.headers['Authorization'], 'Bearer secret');
        expect(jsonDecode(request.body)['latitude'], -6.2);
        return http.Response('{"message":"ok"}', 201);
      }),
    );
    expect((await api.post('checkin', {'latitude': -6.2}))['message'], 'ok');
    api.close();
  });

  test('login does not attach an old token', () async {
    final api = ApiClient(
      tokens: MemoryTokenStore('old'),
      client: MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('{"token":"new"}', 200);
      }),
    );
    await api.post('login', {'email': 'a@example.test', 'password': ' test '}, authenticated: false);
    api.close();
  });

  test('401 clears the current session and notifies the app', () async {
    final tokens = MemoryTokenStore('expired');
    var expired = false;
    final api = ApiClient(tokens: tokens,
      client: MockClient((_) async => http.Response('{"message":"Expired"}', 401)));
    api.onUnauthorized = () => expired = true;
    await expectLater(api.get('profile'), throwsA(isA<ApiException>()));
    expect(tokens.token, isNull);
    expect(expired, isTrue);
    api.close();
  });

  test('a late 401 from an old request cannot erase a newer login', () async {
    final tokens = MemoryTokenStore('old');
    final started = Completer<void>();
    final response = Completer<http.Response>();
    final api = ApiClient(tokens: tokens, client: MockClient((_) {
      started.complete();
      return response.future;
    }));
    final request = api.get('profile');
    final assertion = expectLater(request, throwsA(isA<ApiException>()));
    await started.future;
    await tokens.write('new');
    response.complete(http.Response('{"message":"Expired"}', 401));
    await assertion;
    expect(tokens.token, 'new');
    api.close();
  });

  test('HTML errors produce a readable message', () async {
    final api = ApiClient(tokens: MemoryTokenStore('token'),
      client: MockClient((_) async => http.Response('<html>error</html>', 502)));
    await expectLater(api.get('profile'), throwsA(isA<ApiException>()
      .having((e) => e.message, 'message', contains('Respons server tidak valid'))));
    api.close();
  });

  test('validation field errors and Retry-After are preserved', () async {
    final api = ApiClient(tokens: MemoryTokenStore('token'),
      client: MockClient((request) async => request.url.path.endsWith('checkin')
        ? http.Response('{"message":"Invalid","errors":{"latitude":["Latitude wajib diisi"]}}', 422)
        : http.Response('{"message":"Too many"}', 429, headers: {'retry-after': '45'})));
    await expectLater(api.post('checkin', {}), throwsA(isA<ApiException>()
      .having((e) => e.message, 'message', 'Latitude wajib diisi')));
    await expectLater(api.get('history'), throwsA(isA<ApiException>()
      .having((e) => e.retryAfter, 'retryAfter', 45)));
    api.close();
  });

  test('a timed out attendance write is not automatically repeated', () async {
    var count = 0;
    final response = Completer<http.Response>();
    final api = ApiClient(tokens: MemoryTokenStore('token'),
      timeout: const Duration(milliseconds: 5),
      client: MockClient((_) { count++; return response.future; }));
    await expectLater(api.post('checkin', {}), throwsA(isA<ApiException>()));
    expect(count, 1);
    response.complete(http.Response('{"message":"saved"}', 201));
    api.close();
  });
}
