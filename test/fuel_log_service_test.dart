// Rules for the Add Fuel Log submission: which fields are posted, how the tag
// number and alert message are handled, client-side validation, and how
// backend errors read in the snackbar.

import 'package:flutter_test/flutter_test.dart';

import 'package:ourlandnew/pages/fuel_log/fuel_log_service.dart';
import 'package:ourlandnew/pages/fuel_log/last_fueling_detail.dart';

FuelLogSubmission _submission({
  String? fuelUnitCost,
  int? tagNumber,
  String? remark,
  String? alertMessage,
  String? before = '/tmp/before.jpg',
  String? indent,
  String? after,
}) =>
    FuelLogSubmission(
      vehicle: 12,
      fuelStation: 3,
      fuelType: 'D',
      odoReading: ' 4500.5 ',
      fuelQuantity: '40',
      fuelUnitCost: fuelUnitCost,
      tagNumber: tagNumber,
      remark: remark,
      alertMessage: alertMessage,
      beforeImagePath: before,
      indentImagePath: indent,
      afterImagePath: after,
    );

String? _validate({
  int? vehicle = 12,
  int? station = 3,
  String? fuelType = 'D',
  String odo = '5000',
  String qty = '40',
  String cost = '',
  String tag = '',
  String before = '/tmp/before.jpg',
  LastFuelingDetail? last,
}) =>
    validateFuelLogInput(
      vehicle: vehicle,
      fuelStation: station,
      fuelType: fuelType,
      odoReading: odo,
      fuelQuantity: qty,
      fuelUnitCost: cost,
      tagNumber: tag,
      beforeImagePath: before,
      lastDetail: last,
    );

