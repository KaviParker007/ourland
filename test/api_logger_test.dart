// Tests for the structured API logger.
//
// These lock in the two properties that matter for troubleshooting: the block
// contains every field asked for (URL, method, params, body, status, response),
// and credentials never appear in it.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ourlandnew/services/api_logger.dart';
import 'package:ourlandnew/services/fuel_log_api_tag.dart';

/// Runs [body] with `print` captured, returning everything it emitted.
String capture(void Function() body) {
  final lines = <String>[];
  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines.join('\n');
}

const _auth = {
  'Content-Type': 'application/json',
  'authorization': 'Basic ZGVtbzpzM2NyZXQtcGFzc3dvcmQ=',
};

void main() {
  test('logging is on in debug builds, so these tests are meaningful', () {
    expect(kApiLoggingEnabled, isTrue);
  });

  group('successful call', () {
    late String out;

    setUp(() {
      out = capture(() {
        logApiCall(
          tag: kFuelLogApiTag,
          method: 'get',
          uri: Uri.parse(
              'https://ourlander.in/drf_get_last_fueling_detail/?vehicle_id=123'),
          headers: _auth,
          statusCode: 200,
          responseBody: '{"last_odo_reading": 4200, "mileage": 3.5}',
          elapsedMs: 431,
        );
      });
    });

    test('carries every requested field', () {
      expect(out, contains('========== FUEL LOG API =========='));
      expect(
          out,
          contains('URL: https://ourlander.in/'
              'drf_get_last_fueling_detail/?vehicle_id=123'));
      expect(out, contains('Method: GET')); // upper-cased for scanning
      expect(out, contains('Params: vehicle_id=123'));
      expect(out, contains('Status Code: 200'));
      expect(out, contains('Duration: 431 ms'));
      expect(out, contains('Response:'));
    });

    test('is the success block, not the error one', () {
      expect(out, isNot(contains('FUEL LOG API ERROR')));
      expect(out, isNot(contains('Error Response:')));
    });

    test('pretty-prints the JSON response', () {
      // Indented across lines — readable, and survives logcat's per-line cap.
      expect(out, contains('  "last_odo_reading": 4200'));
      expect(out, contains('  "mileage": 3.5'));
    });

    test('masks the credentials', () {
      expect(out, contains('Basic ****** (masked)'));
      expect(out, isNot(contains('ZGVtbzpzM2NyZXQtcGFzc3dvcmQ=')));
      // The non-sensitive headers still show.
      expect(out, contains('Content-Type'));
    });
  });

  group('failed call', () {
    test('a non-2xx status produces the ERROR block', () {
      final out = capture(() {
        logApiCall(
          tag: kFuelLogApiTag,
          method: 'POST',
          uri: Uri.parse('https://ourlander.in/drf-edit-fuel-log/'),
          headers: _auth,
          body: '{"fuellog_id": 12}',
          statusCode: 400,
          responseBody: '{"detail": "Invalid odo reading"}',
        );
      });

      expect(out, contains('========== FUEL LOG API ERROR =========='));
      expect(out, contains('Status Code: 400'));
      expect(out, contains('Error Response:'));
      expect(out, contains('Invalid odo reading'));
      // The request body is shown so the failing payload is visible.
      expect(out, contains('Body:'));
      expect(out, contains('"fuellog_id": 12'));
      expect(out, isNot(contains('ZGVtbzpzM2NyZXQtcGFzc3dvcmQ=')));
    });

    for (final code in [401, 404, 500]) {
      test('$code is treated as a failure', () {
        final out = capture(() {
          logApiCall(
            tag: kFuelLogApiTag,
            method: 'GET',
            uri: Uri.parse('https://ourlander.in/drf-fuel-log-list/'),
            statusCode: code,
            responseBody: 'server error',
          );
        });
        expect(out, contains('FUEL LOG API ERROR'));
        expect(out, contains('Status Code: $code'));
      });
    }

    test('201 is still a success', () {
      final out = capture(() {
        logApiCall(
          tag: kFuelLogApiTag,
          method: 'POST',
          uri: Uri.parse('https://ourlander.in/drf-add-fuel-log/'),
          statusCode: 201,
          responseBody: '{"id": 7}',
        );
      });
      expect(out, isNot(contains('ERROR')));
      expect(out, contains('Status Code: 201'));
    });

    test('an exception with no response is reported as such', () {
      final out = capture(() {
        logApiCall(
          tag: kFuelLogApiTag,
          method: 'GET',
          uri: Uri.parse('https://ourlander.in/drf-fuel-log-list/'),
          error: 'SocketException: Failed host lookup',
          elapsedMs: 30000,
        );
      });

      expect(out, contains('FUEL LOG API ERROR'));
      expect(out, contains('Status Code: (no response — request failed)'));
      expect(out, contains('Error:'));
      expect(out, contains('SocketException: Failed host lookup'));
    });
  });

  group('multipart call', () {
    test('shows fields and files instead of a body', () {
      final out = capture(() {
        logApiCall(
          tag: kFuelLogApiTag,
          method: 'POST',
          uri: Uri.parse('https://ourlander.in/drf-add-fuel-log/'),
          headers: _auth,
          fields: {'vehicle': '12', 'fuel_quantity': '40'},
          files: ['before_image -> photo.jpg (48211 bytes)'],
          statusCode: 201,
          responseBody: '{"id": 7}',
        );
      });

      expect(out, contains('Fields:'));
      expect(out, contains('vehicle: 12'));
      expect(out, contains('Files:'));
      expect(out, contains('before_image -> photo.jpg (48211 bytes)'));
    });
  });

  group('edge cases', () {
    test('a request with no query string says so', () {
      final out = capture(() {
        logApiCall(
          tag: kFuelLogApiTag,
          method: 'GET',
          uri: Uri.parse('https://ourlander.in/drf-fuel-log-list/'),
          statusCode: 200,
          responseBody: '[]',
        );
      });
      expect(out, contains('Params: (none)'));
    });

    test('a non-JSON response is shown verbatim rather than swallowed', () {
      final out = capture(() {
        logApiCall(
          tag: kFuelLogApiTag,
          method: 'GET',
          uri: Uri.parse('https://ourlander.in/drf-fuel-log-list/'),
          statusCode: 500,
          responseBody: '<html><body>Server Error</body></html>',
        );
      });
      expect(out, contains('<html><body>Server Error</body></html>'));
    });

    test('an empty body reads as (empty), not a blank gap', () {
      final out = capture(() {
        logApiCall(
          tag: kFuelLogApiTag,
          method: 'GET',
          uri: Uri.parse('https://ourlander.in/drf-fuel-log-list/'),
          statusCode: 204,
          responseBody: '',
        );
      });
      expect(out, contains('(empty)'));
    });

    test('params can be overridden for a body-carried query', () {
      final out = capture(() {
        logApiCall(
          tag: kFuelLogApiTag,
          method: 'POST',
          uri: Uri.parse('https://ourlander.in/drf-vehicles/'),
          params: {'is_active': 'true'},
          statusCode: 200,
          responseBody: '[]',
        );
      });
      expect(out, contains('Params: is_active=true'));
    });
  });
}
