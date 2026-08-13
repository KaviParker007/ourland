// Unit tests for the Vehicle Type Dashboard models.
//
// Covers the tricky parsing cases called out in the spec:
//   • pivot rows with zero-omitted / missing type keys
//   • the status-chain trailing `zone_id == "Total"` summary row
//   • terminal `ward` / `ward_code` list parsing (single value and list)

import 'package:flutter_test/flutter_test.dart';
import 'package:ourlandnew/pages/vehicle_type/vehicle_type_models.dart';

void main() {
  group('VehiclePivotRow', () {
    test('parses dynamic type keys and treats missing keys as 0', () {
      final row = VehiclePivotRow.fromJson(
        {'project': 'MDU', 'Tipper': 5, 'LCV': 3},
        labelKey: 'project',
      );
      expect(row.label, 'MDU');
      expect(row.id, isNull);
      expect(row.count('Tipper'), 5);
      expect(row.count('LCV'), 3);
      // A type absent from the JSON must read back as 0, never throw.
      expect(row.count('EMV'), 0);
      expect(row.total, 8);
    });

    test('extracts zone_id and excludes it from the type counts', () {
      final row = VehiclePivotRow.fromJson(
        {'zone': 'MDU-Z1', 'zone_id': 7, 'Tractor': 2},
        labelKey: 'zone',
        idKey: 'zone_id',
      );
      expect(row.label, 'MDU-Z1');
      expect(row.id, 7);
      expect(row.countsByType.containsKey('zone_id'), isFalse);
      expect(row.count('Tractor'), 2);
      expect(row.total, 2);
    });

    test('unionVehicleTypes preserves a consistent, ordered column set', () {
      final rows = [
        VehiclePivotRow.fromJson({'project': 'A', 'Tipper': 1}, labelKey: 'project'),
        VehiclePivotRow.fromJson({'project': 'B', 'LCV': 2}, labelKey: 'project'),
      ];
      final types = unionVehicleTypes(rows);
      // LCV precedes Tipper in the canonical kVehicleTypes ordering.
      expect(types, ['LCV', 'Tipper']);
    });
  });

  group('VehicleStatusRow', () {
    test('parses buckets, defaulting omitted keys to 0', () {
      final row = VehicleStatusRow.fromJson(
        {'zone': 'MDU-Z1', 'zone_id': 7, 'total': 10, 'working': 4},
        labelKey: 'zone',
        idKey: 'zone_id',
      );
      expect(row.label, 'MDU-Z1');
      expect(row.id, 7);
      expect(row.isTotalRow, isFalse);
      expect(row.total, 10);
      expect(row.working, 4);
      expect(row.idle, 0); // omitted → 0
      expect(row.bucket(VehicleStatusBucket.working), 4);
      expect(row.bucket(VehicleStatusBucket.allIdle), 0);
    });

    test('detects the trailing Total summary row (zone_id == "Total")', () {
      final row = VehicleStatusRow.fromJson(
        {'zone': 'Total', 'zone_id': 'Total', 'total': 42, 'working': 20},
        labelKey: 'zone',
        idKey: 'zone_id',
      );
      expect(row.isTotalRow, isTrue);
      expect(row.id, isNull); // never a real, tappable zone id
      expect(row.total, 42);
      expect(row.working, 20);
    });
  });

  group('VehicleRecord', () {
    test('parses ward / ward_code as lists', () {
      final v = VehicleRecord.fromJson({
        'id': 1,
        'vehicle_number': 'TN01AB1234',
        'vehicle_type': 'Tipper',
        'project': 'MDU',
        'zone': 7,
        'zone_code': 'MDU-Z1',
        'ward': [75, 76],
        'ward_code': ['MDU-Z1-W03', 'MDU-Z1-W04'],
        'vehicle_status': 'working',
        'is_reasoned_today': null,
      });
      expect(v.wards, [75, 76]);
      expect(v.wardCodes, ['MDU-Z1-W03', 'MDU-Z1-W04']);
      expect(v.vehicleStatus, 'working');
      expect(v.isReasonedToday, isNull);
    });

    test('coerces a single ward value into a one-element list', () {
      final v = VehicleRecord.fromJson({
        'id': 2,
        'vehicle_number': 'TN02CD5678',
        'vehicle_type': 'LCV',
        'project': 'TBM',
        'ward': 75,
        'ward_code': 'TBM-Z1-W01',
        'vehicle_status': 'idle',
        'is_reasoned_today': 'Driver on leave',
      });
      expect(v.wards, [75]);
      expect(v.wardCodes, ['TBM-Z1-W01']);
      expect(v.isReasonedToday, 'Driver on leave');
    });
  });

  group('VehicleStatusBucket mapping', () {
    test('maps buckets to the correct vehicle_status filter values', () {
      expect(VehicleStatusBucket.total.vehicleStatusValue, 'All');
      expect(VehicleStatusBucket.working.vehicleStatusValue, 'Working');
      expect(VehicleStatusBucket.longShift.vehicleStatusValue, 'Long Shift');
      expect(VehicleStatusBucket.utilized.vehicleStatusValue, 'Utilized');
      expect(VehicleStatusBucket.maintenance.vehicleStatusValue,
          'Under Maintenance');
      expect(VehicleStatusBucket.idle.vehicleStatusValue, 'Idle');
      expect(VehicleStatusBucket.allIdle.vehicleStatusValue, 'All Idle');
    });
  });

  group('VehicleFilters', () {
    test('defaults are all "All" and report no active filters', () {
      const f = VehicleFilters();
      expect(f.vehicleStatus, 'All');
      expect(f.vehicleOwner, 'All');
      expect(f.hasActive, isFalse);
    });

    test('copyWith flips hasActive and preserves other fields', () {
      const f = VehicleFilters();
      final g = f.copyWith(vehicleStatus: 'Working');
      expect(g.vehicleStatus, 'Working');
      expect(g.vehicleOwner, 'All');
      expect(g.hasActive, isTrue);
    });
  });
}