void main() {
  group('submission fields', () {
    test('sends the required fields with the real ids', () {
      expect(_submission().toFields(), {
        'vehicle': '12',
        'fuel_station': '3',
        'fuel_type': 'D',
        'odo_reading': '4500.5',
        'fuel_quantity': '40',
      });
    });

    test('omits optional fields that were left empty', () {
      final fields =
          _submission(fuelUnitCost: '  ', remark: '', tagNumber: null)
              .toFields();
      expect(fields.containsKey('fuel_unit_cost'), isFalse);
      expect(fields.containsKey('remark'), isFalse);
      expect(fields.containsKey('tag_number'), isFalse);
      expect(fields.containsKey('alert_message'), isFalse);
    });

    test('sends tag_number as a plain integer, never tank_tag', () {
      final fields = _submission(tagNumber: 1042).toFields();
      expect(fields['tag_number'], '1042');
      expect(fields.containsKey('tank_tag'), isFalse);
    });

    test('sends the alert message unchanged', () {
      const msg = 'achieved mileage 0.0 is very less than target mileage 4.0';
      expect(_submission(alertMessage: msg).toFields()['alert_message'], msg);
    });

    test('never sends server-managed fields', () {
      final fields = _submission(
              fuelUnitCost: '95', tagNumber: 1, remark: 'r', alertMessage: 'a')
          .toFields();
      for (final key in const [
        'fuel_date',
        'project',
        'zone',
        'ward',
        'last_odo_reading',
        'last_fuel_date',
        'last_fuel_time',
        'last_fuel_quantity',
      ]) {
        expect(fields.containsKey(key), isFalse, reason: key);
      }
    });

    test('attaches only the images that were captured', () {
      expect(_submission(after: '/tmp/after.jpg').toFiles(), {
        'before_image': '/tmp/before.jpg',
        'after_image': '/tmp/after.jpg',
      });
    });
  });

  group('tag number to submit', () {
    test('an unchanged prefilled tag is not re-sent', () {
      expect(tagNumberToSubmit('1042', 1042), isNull);
    });

    test('a changed tag is sent', () {
      expect(tagNumberToSubmit('1043', 1042), 1043);
    });

    test('a new tag is sent when there was none', () {
      expect(tagNumberToSubmit('7', null), 7);
    });

    test('an empty field sends nothing', () {
      expect(tagNumberToSubmit('', 1042), isNull);
      expect(tagNumberToSubmit('', null), isNull);
    });
  });

  group('validation', () {
    test('a complete form passes', () {
      expect(_validate(), isNull);
    });

    test('required selections', () {
      expect(_validate(vehicle: null), 'Please select a vehicle.');
      expect(_validate(station: null), 'Please select a fuel station.');
      expect(_validate(fuelType: null), 'Please select a fuel type.');
      expect(_validate(fuelType: 'X'), 'Please select a fuel type.');
      expect(_validate(before: ''), 'Please capture the before image.');
    });

    test('odometer', () {
      expect(_validate(odo: ''), 'Please enter the odometer reading.');
      expect(_validate(odo: '1.2.3'), 'Please enter a valid odometer reading.');
    });

    test('odometer below the last reading is rejected', () {
      const last = LastFuelingDetail(
          lastOdoReading: 6000, lastFuelDate: '2026-10-01', lastFuelQuantity: 30);
      expect(_validate(odo: '5999', last: last),
          contains('cannot be less than the last reading'));
      expect(_validate(odo: '6000', last: last), isNull);
    });

    test('first fueling has no lower odometer bound', () {
      const first = LastFuelingDetail(
          lastOdoReading: 0, lastFuelQuantity: 0, mileage: 0);
      expect(_validate(odo: '0', last: first), isNull);
    });

    test('fuel quantity must be 1 to 250', () {
      const msg = 'Fuel quantity must be between 1 and 250.';
      expect(_validate(qty: '0.5'), msg);
      expect(_validate(qty: '251'), msg);
      expect(_validate(qty: '1'), isNull);
      expect(_validate(qty: '250'), isNull);
    });

    test('unit cost is optional, but 70 to 120 when given', () {
      const msg = 'Fuel unit cost must be between 70 and 120.';
      expect(_validate(cost: ''), isNull);
      expect(_validate(cost: '69.9'), msg);
      expect(_validate(cost: '121'), msg);
      expect(_validate(cost: '92.5'), isNull);
    });

    test('tag number must be a positive whole number', () {
      expect(_validate(tag: '0'), 'Tag number must be a whole number.');
      expect(_validate(tag: '12'), isNull);
    });
  });

  group('error messages', () {
    test('401 asks the user to log in again', () {
      expect(fuelLogErrorMessage(401, '{"detail":"Invalid credentials"}'),
          kFuelLogSessionExpired);
    });

    test('backend validation text is shown as-is', () {
      expect(fuelLogErrorMessage(400, '{"error": "Vehicle ID is required"}'),
          'Vehicle ID is required');
      expect(
          fuelLogErrorMessage(400,
              '{"error": "Last odometer reading is greater than the current odometer value"}'),
          'Last odometer reading is greater than the current odometer value');
      expect(
          fuelLogErrorMessage(
              400, '{"message": ["Fuel quantity must be between 1 and 250"]}'),
          'Fuel quantity must be between 1 and 250');
    });

    test('serializer errors are listed per field', () {
      expect(
        fuelLogErrorMessage(400,
            '{"odo_reading": ["A valid number is required."], "fuel_station": ["This field is required."]}'),
        'Odo reading: A valid number is required.\n'
        'Fuel station: This field is required.',
      );
    });

    test('non_field_errors are shown without a field prefix', () {
      expect(
          fuelLogErrorMessage(
              400, '{"non_field_errors": ["Fuel unit cost must be between 70 and 120"]}'),
          'Fuel unit cost must be between 70 and 120');
    });

    test('an unreadable body falls back to a friendly message', () {
      expect(fuelLogErrorMessage(400, '<html>Bad Request</html>'),
          'Could not save the fuel log. Please check the details and try again.');
      expect(fuelLogErrorMessage(500, 'Traceback ...'),
          'Server error (500). Please try again later.');
    });
  });

  group('form options', () {
    test('parses both lists and tolerates a missing one', () {
      final options = FuelLogFormOptions.fromJson({
        'vehicle_list': [
          {'id': 5, 'vehicle_number': 'TN 59 AB 1234'},
          'not a map',
        ],
      });
      expect(options.vehicles.single.id, 5);
      expect(options.vehicles.single.vehicleNumber, 'TN 59 AB 1234');
      expect(options.fuelStations, isEmpty);
    });
  });

  group('last fueling detail', () {
    test('reads tag_number', () {
      expect(LastFuelingDetail.fromJson({'tag_number': 1042}).tagNumber, 1042);
      expect(LastFuelingDetail.fromJson({'tag_number': null}).tagNumber, isNull);
    });

    test('a zeroed response is a first fueling, not a failure', () {
      final first = LastFuelingDetail.fromJson({
        'last_odo_reading': 0.0,
        'last_fuel_date': null,
        'last_fuel_time': null,
        'last_fuel_quantity': 0.0,
        'tag_number': null,
        'mileage': 0.0,
        'mileage_status': 0.0,
        'fuel_freq': 0,
        'alert': false,
        'alert_message': [],
      });
      expect(first.isFirstFueling, isTrue);
      expect(first.shouldWarn, isFalse);
    });

    test('a vehicle with history is not a first fueling', () {
      expect(
          LastFuelingDetail.fromJson(
              {'last_odo_reading': 4200, 'last_fuel_date': '2026-10-01'})
              .isFirstFueling,
          isFalse);
    });
  });
}
