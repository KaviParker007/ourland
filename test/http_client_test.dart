// Tests for the logged HTTP client: every request is logged with its details,
// and the caller still receives the response unchanged.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as raw;
import 'package:http/testing.dart';

import 'package:ourlandnew/services/http_client.dart' as http;

/// Runs [body] with `print` captured, returning its result and the output.
Future<(T, String)> capture<T>(Future<T> Function() body) async {
  final lines = <String>[];
  final result = await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return (result, lines.join('\n'));
}

const _headers = {
  'Content-Type': 'application/json',
  'authorization': 'Basic ZGVtbzpzM2NyZXQtcGFzc3dvcmQ=',
};

void main() {
  final uri = Uri.parse('https://example.test/drf-end-job-card-v2/?x=1');

  test('logs a successful POST and passes the response through', () async {
    final client = http.LoggingClient(MockClient((req) async {
      return raw.Response('{"message": "success"}', 200);
    }));

    final (resp, out) = await capture(() => client.post(uri,
        headers: _headers,
        body: jsonEncode({'id': 7, 'additional_cost': '12.50'})));

    expect(resp.statusCode, 200);
    expect(resp.body, '{"message": "success"}');

    expect(out, contains('API POST /drf-end-job-card-v2/'));
    expect(out, contains('URL: $uri'));
    expect(out, contains('Method: POST'));
    expect(out, contains('Params: x=1'));
    expect(out, contains('"additional_cost": "12.50"'));
    expect(out, contains('Status Code: 200'));
    expect(out, contains('Execution Time:'));
    expect(out, contains('"message": "success"'));
    expect(out, isNot(contains('ZGVtbzpzM2NyZXQtcGFzc3dvcmQ=')));
    expect(out, isNot(contains('ERROR')));
  });

  test('logs a non-2xx response as an ERROR block', () async {
    final client = http.LoggingClient(MockClient((req) async {
      return raw.Response('{"detail": "bad"}', 400);
    }));

    final (resp, out) = await capture(() => client.get(uri, headers: _headers));

    expect(resp.statusCode, 400);
    expect(out, contains('API GET /drf-end-job-card-v2/ ERROR'));
    expect(out, contains('Status Code: 400'));
    expect(out, contains('Error Response:'));
  });

  test('logs an exception and rethrows it', () async {
    final client = http.LoggingClient(MockClient((req) async {
      throw raw.ClientException('connection refused');
    }));

    final lines = <String>[];
    await expectLater(
      runZoned(
        () => client.get(uri, headers: _headers),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => lines.add(line),
        ),
      ),
      throwsA(isA<raw.ClientException>()),
    );
    final out = lines.join('\n');

    expect(out, contains('API GET /drf-end-job-card-v2/ ERROR'));
    expect(out, contains('connection refused'));
    expect(out, contains('(no response — request failed)'));
  });

  test('logs multipart fields and files', () async {
    final client = http.LoggingClient(MockClient.streaming((req, _) async {
      return raw.StreamedResponse(
          Stream.value(utf8.encode('{"ok": true}')), 201);
    }));

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({'authorization': _headers['authorization']!})
      ..fields['id'] = '7'
      ..files.add(http.MultipartFile.fromBytes('after_image', [1, 2, 3],
          filename: 'photo.jpg'));

    final (resp, out) = await capture(() async =>
        raw.Response.fromStream(await client.send(request)));

    expect(resp.statusCode, 201);
    expect(resp.body, '{"ok": true}');
    expect(out, contains('Fields: {id: 7}'));
    expect(out, contains('after_image -> photo.jpg (3 bytes)'));
  });
}
