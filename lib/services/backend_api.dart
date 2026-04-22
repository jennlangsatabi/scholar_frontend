import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class BackendApi {
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const Duration _warmupTimeout = Duration(seconds: 12);
  static const int _defaultRetries = 2;

  static final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};
  static final Map<String, Future<dynamic>> _inFlight = <String, Future<dynamic>>{};
  static Future<void>? _warmupFuture;

  static void invalidateCache({String? pathContains}) {
    if (pathContains == null || pathContains.trim().isEmpty) {
      _cache.clear();
      return;
    }

    final needle = pathContains.trim().toLowerCase();
    final keysToRemove = _cache.keys
        .where((key) => key.toLowerCase().contains(needle))
        .toList(growable: false);
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  static Future<void> warmUp() {
    // Render free instances often cold-start. Warm the backend while the user is
    // on the login/role screen so the first real action feels snappy.
    return _warmupFuture ??= () async {
      try {
        final uri = ApiConfig.uri('health.php');
        await http.get(uri).timeout(_warmupTimeout);
      } catch (_) {
        // Ignore warmup failures; real requests will surface errors.
      }
    }();
  }

  static Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? timeout,
    Duration? cacheTtl,
    int retries = _defaultRetries,
  }) async {
    final uri = ApiConfig.uri(path, query);
    final key = _cacheKey('GET', uri, body: headers);
    return await _requestDecoded<Map<String, dynamic>>(
      key,
      cacheTtl: cacheTtl,
      request: () => http
          .get(uri, headers: headers)
          .timeout(timeout ?? _requestTimeout),
      decode: _decodeMap,
      retries: retries,
    );
  }

  static Future<Map<String, dynamic>> postForm(
    String path, {
    Map<String, String>? body,
    Map<String, String>? headers,
    Duration? timeout,
    int retries = _defaultRetries,
  }) async {
    final uri = ApiConfig.uri(path);
    final key = _cacheKey(
      'POST',
      uri,
      body: {
        'body': body,
        'headers': headers,
      },
    );
    return await _requestDecoded<Map<String, dynamic>>(
      key,
      request: () => http
          .post(uri, body: body, headers: headers)
          .timeout(timeout ?? _requestTimeout),
      decode: _decodeMap,
      retries: retries,
    );
  }

  static Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
    int retries = _defaultRetries,
  }) async {
    final uri = ApiConfig.uri(path);
    final encodedBody = json.encode(body ?? const <String, dynamic>{});
    final mergedHeaders = <String, String>{
      'Content-Type': 'application/json',
      ...?headers,
    };
    final key = _cacheKey(
      'POSTJSON',
      uri,
      body: {
        'body': encodedBody,
        'headers': mergedHeaders,
      },
    );
    return await _requestDecoded<Map<String, dynamic>>(
      key,
      request: () => http
          .post(
            uri,
            headers: mergedHeaders,
            body: encodedBody,
          )
          .timeout(timeout ?? _requestTimeout),
      decode: _decodeMap,
      retries: retries,
    );
  }

  static Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? timeout,
    Duration? cacheTtl,
    int retries = _defaultRetries,
  }) async {
    final uri = ApiConfig.uri(path, query);
    final key = _cacheKey('GETLIST', uri, body: headers);
    return await _requestDecoded<List<Map<String, dynamic>>>(
      key,
      cacheTtl: cacheTtl,
      request: () => http
          .get(uri, headers: headers)
          .timeout(timeout ?? _requestTimeout),
      decode: _decodeList,
      retries: retries,
    );
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

  static String extractFirstString(
    Map<String, dynamic> payload,
    List<String> keys, {
    int maxDepth = 4,
  }) {
    final normalizedKeys = keys
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toList(growable: false);
    if (normalizedKeys.isEmpty) {
      return '';
    }

    final seen = <Map<dynamic, dynamic>>{};
    final queue = <({Map<dynamic, dynamic> map, int depth})>[
      (map: payload, depth: 0),
    ];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final map = current.map;
      final depth = current.depth;
      if (!seen.add(map)) continue;

      for (final key in normalizedKeys) {
        final value = map[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty &&
            text.toLowerCase() != 'null' &&
            text.toLowerCase() != 'undefined') {
          return text;
        }
      }

      if (depth >= maxDepth) continue;

      for (final value in map.values) {
        if (value is Map) {
          queue.add((map: value, depth: depth + 1));
        } else if (value is List) {
          for (final entry in value) {
            if (entry is Map) {
              queue.add((map: entry, depth: depth + 1));
            }
          }
        }
      }
    }

    return '';
  }

  static String _cacheKey(String method, Uri uri, {Object? body}) {
    if (body == null) return '$method ${uri.toString()}';
    return '$method ${uri.toString()} ${json.encode(body)}';
  }

  static Future<T> _requestDecoded<T>(
    String key, {
    required Future<http.Response> Function() request,
    required T Function(http.Response response) decode,
    Duration? cacheTtl,
    int retries = _defaultRetries,
  }) async {
    _purgeExpiredCache();

    final ttl = cacheTtl;
    if (ttl != null && ttl > Duration.zero) {
      final cached = _cache[key];
      if (cached != null && !cached.isExpired) {
        return cached.value as T;
      }
    }

    final inflight = _inFlight[key];
    if (inflight != null) {
      final result = await inflight;
      return result as T;
    }

    final future = () async {
      final decoded = await _sendWithRetryDecoded(
        request,
        decode,
        retries: retries,
      );
      if (ttl != null && ttl > Duration.zero) {
        _cache[key] = _CacheEntry(
          value: decoded,
          expiresAt: DateTime.now().add(ttl),
        );
      }
      return decoded;
    }();

    _inFlight[key] = future;
    try {
      final result = await future;
      return result;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<T> _sendWithRetryDecoded<T>(
    Future<http.Response> Function() request,
    T Function(http.Response response) decode, {
    required int retries,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        final response = await request();

        if (_shouldRetryStatus(response.statusCode) && attempt < retries) {
          final delay = _retryDelay(attempt);
          attempt++;
          await Future.delayed(delay);
          continue;
        }

        try {
          return decode(response);
        } on FormatException catch (e) {
          if (_isRetryableDecodeFailure(e) && attempt < retries) {
            final delay = _retryDelay(attempt);
            attempt++;
            await Future.delayed(delay);
            continue;
          }
          rethrow;
        }
      } on TimeoutException {
        if (attempt >= retries) rethrow;
      } on http.ClientException {
        if (attempt >= retries) rethrow;
      }

      final delay = _retryDelay(attempt);
      attempt++;
      await Future.delayed(delay);
    }
  }

  static bool _isRetryableDecodeFailure(FormatException error) {
    // During cold starts / transient gateway errors, Render (or upstream proxies)
    // often returns HTML bodies for 502/503. We treat these as retryable.
    final message = error.message.toLowerCase();
    return message.contains('html instead of json') ||
        message.contains('empty response');
  }

  static bool _shouldRetryStatus(int statusCode) {
    return statusCode == 408 ||
        statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  static Duration _retryDelay(int attempt) {
    // 300ms, 900ms, 1800ms...
    final ms = 300 * (attempt == 0 ? 1 : (attempt * attempt + 2));
    return Duration(milliseconds: ms.clamp(300, 2000));
  }

  static void _purgeExpiredCache() {
    if (_cache.isEmpty) return;
    final now = DateTime.now();
    final expired = <String>[];
    _cache.forEach((key, value) {
      if (value.expiresAt.isBefore(now)) {
        expired.add(key);
      }
    });
    for (final key in expired) {
      _cache.remove(key);
    }
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

class _CacheEntry {
  final Object? value;
  final DateTime expiresAt;

  const _CacheEntry({
    required this.value,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
