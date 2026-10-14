// ─── Logged HTTP client ────────────────────────────────────────────────────────
//
// Drop-in replacement for `package:http/http.dart`. Import it the same way:
//
//   import 'package:ourlandnew/services/http_client.dart' as http;
//
// and keep calling `http.get`, `http.post`, `http.MultipartRequest(...).send()`
// etc. Every request made through it is logged by `logApiCall` (see
// api_logger.dart): URL, method, headers (authorization masked), request body
// or multipart fields/files, status code, response body and execution time.
// Failed responses and thrown exceptions are logged as ERROR blocks.
//
// Logging happens at the transport layer, so call sites need no logging code of
// their own. In release builds `kApiLoggingEnabled` is false and requests pass
// straight through without buffering.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_logger.dart';

export 'package:http/http.dart'
    hide get, post, put, patch, delete, head, read, readBytes, MultipartRequest;

/// Shared client behind the top-level helpers below.
final LoggingClient _client = LoggingClient();

Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    _client.get(url, headers: headers);

Future<http.Response> head(Uri url, {Map<String, String>? headers}) =>
    _client.head(url, headers: headers);

Future<http.Response> post(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _client.post(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> put(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _client.put(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> patch(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _client.patch(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> delete(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _client.delete(url, headers: headers, body: body, encoding: encoding);

/// `http.MultipartRequest` whose `send()` goes through [LoggingClient].
class MultipartRequest extends http.MultipartRequest {
  MultipartRequest(super.method, super.url);

  @override
  Future<http.StreamedResponse> send() async {
    final client = LoggingClient();
    try {
      return await client.send(this);
    } finally {
      // Safe: LoggingClient has already buffered the whole response body.
      client.close();
    }
  }
}

/// Client that logs every request it sends.
class LoggingClient extends http.BaseClient {
  final http.Client _inner;

  LoggingClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!kApiLoggingEnabled) return _inner.send(request);

    final sw = Stopwatch()..start();
    try {
      final streamed = await _inner.send(request);
      // Buffer the body so it can be logged, then hand the caller an
      // equivalent response built from the same bytes.
      final bytes = await streamed.stream.toBytes();
      sw.stop();

      _log(
        request,
        elapsedMs: sw.elapsedMilliseconds,
        statusCode: streamed.statusCode,
        responseBody: http.Response.bytes(bytes, streamed.statusCode,
                headers: streamed.headers)
            .body,
      );

      return http.StreamedResponse(
        http.ByteStream.fromBytes(bytes),
        streamed.statusCode,
        contentLength: bytes.length,
        request: streamed.request,
        headers: streamed.headers,
        isRedirect: streamed.isRedirect,
        persistentConnection: streamed.persistentConnection,
        reasonPhrase: streamed.reasonPhrase,
      );
    } catch (e) {
      sw.stop();
      _log(request, elapsedMs: sw.elapsedMilliseconds, error: e);
      rethrow;
    }
  }

  void _log(
    http.BaseRequest request, {
    required int elapsedMs,
    int? statusCode,
    String? responseBody,
    Object? error,
  }) {
    logApiCall(
      tag: 'API ${request.method.toUpperCase()} ${request.url.path}',
      method: request.method,
      uri: request.url,
      headers: request.headers,
      body: request is http.Request && request.body.isNotEmpty
          ? request.body
          : null,
      fields: request is http.MultipartRequest ? request.fields : null,
      files: request is http.MultipartRequest
          ? request.files
              .map((f) => '${f.field} -> ${f.filename ?? '(no name)'} '
                  '(${f.length} bytes)')
              .toList()
          : null,
      statusCode: statusCode,
      responseBody: responseBody,
      error: error,
      elapsedMs: elapsedMs,
    );
  }

  @override
  void close() => _inner.close();
}
