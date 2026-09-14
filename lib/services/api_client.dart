import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'token_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.retryAfter});
  final String message;
  final int? statusCode;
  final int? retryAfter;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required this.tokens,
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 20),
  }) : _http = client ?? http.Client(),
       baseUrl = (baseUrl ?? const String.fromEnvironment(
         'API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/api',
       )).replaceFirst(RegExp(r'/+$'), '');

  final TokenStore tokens;
  final http.Client _http;
  final String baseUrl;
  final Duration timeout;
  VoidCallback? onUnauthorized;

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body,
      {bool authenticated = true}) =>
      _request('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> _request(String method, String path, {
    Map<String, dynamic>? body, bool authenticated = true,
  }) async {
    final uri = Uri.tryParse('$baseUrl/$path');
    if (uri == null || !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme)) {
      throw const ApiException('Alamat server tidak valid.');
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw const ApiException('Versi rilis membutuhkan koneksi HTTPS.');
    }

    final token = authenticated ? await tokens.read() : null;
    if (authenticated && (token == null || token.isEmpty)) {
      onUnauthorized?.call();
      throw const ApiException('Silakan login kembali.', statusCode: 401);
    }

    final headers = <String, String>{
      'Accept': 'application/json', 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    http.Response response;
    try {
      response = await (method == 'GET'
          ? _http.get(uri, headers: headers)
          : _http.post(uri, headers: headers, body: jsonEncode(body)))
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'Server belum merespons. Periksa status absensi sebelum mencoba lagi.',
      );
    } on http.ClientException {
      throw const ApiException('Tidak dapat terhubung. Periksa koneksi internet.');
    }

    // An expired old request must not erase a token issued by a newer login.
    if (response.statusCode == 401 && authenticated &&
        await tokens.read() == token) {
      await tokens.delete();
      onUnauthorized?.call();
    }

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      data = decoded;
    } on FormatException {
      throw ApiException(
        response.statusCode == 401 ? 'Sesi berakhir. Silakan login kembali.'
            : 'Respons server tidak valid. Coba beberapa saat lagi.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = data['message']?.toString() ?? 'Permintaan tidak berhasil.';
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) message = first.first.toString();
      }
      final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
      if (response.statusCode == 429 && retryAfter != null) {
        message = 'Terlalu banyak percobaan. Coba lagi dalam $retryAfter detik.';
      }
      throw ApiException(message, statusCode: response.statusCode, retryAfter: retryAfter);
    }
    return data;
  }

  void close() => _http.close();
}
