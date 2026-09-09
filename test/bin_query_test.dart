// Unit tests for the Bins query object, URL builder and aggregate DTO.
//
// These pin down each documented tap interaction, the unassigned-zone handling
// (omit the id rather than send one), and the nested `{type: {bucket: n}}`
// count shape.

import 'package:flutter_test/flutter_test.dart';

import 'package:ourlandnew/models/bin_record.dart';
import 'package:ourlandnew/pages/bins/bin_models.dart';
import 'package:ourlandnew/pages/bins/bin_query.dart';
import 'package:ourlandnew/services/dash_api.dart';

const String _host = 'https://ourlander.in';

String render(String path, Map<String, String> params) {
  final uri = buildApiUri(_host, path, params);
  return '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
}

void main() {
  group('encodeBinFilter', () {
    test('sends "All" literally while kOmitBinAllValues is false', () {
      expect(kOmitBinAllValues, isFalse);
      expect(encodeBinFilter('All'), 'All');
    });

    test('drops null and blank values', () {
      expect(encodeBinFilter(null), isNull);
      expect(encodeBinFilter(''), isNull);
      expect(encodeBinFilter('   '), isNull);
    });
  });

  group('Screen 1 — Bins by Project', () {
    test('initial load sends no location params', () {
      const q = BinQuery();
      expect(
        render(BinEndpoints.dashByProject, q.aggregateParams(BinLevel.project)),
        '/bins/drf_bin_dash_by_project/',
      );
    });

    test('tapping a project header requests that project\'s zones', () {
      final q = const BinQuery().drillToZones('MDU');
      expect(
        render(BinEndpoints.dashByZone, q.aggregateParams(BinLevel.zone)),
        '/bins/drf_bin_dash_by_zone/?project=MDU',
      );
    });

    test('tapping a bin-type row goes straight to the bin list', () {
      final q = const BinQuery().drillToZones('MDU').withType('Dumper');
      expect(
        render(BinEndpoints.listQueriedBins, q.binListParams()),
        '/bins/drf_list_queried_bins/'
        '?project=MDU&bin_type=Dumper&bin_status=All&bin_owner=All',
      );
    });
  });

  group('Screen 2 — Bins by Zone', () {
    final zone = const BinQuery()
        .drillToZones('MDU')
        .drillToWards(zoneId: 11, zoneCode: 'MDU-Z5');

    test('the ward dashboard carries project and zone_id', () {
      expect(
        render(BinEndpoints.dashByWard, zone.aggregateParams(BinLevel.ward)),
        '/bins/drf_bin_dash_by_ward/?project=MDU&zone_id=11',
      );
    });

    test('an unassigned zone omits zone_id entirely', () {
      // The endpoint documents omission as the way to get bins with no zone, so
      // the parameter must be absent rather than sent as an empty value.
      final unassigned = const BinQuery()
          .drillToZones('MDU')
          .drillToWards(zoneId: null, zoneCode: 'Unassigned');
      final params = unassigned.aggregateParams(BinLevel.ward);
      expect(params.containsKey('zone_id'), isFalse);
      expect(params['project'], 'MDU');
      expect(unassigned.zoneIsUnassigned, isTrue);
    });

    test('tapping a bin-type row uses the tapped zone id', () {
      final q = const BinQuery()
          .drillToZones('MDU')
          .withZone(zoneId: 11, zoneCode: 'MDU-Z5')
          .withType('Compactor');
      expect(
        render(BinEndpoints.listQueriedBins, q.binListParams()),
        '/bins/drf_list_queried_bins/'
        '?project=MDU&zone_id=11&bin_type=Compactor'
        '&bin_status=All&bin_owner=All',
      );
    });
  });

  group('Screen 3 — Bins by Ward', () {
    final ward = const BinQuery()
        .drillToZones('MDU')
        .drillToWards(zoneId: 11, zoneCode: 'MDU-Z5')
        .withWard(wardId: 84, wardCode: 'MDU-Z5-W84');

    test('a ward header lists every bin type in that ward', () {
      expect(
        render(BinEndpoints.listQueriedBins, ward.binListParams()),
        '/bins/drf_list_queried_bins/'
        '?project=MDU&zone_id=11&ward_id=84&bin_type=All'
        '&bin_status=All&bin_owner=All',
      );
    });

    test('a bin-type row narrows to that type', () {
      expect(
        ward.withType('Dumper').binListParams()['bin_type'],
        'Dumper',
      );
    });
  });

  group('BinQuery — accumulation', () {
    test('drillToZones clears any deeper scope', () {
      final q = const BinQuery()
          .drillToZones('MDU')
          .drillToWards(zoneId: 11, zoneCode: 'Z')
          .withWard(wardId: 84, wardCode: 'W')
          .drillToZones('TBM');
      expect(q.project, 'TBM');
      expect(q.zoneId, isNull);
      expect(q.wardId, isNull);
    });

    test('drillToWards keeps the project and clears the ward', () {
      final q = const BinQuery()
          .drillToZones('MDU')
          .withWard(wardId: 84, wardCode: 'W')
          .drillToWards(zoneId: 12, zoneCode: 'MDU-Z6');
      expect(q.project, 'MDU');
      expect(q.zoneId, 12);
      expect(q.wardId, isNull);
    });

    test('filters ride along on every drill', () {
      const filters = BinFilters(binType: 'Dumper', binStatus: 'Active');
      final q = const BinQuery(filters: filters)
          .drillToZones('MDU')
          .drillToWards(zoneId: 11, zoneCode: 'Z');
      expect(q.filters, filters);
      expect(q.binListParams()['bin_status'], 'Active');
    });

    test('the dashboards never send a bin_type filter', () {
      // They group *by* bin type; filtering server-side would hollow out every
      // other row.
      final q = const BinQuery(filters: BinFilters(binType: 'Dumper'))
          .drillToZones('MDU');
      expect(q.aggregateParams(BinLevel.zone).containsKey('bin_type'), isFalse);
    });

    test('equality is by value', () {
      expect(const BinQuery().drillToZones('MDU'),
          const BinQuery().drillToZones('MDU'));
      expect(
        const BinQuery().drillToZones('MDU') ==
            const BinQuery().drillToZones('TBM'),
        isFalse,
      );
    });

    test('describeScope names the path and type', () {
      final q = const BinQuery()
          .drillToZones('MDU')
          .drillToWards(zoneId: 11, zoneCode: 'MDU-Z5')
          .withWard(wardId: 84, wardCode: 'MDU-Z5-W84')
          .withType('Dumper');
      expect(q.describeScope, 'MDU › MDU-Z5 › MDU-Z5-W84 · Dumper');
      expect(
        const BinQuery().drillToZones('MDU').describeScope,
        'MDU · All bin types',
      );
    });
  });

  group('BinGroupRow', () {
    test('parses the nested {type: {bucket: count}} shape', () {
      final row = BinGroupRow.fromJson(
        {
          'project': 'MDU',
          'Compactor': {'12hr': 789},
          'Dumper': {'12hr': 64},
        },
        labelKey: 'project',
      );
      expect(row.label, 'MDU');
      expect(row.id, isNull);
      expect(row.count('Compactor'), 789);
      expect(row.count('Dumper'), 64);
      expect(row.total, 853);
      expect(row.captionFor('Compactor'), '12hr 789');
    });

    test('sums multiple buckets and lists them in the caption', () {
      final row = BinGroupRow.fromJson(
        {
          'zone': 'MDU-Z5',
          'zone_id': 11,
          'Compactor': {'12hr': 10, '24hr': 5},
        },
        labelKey: 'zone',
        idKey: 'zone_id',
      );
      expect(row.count('Compactor'), 15);
      expect(row.captionFor('Compactor'), '12hr 10 · 24hr 5');
      expect(row.id, 11);
      expect(row.isUnassigned, isFalse);
    });

    test('a missing type reads back as 0 rather than throwing', () {
      final row = BinGroupRow.fromJson(
        {'project': 'MDU', 'Dumper': {'12hr': 1}},
        labelKey: 'project',
      );
      expect(row.count('Compactor'), 0);
      expect(row.captionFor('Compactor'), isNull);
    });

    test('tolerates a flat count instead of a nested map', () {
      final row = BinGroupRow.fromJson(
        {'project': 'MDU', 'Compactor': 7},
        labelKey: 'project',
      );
      expect(row.count('Compactor'), 7);
      // A single unnamed bucket has nothing useful to caption.
      expect(row.captionFor('Compactor'), isNull);
    });

    test('treats a null or zero id as the unassigned bucket', () {
      final nullId = BinGroupRow.fromJson(
        {'zone': null, 'zone_id': null, 'Dumper': {'12hr': 3}},
        labelKey: 'zone',
        idKey: 'zone_id',
      );
      expect(nullId.isUnassigned, isTrue);
      expect(nullId.id, isNull);
      expect(nullId.label, 'Unassigned');

      final zeroId = BinGroupRow.fromJson(
        {'zone': 'No zone', 'zone_id': 0, 'Dumper': {'12hr': 3}},
        labelKey: 'zone',
        idKey: 'zone_id',
      );
      expect(zeroId.isUnassigned, isTrue);
      expect(zeroId.id, isNull);
      expect(zeroId.label, 'No zone');
    });

    test('never mistakes a meta key for a bin type', () {
      final row = BinGroupRow.fromJson(
        {'zone': 'MDU-Z5', 'zone_id': 11, 'total': 99, 'Dumper': {'12hr': 3}},
        labelKey: 'zone',
        idKey: 'zone_id',
      );
      expect(row.countsByType.keys, ['Dumper']);
      expect(row.total, 3);
    });

    test('survives an empty payload', () {
      final row = BinGroupRow.fromJson(const {}, labelKey: 'project');
      expect(row.label, '—');
      expect(row.total, 0);
      expect(row.countsByType, isEmpty);
    });

    test('unionBinTypes orders canonically then alphabetically', () {
      final rows = [
        BinGroupRow.fromJson(
            {'project': 'A', 'Zebra': 1, 'Dumper': 2}, labelKey: 'project'),
        BinGroupRow.fromJson({'project': 'B', 'Compactor': 3},
            labelKey: 'project'),
      ];
      expect(unionBinTypes(rows, kBinTypes),
          ['Compactor', 'Dumper', 'Zebra']);
    });
  });

  group('BinRecord', () {
    test('parses the documented payload', () {
      final r = BinRecord.fromJson({
        'id': 10,
        'lock_card': true,
        'bin_id': 789,
        'bin_number': 'Chinnakamm - CB 1',
        'bin_type': 'Dumper',
        'zone': 'MDU-Z5',
        'ward': 'MDU-Z5-W84',
        'collected_vehicle_number': 'TN59BA6563',
        'device_id': 'BP2A.250605.031.A3_V000L1',
        'before': 'https://example.com/b.jpg',
        'after': 'https://example.com/a.jpg',
        'collected_on': '2026-09-08 14:54:15',
        'left_on': '2026-09-08 14:54:23',
        'latitude': '13.048070',
        'longitude': '80.240141',
        'bin': 789,
        'collected_vehicle': 1012,
        'collected_by': 581,
      });
      expect(r.id, 10);
      expect(r.lockCard, isTrue);
      expect(r.binId, 789);
      expect(r.binType, 'Dumper');
      expect(r.before, 'https://example.com/b.jpg');
      expect(r.coordinates, '13.048070, 80.240141');
      expect(r.hasLocation, isTrue);
      expect(r.isCollected, isTrue);
    });

    test('rejects non-http image URLs so the placeholder shows instead', () {
      final r = BinRecord.fromJson({
        'id': 1,
        'before': '',
        'after': '/media/relative/path.jpg',
      });
      expect(r.before, isNull);
      expect(r.after, isNull);
      expect(r.hasAnyImage, isFalse);
    });

    test('survives an empty payload', () {
      final r = BinRecord.fromJson(const {});
      expect(r.id, 0);
      expect(r.binNumber, '—');
      expect(r.binType, '—');
      expect(r.lockCard, isFalse);
      expect(r.hasLocation, isFalse);
      expect(r.coordinates, isNull);
      expect(r.isCollected, isFalse);
    });

    test('coerces a numeric lock_card and string ids', () {
      final r = BinRecord.fromJson({'id': '42', 'lock_card': 1});
      expect(r.id, 42);
      expect(r.lockCard, isTrue);
    });

    test('leaves an unparseable coordinate pair as no location', () {
      final r = BinRecord.fromJson(
          {'id': 1, 'latitude': 'N/A', 'longitude': '80.24'});
      expect(r.hasLocation, isFalse);
      expect(r.coordinates, isNull);
    });
  });
}
