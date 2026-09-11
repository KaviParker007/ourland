// Unit tests for the Bins query object, URL builder and aggregate DTO.
//
// These pin down each documented tap interaction, the unassigned-zone handling
// (omit the id rather than send one), and the nested `{type: {bucket: n}}`
// count shape.

import 'package:flutter_test/flutter_test.dart';

import 'package:ourlandnew/models/bin_record.dart';
import 'package:ourlandnew/pages/bins/bin_models.dart';
import 'package:ourlandnew/pages/bins/bin_query.dart';
import 'package:ourlandnew/pages/bins/bin_status.dart';
import 'package:ourlandnew/services/dash_api.dart';

const String _host = 'https://ourlander.in';

String render(String path, Map<String, String> params) {
  final uri = buildApiUri(_host, path, params);
  return '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
}

void main() {
  group('encodeBinFilter', () {
    test('omits "All" so only chosen parameters are sent', () {
      // These are optional params that default to All server-side, and the
      // contract's worked example sends no bin_owner at all.
      expect(kOmitBinAllValues, isTrue);
      expect(encodeBinFilter('All'), isNull);
      expect(encodeBinFilter('all'), isNull);
      expect(encodeBinFilter('Dumper'), 'Dumper');
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
        '/bins/drf_list_queried_bins/?project=MDU&bin_type=Dumper',
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
        '/bins/drf_list_queried_bins/?project=MDU&zone_id=11&bin_type=Compactor',
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
        '/bins/drf_list_queried_bins/?project=MDU&zone_id=11&ward_id=84',
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
      expect(row.captionFor('Compactor'), '12 hr 789');
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
      expect(row.captionFor('Compactor'), '12 hr 10 · 24 hr 5');
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

  // ── The headline requirement ─────────────────────────────────────────────────

  group('Project → Bin Type → Bin Status → Bin List', () {
    test('MDU → Compactor → Collected in 12hr produces the exact URL', () {
      final q = const BinQuery()
          .drillToZones('MDU')
          .withType('Compactor')
          .withStatus('Collected in 12hr');

      final uri =
          buildApiUri(_host, BinEndpoints.listQueriedBins, q.binListParams());

      // Spaces percent-encoded as %20, and no parameter the user did not choose.
      expect(
        uri.toString(),
        '$_host/bins/drf_list_queried_bins/'
        '?project=MDU&bin_type=Compactor'
        '&bin_status=Collected%20in%2012hr',
      );
      // And it round-trips back to the canonical value the API expects.
      expect(uri.queryParameters['bin_status'], 'Collected in 12hr');
      expect(uri.queryParameters['bin_type'], 'Compactor');
      expect(uri.queryParameters['project'], 'MDU');
      expect(uri.queryParameters.containsKey('bin_owner'), isFalse);
    });

    test('every canonical status survives encoding and decoding', () {
      for (final status in kBinStatuses) {
        final q = const BinQuery().drillToZones('MDU').withStatus(status);
        final uri =
            buildApiUri(_host, BinEndpoints.listQueriedBins, q.binListParams());
        expect(uri.query.contains('+'), isFalse,
            reason: 'spaces must be %20, not + ($status)');
        expect(uri.queryParameters['bin_status'], status);
      }
    });

    test('the full drill carries zone and ward alongside type and status', () {
      final q = const BinQuery()
          .drillToZones('MDU')
          .drillToWards(zoneId: 11, zoneCode: 'MDU-Z5')
          .withWard(wardId: 84, wardCode: 'MDU-Z5-W84')
          .withType('Dumper')
          .withStatus('Yet to collect');

      final uri =
          buildApiUri(_host, BinEndpoints.listQueriedBins, q.binListParams());
      expect(uri.queryParameters, {
        'project': 'MDU',
        'zone_id': '11',
        'ward_id': '84',
        'bin_type': 'Dumper',
        'bin_status': 'Yet to collect',
      });
    });

    test('bin_owner is sent only once actually chosen', () {
      final without = const BinQuery().drillToZones('MDU');
      expect(without.binListParams().containsKey('bin_owner'), isFalse);

      final chosen = without
          .withFilters(without.filters.copyWith(binOwner: 'Corporation'));
      expect(chosen.binListParams()['bin_owner'], 'Corporation');
    });

    test('describeScope reports type and status', () {
      final q = const BinQuery()
          .drillToZones('MDU')
          .withType('Compactor')
          .withStatus('Collected in 12hr');
      expect(q.describeScope, 'MDU · Compactor · Collected in 12hr');
      expect(q.hasStatus, isTrue);
      expect(const BinQuery().hasStatus, isFalse);
    });
  });

  group('canonicalBinStatus', () {
    test('maps every documented bucket key', () {
      // The backend's short keys, exactly as the dashboards return them.
      expect(canonicalBinStatus('12hr'), 'Collected in 12hr');
      expect(canonicalBinStatus('24hr'), 'Collected in 24hr');
      expect(canonicalBinStatus('48hr'), 'Collected in 48hr');
      expect(canonicalBinStatus('ytc'), 'Yet to collect');
      expect(canonicalBinStatus('under_maintenance'), 'Under Maintenance');
    });

    test('every documented key resolves to a real bin_status value', () {
      // Guards against a typo in the mapping table producing a label the list
      // endpoint would reject.
      for (final key in const [
        '12hr',
        '24hr',
        '48hr',
        'ytc',
        'under_maintenance',
      ]) {
        expect(kBinStatuses, contains(canonicalBinStatus(key)), reason: key);
      }
    });

    test('ytc is never shown or sent raw', () {
      // It shares no substring with "Yet to collect", so only the exact table
      // can resolve it — this is the case that regressed.
      expect(canonicalBinStatus('ytc'), isNot('ytc'));
      expect(canonicalBinStatus('YTC'), 'Yet to collect');
    });

    test('tolerates spelling variants for the same bucket', () {
      // The sample payload only ever showed `12hr`, so the other four spellings
      // are unconfirmed; anything recognisable resolves.
      for (final k in ['24hr', '24_hr', '24 hr', 'Collected in 24hr', 'HR24']) {
        expect(canonicalBinStatus(k), 'Collected in 24hr', reason: k);
      }
      for (final k in ['yet_to_collect', 'Yet to collect', 'pending']) {
        expect(canonicalBinStatus(k), 'Yet to collect', reason: k);
      }
      for (final k in ['under_maintenance', 'Under Maintenance', 'maintenance']) {
        expect(canonicalBinStatus(k), 'Under Maintenance', reason: k);
      }
    });

    test('returns null for an unrecognised key rather than guessing', () {
      expect(canonicalBinStatus('sometimes'), isNull);
      expect(canonicalBinStatus(''), isNull);
      expect(canonicalBinStatus('   '), isNull);
    });

    test('orderBinStatuses keeps the documented order then extras', () {
      expect(
        orderBinStatuses(
            {'Under Maintenance', 'zzz', 'Collected in 12hr', 'aaa'}),
        ['Collected in 12hr', 'Under Maintenance', 'aaa', 'zzz'],
      );
    });
  });

  group('the documented dashboard payload', () {
    // Verbatim from the API.
    final row = BinGroupRow.fromJson(
      const {
        'project': 'MDU',
        'Compactor': {
          '12hr': 1,
          '48hr': 22,
          'ytc': 766,
          'under_maintenance': 4,
        },
        'Dumper': {'24hr': 1, '48hr': 4, 'ytc': 59},
      },
      labelKey: 'project',
    );

    test('Compactor maps onto the user-facing statuses', () {
      expect(row.statusCountsFor('Compactor'), {
        'Collected in 12hr': 1,
        'Collected in 48hr': 22,
        'Yet to collect': 766,
        'Under Maintenance': 4,
      });
    });

    test('Dumper maps onto the user-facing statuses', () {
      expect(row.statusCountsFor('Dumper'), {
        'Collected in 24hr': 1,
        'Collected in 48hr': 4,
        'Yet to collect': 59,
      });
    });

    test('no raw backend key survives into the display map', () {
      for (final type in const ['Compactor', 'Dumper']) {
        final keys = row.statusCountsFor(type).keys;
        expect(keys, isNot(contains('ytc')), reason: type);
        expect(keys, isNot(contains('under_maintenance')), reason: type);
        // Everything shown is a value the list endpoint accepts.
        for (final k in keys) {
          expect(kBinStatuses, contains(k), reason: '$type/$k');
        }
      }
    });

    test('totals still come straight from the API', () {
      expect(row.count('Compactor'), 1 + 22 + 766 + 4);
      expect(row.count('Dumper'), 1 + 4 + 59);
      expect(row.total, 793 + 64);
    });

    test('a status the API omitted is simply absent, not zero-filled here', () {
      // The status screen renders all five and shows 0 for the gaps; the model
      // itself reports only what came back.
      expect(row.statusCountsFor('Compactor').containsKey('Collected in 24hr'),
          isFalse);
      expect(row.statusCountsFor('Dumper').containsKey('Under Maintenance'),
          isFalse);
    });

    test('tapping a mapped status sends the backend value', () {
      // Yet to collect → bin_status=Yet to collect, not ytc.
      final q = const BinQuery()
          .drillToZones('MDU')
          .withType('Compactor')
          .withStatus('Yet to collect');
      final uri =
          buildApiUri(_host, BinEndpoints.listQueriedBins, q.binListParams());
      expect(uri.queryParameters['bin_status'], 'Yet to collect');
      expect(uri.toString(), contains('bin_status=Yet%20to%20collect'));

      final maintenance = q.withStatus('Under Maintenance');
      expect(maintenance.binListParams()['bin_status'], 'Under Maintenance');
    });
  });

  group('BinGroupRow status counts', () {
    final row = BinGroupRow.fromJson(
      {
        'project': 'MDU',
        'Compactor': {'12hr': 789, '24hr': 10, 'yet_to_collect': 4},
        'Dumper': {'12hr': 64, 'under_maintenance': 2},
      },
      labelKey: 'project',
    );

    test('re-keys buckets onto the canonical status values', () {
      expect(row.statusCountsFor('Compactor'), {
        'Collected in 12hr': 789,
        'Collected in 24hr': 10,
        'Yet to collect': 4,
      });
      expect(row.statusCountsFor('Dumper'), {
        'Collected in 12hr': 64,
        'Under Maintenance': 2,
      });
    });

    test('aggregates across types', () {
      expect(row.statusCountsAll, {
        'Collected in 12hr': 853,
        'Collected in 24hr': 10,
        'Yet to collect': 4,
        'Under Maintenance': 2,
      });
    });

    test('an unknown bucket is preserved under its raw key, not dropped', () {
      final odd = BinGroupRow.fromJson(
        {
          'project': 'MDU',
          'Compactor': {'12hr': 5, 'mystery': 3},
        },
        labelKey: 'project',
      );
      expect(odd.statusCountsFor('Compactor'),
          {'Collected in 12hr': 5, 'mystery': 3});
      // Still counted in the total, so no bins go missing.
      expect(odd.count('Compactor'), 8);
    });

    test('aggregateStatusCounts sums every group on the dashboard', () {
      final rows = [
        BinGroupRow.fromJson({
          'project': 'MDU',
          'Compactor': {'12hr': 10},
        }, labelKey: 'project'),
        BinGroupRow.fromJson({
          'project': 'TBM',
          'Dumper': {'12hr': 5, 'yet_to_collect': 2},
        }, labelKey: 'project'),
      ];
      expect(aggregateStatusCounts(rows),
          {'Collected in 12hr': 15, 'Yet to collect': 2});
    });

    test('an empty row yields empty status counts, not an error', () {
      final empty = BinGroupRow.fromJson(const {}, labelKey: 'project');
      expect(empty.statusCountsAll, isEmpty);
      expect(empty.statusCountsFor('Compactor'), isEmpty);
      expect(aggregateStatusCounts([empty]), isEmpty);
    });
  });
}
