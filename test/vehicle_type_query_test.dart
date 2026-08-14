// Unit tests for the Vehicle Type query object and URL builder.
//
// These pin down the six documented drill-down interactions: every tap target on
// Screens 1–3 must produce exactly the query string in the specification, with
// all parameters accumulated so far plus the two global filters.

import 'package:flutter_test/flutter_test.dart';
import 'package:ourlandnew/pages/vehicle_type/vehicle_type_models.dart';
import 'package:ourlandnew/pages/vehicle_type/vehicle_type_query.dart';

const String _host = 'https://ourlander.in';

/// The query as Screen 1 holds it, with default filters.
const VehicleQuery root = VehicleQuery();

/// Renders `path?params` for a readable comparison in the expectations below.
String render(String path, Map<String, String> params) {
  final uri = buildVehicleUri(_host, path, params);
  return '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
}

void main() {
  group('encodeFilterValue', () {
    test('sends "All" literally while kOmitAllFilterValues is false', () {
      // This test documents the currently confirmed backend behaviour. If the
      // backend team switches to omission, flip kOmitAllFilterValues and this
      // expectation flips with it — nothing else in the module changes.
      expect(kOmitAllFilterValues, isFalse);
      expect(encodeFilterValue('All'), 'All');
    });

    test('drops null and blank values', () {
      expect(encodeFilterValue(null), isNull);
      expect(encodeFilterValue(''), isNull);
      expect(encodeFilterValue('   '), isNull);
    });

    test('trims and preserves real selections', () {
      expect(encodeFilterValue('  Working '), 'Working');
      expect(encodeFilterValue('Under Maintenance'), 'Under Maintenance');
    });
  });

  group('cleanParams', () {
    test('removes null and blank entries and trims survivors', () {
      final out = cleanParams({
        'a': 'x',
        'b': null,
        'c': '',
        'd': '  y  ',
      });
      expect(out, {'a': 'x', 'd': 'y'});
    });
  });

  group('buildVehicleUri', () {
    test('joins host and path without doubling the slash', () {
      expect(buildVehicleUri('$_host/', 'drf_vehicle_dash_by_project/', const {})
          .toString(), '$_host/drf_vehicle_dash_by_project/');
      expect(buildVehicleUri(_host, '/drf_vehicle_dash_by_project/', const {})
          .toString(), '$_host/drf_vehicle_dash_by_project/');
    });

    test('omits the query string entirely when there are no params', () {
      final uri = buildVehicleUri(_host, VehicleEndpoints.idleReason, const {});
      expect(uri.hasQuery, isFalse);
    });

    test('percent-encodes multi-word filter values', () {
      final q = root.withFilters(
          const VehicleFilters(vehicleStatus: 'Under Maintenance'));
      final uri = buildVehicleUri(
        _host,
        VehicleEndpoints.dashByProject,
        q.aggregateParams(
            chain: VehicleChain.location, level: VehicleLevel.project),
      );
      expect(uri.query, contains('vehicle_status=Under+Maintenance'));
      // Round-trips back to the literal the backend expects.
      expect(uri.queryParameters['vehicle_status'], 'Under Maintenance');
    });
  });

  group('VehicleQuery — accumulation', () {
    test('drillToZones sets the project and clears any deeper scope', () {
      final q = root
          .drillToWards(zoneId: 7, zoneCode: 'MDU-Zone1')
          .drillToZones('TBM');
      expect(q.project, 'TBM');
      expect(q.zoneId, isNull);
      expect(q.wardId, isNull);
      expect(q.vehicleType, kAllFilterValue);
    });

    test('drillToWards keeps the project and clears the ward', () {
      final q = root
          .drillToZones('MDU')
          .withWard(wardId: 75, wardCode: 'MDU-Z1-W03')
          .drillToWards(zoneId: 12, zoneCode: 'MDU-Zone2');
      expect(q.project, 'MDU');
      expect(q.zoneId, 12);
      expect(q.zoneCode, 'MDU-Zone2');
      expect(q.wardId, isNull);
    });

    test('drilling deeper carries the filters unchanged', () {
      const filters =
          VehicleFilters(vehicleStatus: 'Idle', vehicleOwner: 'GOVT');
      final q = const VehicleQuery(filters: filters)
          .drillToZones('MDU')
          .drillToWards(zoneId: 7, zoneCode: 'MDU-Zone1')
          .withType('LCV');
      expect(q.filters, filters);
    });

    test('scope reports the deepest location set', () {
      expect(root.scope, VehicleLevel.project);
      expect(root.drillToZones('MDU').scope, VehicleLevel.project);
      expect(root.drillToWards(zoneId: 7, zoneCode: 'Z').scope,
          VehicleLevel.zone);
      expect(
        root
            .drillToWards(zoneId: 7, zoneCode: 'Z')
            .withWard(wardId: 75, wardCode: 'W')
            .scope,
        VehicleLevel.ward,
      );
    });

    test('hasType is false for the All sentinel', () {
      expect(root.hasType, isFalse);
      expect(root.withType('All').hasType, isFalse);
      expect(root.withType('EMV').hasType, isTrue);
    });

    test('equality is by value, so an unchanged filter edit is detectable', () {
      expect(root.drillToZones('MDU'), root.drillToZones('MDU'));
      expect(root.drillToZones('MDU') == root.drillToZones('TBM'), isFalse);
    });
  });

  // ── The six documented tap interactions ──────────────────────────────────────

  group('Screen 1 — Vehicles by Project', () {
    test('initial load sends the filters only', () {
      expect(
        render(
          VehicleEndpoints.dashByProject,
          root.aggregateParams(
              chain: VehicleChain.location, level: VehicleLevel.project),
        ),
        '/drf_vehicle_dash_by_project/'
        '?vehicle_status=All&vehicle_owner=All',
      );
    });

    test('tapping the MDU header requests that project\'s zones', () {
      final q = root.drillToZones('MDU');
      expect(
        render(
          VehicleEndpoints.dashByZone,
          q.aggregateParams(
              chain: VehicleChain.location, level: VehicleLevel.zone),
        ),
        '/drf_vehicle_dash_by_zone/'
        '?project=MDU&vehicle_status=All&vehicle_owner=All',
      );
    });

    test('tapping the EMV row goes straight to the vehicle list', () {
      final q = root.drillToZones('MDU').withType('EMV');
      expect(
        render(VehicleEndpoints.queriedVehicles, q.vehicleListParams()),
        '/drf_list_queried_vehicles/'
        '?project=MDU&vehicle_type=EMV'
        '&vehicle_status=All&vehicle_owner=All',
      );
    });
  });

  group('Screen 2 — Vehicles by Zone', () {
    final zone = root.drillToZones('MDU').copyWith(
          zoneId: 7,
          zoneCode: 'MDU-Zone1',
        );

    test('tapping the zone header carries zone_id AND project', () {
      // Both are required: the ward endpoint is documented as
      // ?zone_id={zone_id}&project={project}.
      expect(
        render(
          VehicleEndpoints.dashByWard,
          zone.aggregateParams(
              chain: VehicleChain.location, level: VehicleLevel.ward),
        ),
        '/drf_vehicle_dash_by_ward/'
        '?zone_id=7&project=MDU&vehicle_status=All&vehicle_owner=All',
      );
    });

    test('tapping the EMV row uses the tapped zone\'s id, not a stale one', () {
      final q = zone.withType('EMV');
      expect(
        render(VehicleEndpoints.queriedVehicles, q.vehicleListParams()),
        '/drf_list_queried_vehicles/'
        '?zone_id=7&project=MDU&vehicle_type=EMV'
        '&vehicle_status=All&vehicle_owner=All',
      );
      // The specification showed zone_id=7 on the header link and zone_id=12 on
      // the type link of the same zone; both must be the tapped zone.
      final other = zone.copyWith(zoneId: 12, zoneCode: 'MDU-Zone2');
      expect(other.vehicleListParams()['zone_id'], '12');
      expect(
        other.aggregateParams(
            chain: VehicleChain.location, level: VehicleLevel.ward)['zone_id'],
        '12',
      );
    });
  });

  group('Screen 3 — Vehicles by Ward', () {
    final ward = root
        .drillToZones('MDU')
        .copyWith(zoneId: 7, zoneCode: 'MDU-Zone1')
        .withWard(wardId: 75, wardCode: 'MDU-Z1-W03');

    test('tapping the ward header lists every type in that ward', () {
      expect(
        render(VehicleEndpoints.queriedVehicles, ward.vehicleListParams()),
        '/drf_list_queried_vehicles/'
        '?ward_id=75&zone_id=7&project=MDU&vehicle_type=All'
        '&vehicle_status=All&vehicle_owner=All',
      );
    });

    test('tapping the LCV row narrows to that type', () {
      expect(
        render(VehicleEndpoints.queriedVehicles,
            ward.withType('LCV').vehicleListParams()),
        '/drf_list_queried_vehicles/'
        '?ward_id=75&zone_id=7&project=MDU&vehicle_type=LCV'
        '&vehicle_status=All&vehicle_owner=All',
      );
    });
  });

  group('Filter propagation', () {
    test('active filters ride along on every level', () {
      final q = const VehicleQuery(
        filters:
            VehicleFilters(vehicleStatus: 'Long Shift', vehicleOwner: 'RENT'),
      ).drillToZones('MDU').copyWith(zoneId: 7);

      final wardParams = q.aggregateParams(
          chain: VehicleChain.location, level: VehicleLevel.ward);
      expect(wardParams['vehicle_status'], 'Long Shift');
      expect(wardParams['vehicle_owner'], 'RENT');

      final listParams = q.withType('LCV').vehicleListParams();
      expect(listParams['vehicle_status'], 'Long Shift');
      expect(listParams['vehicle_owner'], 'RENT');
    });

    test('the status chain pins vehicle_type and omits vehicle_status', () {
      // Status *is* Chain B's axis, so filtering by it server-side would empty
      // every other bucket.
      final params = const VehicleQuery(
        filters: VehicleFilters(vehicleStatus: 'Working', vehicleOwner: 'OL'),
      ).drillToZones('MDU').aggregateParams(
            chain: VehicleChain.status,
            level: VehicleLevel.zone,
          );
      expect(params['vehicle_type'], 'All');
      expect(params['vehicle_owner'], 'OL');
      expect(params.containsKey('vehicle_status'), isFalse);
    });

    test('statusOverride replaces the carried status at the leaf', () {
      final params = const VehicleQuery(
        filters: VehicleFilters(vehicleStatus: 'All'),
      )
          .drillToZones('MDU')
          .vehicleListParams(statusOverride: 'Under Maintenance');
      expect(params['vehicle_status'], 'Under Maintenance');
    });
  });

  group('describeScope', () {
    test('names the full path and the selected type', () {
      final q = root
          .drillToZones('MDU')
          .copyWith(zoneId: 7, zoneCode: 'MDU-Zone1')
          .withWard(wardId: 75, wardCode: 'MDU-Z1-W03')
          .withType('LCV');
      expect(q.describeScope, 'MDU › MDU-Zone1 › MDU-Z1-W03 · LCV');
    });

    test('falls back to ids when a code is missing, and says All types', () {
      final q = root.drillToZones('MDU').copyWith(zoneId: 7);
      expect(q.describeScope, 'MDU › Zone 7 · All types');
    });

    test('handles an entirely unscoped query', () {
      expect(root.describeScope, 'All locations · All types');
    });
  });
}
