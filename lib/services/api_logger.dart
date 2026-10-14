// ─── Structured API logging ────────────────────────────────────────────────────
//
// Prints one readable block per completed HTTP call: URL, method, params, body,
// status code and response — or an ERROR block when the call fails or returns a
// non-2xx status.
//
// Every request made through services/http_client.dart is logged here
// automatically; call sites do not need to call `logApiCall` themselves.
//
// Two deliberate properties:
//
//  • Credentials are never printed. The `authorization` header is masked, so a
//    log can be pasted into a ticket safely.
//  • JSON responses are pretty-printed. Beyond being readable, this matters on
//    Android: logcat truncates a single line at roughly 1 KB, so a one-line
//    dump of a long response gets cut off while an indented one survives.
//
// Compiled out of release builds — `kApiLoggingEnabled` is const, so the calls
// and their string interpolation are tree-shaken away.

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Whether the blocks below are emitted. Debug builds only: these dumps include
/// full API responses, which should not reach a production log.
const bool kApiLoggingEnabled = kDebugMode;

const String _kBar = '==================================================';

/// Pretty-prints [raw] when it is JSON, otherwise returns it unchanged. An empty
/// body reads as `(empty)`.
String _formatBody(String? raw) {
  if (raw == null) return '(none)';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '(empty)';
  try {
    final decoded = jsonDecode(trimmed);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    // Not JSON (an HTML error page, a bare string) — show it as it came.
    return trimmed;
  }
}

/// `project=MDU&vehicle_id=123`, or `(none)`.
String _formatParams(Uri uri, Map<String, String>? override) {
  final params = override ?? uri.queryParameters;
  if (params.isEmpty) return '(none)';
  return params.entries.map((e) => '${e.key}=${e.value}').join('&');
}

Map<String, String> _maskHeaders(Map<String, String> headers) {
  final masked = <String, String>{};
  headers.forEach((key, value) {
    masked[key] = key.toLowerCase() == 'authorization'
        ? 'Basic ****** (masked)'
        : value;
  });
  return masked;
}

/// Emits [lines] inside a labelled block. Each line is printed separately so a
/// long response is not lost to per-line truncation.
void _emit(String title, List<String> lines) {
  if (!kApiLoggingEnabled) return;
  // ignore: avoid_print
  print('========== $title ==========');
  for (final line in lines) {
    for (final sub in line.split('\n')) {
      // ignore: avoid_print
      print(sub);
    }
  }
  // ignore: avoid_print
  print(_kBar);
}

/// Logs one completed HTTP call.
///
/// Pass [statusCode] and [responseBody] for a call that got a response, or
/// [error] for one that threw. A non-2xx status or a non-null [error] produces
/// the ERROR variant of the block.
///
/// [tag] names the module, e.g. `FUEL LOG API`.
void logApiCall({
  required String tag,
  required String method,
  required Uri uri,

  /// Overrides the params shown; defaults to the URI's own query string. Useful
  /// for a POST whose "parameters" live in the body.
  Map<String, String>? params,
  Map<String, String>? headers,

  /// Request body for POST/PUT/PATCH.
  Object? body,

  /// Multipart form fields, when the request is a `MultipartRequest`.
  Map<String, String>? fields,

  /// Multipart file descriptions, e.g. `before_image -> photo.jpg (12345 bytes)`.
  List<String>? files,
  int? statusCode,
  String? responseBody,
  Object? error,
  int? elapsedMs,
}) {
  if (!kApiLoggingEnabled) return;

  final failed =
      error != null || statusCode == null || statusCode < 200 || statusCode >= 300;

  final lines = <String>[
    'URL: $uri',
    'Method: ${method.toUpperCase()}',
    'Params: ${_formatParams(uri, params)}',
    if (headers != null && headers.isNotEmpty)
      'Headers: ${_maskHeaders(headers)}',
    if (fields != null && fields.isNotEmpty) 'Fields: $fields',
    if (files != null && files.isNotEmpty) ...[
      'Files:',
      ...files.map((f) => '  $f'),
    ],
    if (body != null) ...[
      'Body:',
      _formatBody(body is String ? body : jsonEncode(body)),
    ],
    'Status Code: ${statusCode ?? '(no response — request failed)'}',
    if (elapsedMs != null) 'Execution Time: $elapsedMs ms',
    '',
    if (error != null) ...[
      'Error:',
      error.toString(),
    ],
    if (responseBody != null) ...[
      failed ? 'Error Response:' : 'Response:',
      _formatBody(responseBody),
    ],
  ];

  _emit(failed ? '$tag ERROR' : tag, lines);
}
