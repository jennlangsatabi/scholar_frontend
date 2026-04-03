import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class BackendApi {
  static const Duration _requestTimeout = Duration(seconds: 20);

  static Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await http
        .get(ApiConfig.uri(path, query))
        .timeout(_requestTimeout);
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> postForm(
    String path, {
    Map<String, String>? body,
  }) async {
    final response = await http
        .post(ApiConfig.uri(path), body: body)
        .timeout(_requestTimeout);
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http
        .post(
          ApiConfig.uri(path),
          headers: const {'Content-Type': 'application/json'},
          body: json.encode(body ?? const <String, dynamic>{}),
        )
        .timeout(_requestTimeout);
    return _decodeMap(response);
  }

  static Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await http
        .get(ApiConfig.uri(path, query))
        .timeout(_requestTimeout);
    return _decodeList(response);
  }

  static Future<List<Map<String, dynamic>>> unwrapList(
    Future<Map<String, dynamic>> request, {
    String key = 'data',
  }) async {
    final payload = await request;
    final raw = payload[key];
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = _decodeAny(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw FormatException(
      'Expected JSON object from ${response.request?.url}',
    );
  }

  static List<Map<String, dynamic>> _decodeList(http.Response response) {
    final decoded = _decodeAny(response);
    final rawList = decoded is List
        ? decoded
        : decoded is Map<String, dynamic> && decoded['data'] is List
            ? decoded['data'] as List
            : decoded is Map && decoded['data'] is List
                ? decoded['data'] as List
                : null;
    if (rawList == null) {
      throw FormatException(
        'Expected JSON list from ${response.request?.url}',
      );
    }
    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static dynamic _decodeAny(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) {
      throw const FormatException('Server returned an empty response.');
    }
    if (body.startsWith('<')) {
      throw const FormatException('Server returned HTML instead of JSON.');
    }

    final decoded = json.decode(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (decoded is Map &&
          (decoded.containsKey('status') || decoded.containsKey('message'))) {
        return decoded;
      }
      throw Exception('HTTP ${response.statusCode}: $body');
    }

    return decoded;
  }
}
