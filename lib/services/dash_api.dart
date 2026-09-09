// ─── Shared dashboard API plumbing ─────────────────────────────────────────────
//
// Base class for the read-only drill-down dashboard services (Bins,
// Collections). It owns the parts every one of them needs identically:
//
//   • HTTP Basic auth pulled from SharedPreferences (the app-wide mechanism)
//   • query-param cleaning and URI building
//   • boxed request/response logging with the auth header masked
//   • status-code → user-facing message mapping
//   • tolerant list decoding (bare list, or a `results` / `data` envelope)
//
// Subclasses add one method per endpoint and nothing else.
//
// Note: the older VehicleDashboardApi predates this base and stays standalone —
// its `VehicleDashException` carries a recoverable `project_choices` payload that
// its screens catch by exact type, so folding it in here would change which
// errors those `on VehicleDashException` clauses see.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ourlandnew/config.dart';

/// Typed, user-facing API failure. [message] is safe to show in the UI.
class DashApiException implements Exception {
  final String message;
  final int? statusCode;

  DashApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Drops null/blank entries and trims the survivors, so callers can write
/// optional params inline without guarding each one.
Map<String, String> cleanParams(Map<String, String?> params) {
  final out = <String, String>{};
  params.forEach((key, value) {
    if (value == null) return;
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) out[key] = trimmed;
  });
  return out;
}

/// Builds an absolute request URI. A free function so tests can assert the exact
/// query string without instantiating a client.
///
/// The query is encoded by hand rather than through `replace(queryParameters:)`
/// because that helper emits `+` for a space. Most servers decode the two
/// identically, but the API contract specifies `%20` (e.g.
/// `bin_status=Collected%20in%2012hr`), so [Uri.encodeComponent] is used to
/// produce exactly that.
Uri buildApiUri(String baseUrl, String path, Map<String, String> params) {
  final base =
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  final suffix = path.startsWith('/') ? path.substring(1) : path;
  final uri = Uri.parse('$base/$suffix');
  if (params.isEmpty) return uri;
  final query = params.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return uri.replace(query: query);
}

abstract class DashApiClient {
  static const Duration timeout = Duration(seconds: 30);

  String get baseUrl => AppConfig.apiUrl;

  /// Prefix used in the debug log boxes, e.g. `BIN API`.
  String get logTag;

  // ── Auth (attached centrally, never per call) ────────────────────────────────

  Future<Map<String, String>> authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final password = prefs.getString('password');
    if (username == null || password == null) {
      throw DashApiException(
        'Your session has expired. Please log in again.',
        statusCode: 401,
      );
    }
    final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    return {'Content-Type': 'application/json', 'authorization': auth};
  }

  // ── Logging ─────────────────────────────────────────────────────────────────

  void logBox({required String title, required List<String> lines}) {
    const bar = '══════════════════════════════════════════════════════════';
    final buffer = StringBuffer()
      ..writeln('\n╔$bar')
      ..writeln('║ $title')
      ..writeln('╟$bar');
    for (final line in lines) {
      for (final sub in line.split('\n')) {
        buffer.writeln('║ $sub');
      }
    }
    buffer.write('╚$bar');
    // ignore: avoid_print
    print(buffer.toString());
  }

  Map<String, String> maskHeaders(Map<String, String> headers) {
    final masked = Map<String, String>.from(headers);
    if (masked.containsKey('authorization')) {
      masked['authorization'] = 'Basic ****** (masked)';
    }
    return masked;
  }

  // ── Error mapping ───────────────────────────────────────────────────────────

  Never mapError(Object e) {
    if (e is DashApiException) throw e;
    if (e is TimeoutException) {
      throw DashApiException('The request timed out. Please try again.');
    }
    if (e is FormatException) {
      throw DashApiException('Could not read the server response.');
    }
    throw DashApiException('Network error. Please check your connection.');
  }

  DashApiException fromResponse(http.Response resp) {
    final code = resp.statusCode;
    Map<String, dynamic>? body;
    try {
      if (resp.body.isNotEmpty) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      }
    } catch (_) {
      body = null;
    }

    if (code == 401) {
      return DashApiException(
        'Your session has expired. Please log in again.',
        statusCode: 401,
      );
    }
    if (code == 403) {
      return DashApiException(
        "You don't have permission to view this data.",
        statusCode: 403,
      );
    }
    if (code >= 500) {
      return DashApiException('Server error. Please try again later.',
          statusCode: code);
    }
    final detail = body?['detail']?.toString();
    return DashApiException(detail ?? 'Request failed ($code).',
        statusCode: code);
  }

  /// Tolerates a bare JSON list or a `{results: […]}` / `{data: […]}` envelope,
  /// and an empty body. Never assumes the payload is a list.
  List<dynamic> decodeList(http.Response resp) {
    if (resp.body.isEmpty) return const [];
    final data = jsonDecode(resp.body);
    if (data is List) return data;
    if (data is Map) {
      final inner = data['results'] ?? data['data'];
      if (inner is List) return inner;
    }
    return const [];
  }

  // ── Logged GET ──────────────────────────────────────────────────────────────

  Future<http.Response> loggedGet(Uri uri, Map<String, String> headers) async {
    logBox(title: '$logTag ▶ REQUEST', lines: [
      'Method        : GET',
      'API URL       : ${uri.scheme}://${uri.authority}${uri.path}',
      'Query Params  : '
          '${uri.queryParameters.isEmpty ? '(none)' : uri.queryParameters}',
      'Headers       : ${maskHeaders(headers)}',
    ]);
    final sw = Stopwatch()..start();
    try {
      final resp = await http.get(uri, headers: headers).timeout(timeout);
      sw.stop();
      final isError = resp.statusCode < 200 || resp.statusCode >= 300;
      logBox(
        title: isError
            ? '$logTag ✖ RESPONSE (${resp.statusCode})'
            : '$logTag ✔ RESPONSE (${resp.statusCode})',
        lines: [
          'API URL       : ${uri.scheme}://${uri.authority}${uri.path}',
          'Status Code   : ${resp.statusCode}',
          'Execution Time: ${sw.elapsed.inMilliseconds} ms',
          '${isError ? 'Error Response' : 'Response Body '}: '
              '${resp.body.isEmpty ? '(empty)' : resp.body}',
        ],
      );
      return resp;
    } catch (e) {
      sw.stop();
      logBox(title: '$logTag ✖ REQUEST FAILED', lines: [
        'API URL       : ${uri.scheme}://${uri.authority}${uri.path}',
        'Execution Time: ${sw.elapsed.inMilliseconds} ms',
        'Error         : $e',
      ]);
      rethrow;
    }
  }

  /// GET [path] and map each object in the response through [parse]. Non-object
  /// entries are skipped rather than throwing, so one malformed row cannot take
  /// down the screen.
  Future<List<T>> fetchList<T>(
    String path,
    Map<String, String> params,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final headers = await authHeaders();
      final uri = buildApiUri(baseUrl, path, params);
      final resp = await loggedGet(uri, headers);
      if (resp.statusCode != 200) throw fromResponse(resp);
      return decodeList(resp)
          .whereType<Map>()
          .map((e) => parse(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      mapError(e);
    }
  }
}
