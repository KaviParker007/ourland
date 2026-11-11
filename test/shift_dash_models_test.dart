// Shift Dashboard: response parsing, query params per status, record filters,
// and the activity-image upload error messages.

import 'package:flutter_test/flutter_test.dart';

import 'package:ourlandnew/pages/shifts/shift_dash_models.dart';
import 'package:ourlandnew/pages/shifts/shift_dash_service.dart';

void main() {
  final day = DateTime(2026, 11, 11);

  group('dashboard rows', () {
    test('reads dynamic vehicle types without a hardcoded list', () {
      final rows = parseShiftDash({
        'Open': [
          {'project': 'MDU', 'total': 9, 'LCV': 4, 'Hook Loader': 3, 'HCV': 2},
        ],
      }, ShiftStatus.open, 'project');

      expect(rows.single.label, 'MDU');
      expect(rows.single.total, 9);
      expect(rows.single.vehicleCounts,
          {'LCV': 4, 'Hook Loader': 3, 'HCV': 2});
    });

    test('drops zero counts and keeps response order', () {
      final row = ShiftDashRow.fromJson(
          {'zone': 'MDU-Z1', 'total': 3, 'Tipper': 0, 'EMV': 1, 'Compactor': 2},
          'zone');
      expect(row.vehicleCounts.keys, ['EMV', 'Compactor']);
    });

    test('creator rows keep the employee id separate from the code', () {
      final row = ShiftDashRow.fromJson({
        'name': 'Ravi Kumar',
        'employee_code': 'OL0123',
        'createdby': 77,
        'total': 2,
        'LCV': 2,
      }, 'name');
      expect(row.label, 'Ravi Kumar');
      expect(row.createdBy, 77);
      expect(row.employeeCode, 'OL0123');
      // Neither identifier is mistaken for a vehicle type.
      expect(row.vehicleCounts, {'LCV': 2});
    });

    test('ward totals are taken as returned, not re-summed', () {
      // Distinct count: one vehicle may serve several wards, so total need not
      // equal the sum of the vehicle-type counts.
      final row = ShiftDashRow.fromJson(
          {'ward': 'W-12', 'total': 3, 'LCV': 2, 'Tipper': 2}, 'ward');
      expect(row.total, 3);
    });

    test('reads only the list under the selected status', () {
      final decoded = {
        'Open': [
          {'project': 'A', 'total': 1}
        ],
        'Long': [
          {'project': 'B', 'total': 2}
        ],
      };
      expect(parseShiftDash(decoded, ShiftStatus.long, 'project').single.label,
          'B');
    });

    test('empty, missing and malformed responses are safe', () {
      expect(parseShiftDash(null, ShiftStatus.open, 'project'), isEmpty);
      expect(parseShiftDash({}, ShiftStatus.open, 'project'), isEmpty);
      expect(parseShiftDash({'Open': 'x'}, ShiftStatus.open, 'project'),
          isEmpty);
      expect(
          parseShiftDash({
            'Open': [
              'not a map',
              {'total': 4}, // no label
            ]
          }, ShiftStatus.open, 'project'),
          isEmpty);
    });
  });

  group('query params', () {
    test('Open, Closed and Long send the date', () {
      for (final s in [ShiftStatus.open, ShiftStatus.closed, ShiftStatus.long]) {
        expect(ShiftDashQuery(status: s, date: day).baseParams(),
            {'shift_status': s.apiValue, 'date': '2026-11-11'});
      }
    });

    test('Unclosed omits the date entirely', () {
      expect(
          ShiftDashQuery(status: ShiftStatus.unclosed, date: day).baseParams(),
          {'shift_status': 'Unclosed'});
    });

    test('Unclosed results do not depend on the chosen date', () {
      final a = ShiftDashQuery(status: ShiftStatus.unclosed, date: day);
      final b = a.copyWith(date: DateTime(2026, 1, 1));
      expect(a.key('Z1'), b.key('Z1'));
    });

    test('record filter passes every selected filter', () {
      final f = ShiftListFilter(
        query: ShiftDashQuery(status: ShiftStatus.long, date: day),
        project: 'MDU',
        zoneCode: 'MDU-Z1',
        wardCode: 'W-12',
        createdBy: 77,
        creatorLabel: 'Ravi Kumar',
      ).withVehicleType('Hook Loader');

      expect(f.toParams(), {
        'shift_status': 'Long',
        'date': '2026-11-11',
        'vehicle_type': 'Hook Loader',
        'project': 'MDU',
        'zone_code': 'MDU-Z1',
        'ward_code': 'W-12',
        'createdby': '77',
      });
    });

    test('Unclosed record filter keeps location filters but no date', () {
      final f = ShiftListFilter(
        query: ShiftDashQuery(status: ShiftStatus.unclosed, date: day),
        zoneCode: 'MDU-Z1',
      );
      expect(f.toParams().containsKey('date'), isFalse);
      expect(f.toParams()['zone_code'], 'MDU-Z1');
    });
  });

  group('vehicle type colour', () {
    test('is stable for unknown types', () {
      expect(vehicleTypeColor('Hook Loader'), vehicleTypeColor('Hook Loader'));
    });
  });

  group('activity image upload errors', () {
    test('403 is an access message, not a login one', () {
      final e = ShiftDashboardApi.activityUploadError(
          403, '{"detail": "You do not have permission to perform this action."}');
      expect(e.statusCode, 403);
      expect(e.message, contains("don't have permission to upload"));
      expect(e.message.toLowerCase(), isNot(contains('log in')));
    });

    test('400 messages from the backend', () {
      expect(
          ShiftDashboardApi.activityUploadError(
                  400, '{"error": "image is required"}')
              .message,
          'image is required');
      expect(
          ShiftDashboardApi.activityUploadError(
                  400, '{"error": "Shift has no current trip."}')
              .message,
          'This shift has no current trip to attach the image to.');
    });

    test('404 and 401', () {
      expect(
          ShiftDashboardApi.activityUploadError(404, '{"detail": "Not found."}')
              .message,
          contains('could not be found'));
      expect(ShiftDashboardApi.activityUploadError(401, '').message,
          contains('log in again'));
    });
  });
}
