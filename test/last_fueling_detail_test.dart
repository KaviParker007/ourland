// Tests for the updated drf_get_last_fueling_detail/ response.
//
// The listed edge cases are the point of this file: a null / empty / bare-string
// alert_message, alert true with no text, alert false, multiple messages, and
// missing or wrong-typed fields must all be safe.

import 'package:flutter_test/flutter_test.dart';

import 'package:ourlandnew/pages/fuel_log/last_fueling_detail.dart';

void main() {
  group('the documented payload', () {
    final detail = LastFuelingDetail.fromJson(const {
      'last_odo_reading': 0.0,
      'last_fuel_date': '2026-09-08',
      'last_fuel_time': '2026-09-08T14:52:15.879030',
      'last_fuel_quantity': 20.0,
      'mileage': 0.0,
      'mileage_status': 0.0,
      'fuel_freq': 0,
      'alert': true,
      'alert_message': [
        'achieved mileage 0.0 is very less than target mileage 4.0'
      ],
    });

    test('parses every field', () {
      expect(detail.lastOdoReading, 0.0);
      expect(detail.lastFuelDate, '2026-09-08');
      expect(detail.lastFuelTime, '2026-09-08T14:52:15.879030');
      expect(detail.lastFuelQuantity, 20.0);
      expect(detail.mileage, 0.0);
      expect(detail.mileageStatus, 0.0);
      expect(detail.fuelFreq, 0);
      expect(detail.alert, isTrue);
      expect(detail.alertMessages, [
        'achieved mileage 0.0 is very less than target mileage 4.0'
      ]);
    });

    test('renders each value for display', () {
      expect(detail.odoReadingDisplay, '0.0');
      expect(detail.fuelDateDisplay, '2026-09-08');
      // The ISO timestamp is reduced to the clock time; the date has its own
      // field, so repeating it would be noise.
      expect(detail.fuelTimeDisplay, '02:52 PM');
      expect(detail.fuelQuantityDisplay, '20.0 L');
      expect(detail.mileageDisplay, '0.0');
      expect(detail.mileageStatusDisplay, '0.0');
      expect(detail.fuelFreqDisplay, '0');
    });

    test('warns, and posts the message back verbatim', () {
      expect(detail.shouldWarn, isTrue);
      expect(detail.hasAlertMessages, isTrue);
      expect(detail.alertMessageForSubmission,
          'achieved mileage 0.0 is very less than target mileage 4.0');
    });

    test('a zero value is shown, not mistaken for missing', () {
      // 0.0 is a real reading; it must not render as N/A.
      expect(detail.odoReadingDisplay, isNot('N/A'));
      expect(detail.fuelFreqDisplay, '0');
    });
  });

  group('alert flag', () {
    LastFuelingDetail withAlert(Object? alert, {Object? messages}) =>
        LastFuelingDetail.fromJson({
          'alert': alert,
          if (messages != null) 'alert_message': messages,
        });

    test('false does not warn', () {
      expect(withAlert(false).shouldWarn, isFalse);
      expect(withAlert(false).alertMessageForSubmission, isNull);
    });

    test('missing does not warn', () {
      expect(LastFuelingDetail.fromJson(const {}).shouldWarn, isFalse);
    });

    test('true with an empty message list still warns', () {
      // The backend can flag a problem without text; swallowing that would be
      // worse than showing a warning with no detail.
      final d = withAlert(true, messages: const []);
      expect(d.shouldWarn, isTrue);
      expect(d.hasAlertMessages, isFalse);
      // Nothing is invented to post back.
      expect(d.alertMessageForSubmission, isNull);
    });

    test('true with a null message list still warns', () {
      final d = LastFuelingDetail.fromJson(
          const {'alert': true, 'alert_message': null});
      expect(d.shouldWarn, isTrue);
      expect(d.alertMessages, isEmpty);
      expect(d.alertMessageForSubmission, isNull);
    });

    test('coerces the string and numeric spellings of true', () {
      expect(withAlert('true').shouldWarn, isTrue);
      expect(withAlert(1).shouldWarn, isTrue);
      expect(withAlert('false').shouldWarn, isFalse);
      expect(withAlert(0).shouldWarn, isFalse);
      expect(withAlert('nonsense').shouldWarn, isFalse);
    });
  });

  group('alert_message shapes', () {
    List<String> parse(Object? raw) =>
        LastFuelingDetail.fromJson({'alert_message': raw}).alertMessages;

    test('a bare string becomes a one-element list', () {
      expect(parse('mileage too low'), ['mileage too low']);
    });

    test('blank and null entries are dropped', () {
      expect(parse(const ['', '  ', null, 'real warning']),
          ['real warning']);
      expect(parse(const ['', null]), isEmpty);
      expect(parse(''), isEmpty);
    });

    test('multiple messages are all kept, in order', () {
      final d = LastFuelingDetail.fromJson(const {
        'alert': true,
        'alert_message': ['first warning', 'second warning'],
      });
      expect(d.alertMessages, ['first warning', 'second warning']);
      // Joined for the multipart POST, since a form field is a plain string.
      expect(d.alertMessageForSubmission, 'first warning | second warning');
    });

    test('non-string entries are stringified rather than dropped', () {
      expect(parse(const [42]), ['42']);
    });
  });

  group('missing and wrong-typed fields', () {
    test('an empty payload is entirely safe', () {
      final d = LastFuelingDetail.fromJson(const {});
      expect(d.lastOdoReading, isNull);
      expect(d.odoReadingDisplay, 'N/A');
      expect(d.fuelDateDisplay, 'N/A');
      expect(d.fuelTimeDisplay, 'N/A');
      expect(d.fuelQuantityDisplay, 'N/A');
      expect(d.mileageDisplay, 'N/A');
      expect(d.mileageStatusDisplay, 'N/A');
      expect(d.fuelFreqDisplay, 'N/A');
      expect(d.shouldWarn, isFalse);
    });

    test('explicit nulls behave like missing keys', () {
      final d = LastFuelingDetail.fromJson(const {
        'last_odo_reading': null,
        'last_fuel_date': null,
        'last_fuel_time': null,
        'last_fuel_quantity': null,
        'mileage': null,
        'mileage_status': null,
        'fuel_freq': null,
      });
      expect(d.odoReadingDisplay, 'N/A');
      expect(d.fuelTimeDisplay, 'N/A');
      expect(d.fuelFreqDisplay, 'N/A');
    });

    test('numbers arriving as strings still parse', () {
      final d = LastFuelingDetail.fromJson(const {
        'last_odo_reading': '4200.5',
        'last_fuel_quantity': '20',
        'fuel_freq': '3',
      });
      expect(d.lastOdoReading, 4200.5);
      expect(d.lastFuelQuantity, 20.0);
      expect(d.fuelFreq, 3);
    });

    test('an unparseable number reads as absent rather than throwing', () {
      final d = LastFuelingDetail.fromJson(const {
        'last_odo_reading': 'not a number',
        'fuel_freq': 'n/a',
      });
      expect(d.lastOdoReading, isNull);
      expect(d.odoReadingDisplay, 'N/A');
      expect(d.fuelFreqDisplay, 'N/A');
    });

    test('a non-timestamp last_fuel_time is shown as-is', () {
      final d = LastFuelingDetail.fromJson(
          const {'last_fuel_time': 'sometime yesterday'});
      expect(d.fuelTimeDisplay, 'sometime yesterday');
    });

    test('a date-only last_fuel_time still formats', () {
      final d =
          LastFuelingDetail.fromJson(const {'last_fuel_time': '2026-09-08'});
      expect(d.fuelTimeDisplay, '12:00 AM');
    });

    test('the empty constant is inert', () {
      expect(LastFuelingDetail.empty.shouldWarn, isFalse);
      expect(LastFuelingDetail.empty.alertMessages, isEmpty);
      expect(LastFuelingDetail.empty.odoReadingDisplay, 'N/A');
    });
  });
}
