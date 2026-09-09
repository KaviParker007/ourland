// Unit tests for the Collections date range, query object and aggregate DTO.
//
// The two things most easily got wrong are pinned here:
//   • the 7-day range cap, validated before any request is made
//   • drf_bincollection_by_ward filters on zone_id ALONE and takes no project

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:ourlandnew/pages/collections/collection_models.dart';
import 'package:ourlandnew/pages/collections/collection_query.dart';
import 'package:ourlandnew/services/dash_api.dart';

const String _host = 'https://ourlander.in';

String render(String path, Map<String, String> params) {
  final uri = buildApiUri(_host, path, params);
  return '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
}

/// A fixed range so the expectations do not shift with the clock.
CollectionDateRange fixed(String start, String end) =>
    CollectionDateRange(DateTime.parse(start), DateTime.parse(end));

void main() {
  group('CollectionDateRange — defaults', () {
    test('both ends default to today', () {
      final r = CollectionDateRange.today();
      final today = CollectionDateRange.dayOf(DateTime.now());
      expect(r.start, today);
      expect(r.end, today);
      expect(r.isSingleDay, isTrue);
      expect(r.isToday, isTrue);
      expect(r.lengthInDays, 1);
      expect(r.isValid, isTrue);
      expect(r.label, 'Today');
    });

    test('strips the time component so day maths is exact', () {
      final r = CollectionDateRange(
        DateTime.parse('2026-09-08 23:59:59'),
        DateTime.parse('2026-09-08 00:00:01'),
      );
      expect(r.start, DateTime(2026, 9, 8));
      expect(r.end, DateTime(2026, 9, 8));
      expect(r.lengthInDays, 1);
    });
  });

  group('CollectionDateRange — the 7-day rule', () {
    test('a 7-day span is valid, an 8-day span is not', () {
      final seven = fixed('2026-09-02', '2026-09-08');
      expect(seven.lengthInDays, 7);
      expect(seven.isValid, isTrue);
      expect(seven.error, isNull);

      final eight = fixed('2026-09-01', '2026-09-08');
      expect(eight.lengthInDays, 8);
      expect(eight.isValid, isFalse);
      expect(eight.error, contains('7 days or fewer'));
      expect(eight.error, contains('currently 8'));
    });

    test('an inverted range is rejected with its own message', () {
      final bad = fixed('2026-09-08', '2026-09-01');
      expect(bad.isValid, isFalse);
      expect(bad.error, 'The end date cannot be before the start date.');
    });

    test('withStart pulls the end along rather than producing 8 days', () {
      final r = fixed('2026-09-08', '2026-09-08').withStart(
        DateTime.parse('2026-09-01'),
      );
      expect(r.startParam, '2026-09-01');
      // Capped at start + 6, not left at 09-08 which would be 8 days.
      expect(r.endParam, '2026-09-07');
      expect(r.lengthInDays, 7);
      expect(r.isValid, isTrue);
    });

    test('withStart after the end drags the end forward', () {
      final r = fixed('2026-09-01', '2026-09-03')
          .withStart(DateTime.parse('2026-09-10'));
      expect(r.startParam, '2026-09-10');
      expect(r.endParam, '2026-09-10');
      expect(r.isValid, isTrue);
    });

    test('withEnd pulls the start along rather than producing 8 days', () {
      final r = fixed('2026-09-01', '2026-09-01')
          .withEnd(DateTime.parse('2026-09-10'));
      expect(r.endParam, '2026-09-10');
      expect(r.startParam, '2026-09-04');
      expect(r.lengthInDays, 7);
      expect(r.isValid, isTrue);
    });

    test('withEnd before the start drags the start back', () {
      final r = fixed('2026-09-08', '2026-09-08')
          .withEnd(DateTime.parse('2026-09-05'));
      expect(r.startParam, '2026-09-05');
      expect(r.endParam, '2026-09-05');
      expect(r.isValid, isTrue);
    });

    test('maxEndForStart is the inclusive 7th day', () {
      expect(fixed('2026-09-02', '2026-09-02').maxEndForStart,
          DateTime(2026, 9, 8));
    });

    test('every reachable adjustment stays valid', () {
      // Whatever the picker hands back, the produced range must be sendable.
      final seeds = [
        fixed('2026-09-08', '2026-09-08'),
        fixed('2026-09-02', '2026-09-08'),
      ];
      final targets = [
        '2026-01-01',
        '2026-09-01',
        '2026-09-05',
        '2026-12-31',
      ];
      for (final seed in seeds) {
        for (final t in targets) {
          final d = DateTime.parse(t);
          expect(seed.withStart(d).isValid, isTrue,
              reason: 'withStart($t) on $seed');
          expect(seed.withEnd(d).isValid, isTrue,
              reason: 'withEnd($t) on $seed');
        }
      }
    });
  });

  group('CollectionDateRange — labels', () {
    test('a single non-today day shows the full date', () {
      // Deliberately offset from now(), since a range equal to today renders as
      // "Today" instead — covered by the defaults group.
      final other = CollectionDateRange.dayOf(
          DateTime.now().add(const Duration(days: 3)));
      final r = CollectionDateRange(other, other);
      expect(r.isToday, isFalse);
      expect(r.label, DateFormat('dd MMM yyyy').format(other));
    });

    test('a same-year span abbreviates the left side', () {
      expect(fixed('2026-09-02', '2026-09-08').label, '02 Sep – 08 Sep 2026');
    });

    test('a cross-year span spells both sides out', () {
      expect(fixed('2025-12-30', '2026-01-02').label,
          '30 Dec 2025 – 02 Jan 2026');
    });
  });

  // ── The documented tap interactions ──────────────────────────────────────────

  group('Screen 1 — Collections by Project', () {
    final range = fixed('2026-09-02', '2026-09-08');

    test('initial load sends only the dates', () {
      final q = CollectionQuery(range: range);
      expect(
        render(CollectionEndpoints.byProject,
            q.aggregateParams(CollectionLevel.project)),
        '/bins/drf_bincollection_by_project/'
        '?start_date=2026-09-02&end_date=2026-09-08',
      );
    });

    test('tapping a project header requests that project\'s zones', () {
      final q = CollectionQuery(range: range).drillToZones('MDU');
      expect(
        render(CollectionEndpoints.byZone,
            q.aggregateParams(CollectionLevel.zone)),
        '/bins/drf_bincollection_by_zone/'
        '?project=MDU&start_date=2026-09-02&end_date=2026-09-08',
      );
    });

    test('tapping a bin-type row goes straight to the collection list', () {
      final q = CollectionQuery(range: range)
          .drillToZones('MDU')
          .withType('Compactor');
      expect(
        render(CollectionEndpoints.listQueried, q.collectionListParams()),
        '/bins/drf_list_queried_bin_collection/'
        '?project=MDU&bin_type=Compactor'
        '&start_date=2026-09-02&end_date=2026-09-08',
      );
    });
  });

  group('Screen 2 — Collections by Zone', () {
    final range = fixed('2026-09-08', '2026-09-08');

    test('the ward dashboard sends zone_id and NO project', () {
      // drf_bincollection_by_ward filters by zone_id only. Sending project would
      // not match the documented contract.
      final q = CollectionQuery(range: range)
          .drillToZones('MDU')
          .drillToWards(zoneId: 11, zoneCode: 'MDU-Z5');
      final params = q.aggregateParams(CollectionLevel.ward);
      expect(params.containsKey('project'), isFalse);
      expect(params['zone_id'], '11');
      expect(
        render(CollectionEndpoints.byWard, params),
        '/bins/drf_bincollection_by_ward/'
        '?zone_id=11&start_date=2026-09-08&end_date=2026-09-08',
      );
    });

    test('an unassigned zone omits zone_id too', () {
      final q = CollectionQuery(range: range)
          .drillToZones('MDU')
          .drillToWards(zoneId: null, zoneCode: 'Unassigned');
      final params = q.aggregateParams(CollectionLevel.ward);
      expect(params.containsKey('zone_id'), isFalse);
      expect(params.containsKey('project'), isFalse);
      expect(q.zoneIsUnassigned, isTrue);
    });

    test('the zone dashboard does send project', () {
      final q = CollectionQuery(range: range).drillToZones('MDU');
      expect(q.aggregateParams(CollectionLevel.zone)['project'], 'MDU');
    });

    test('the list endpoint still sends the full scope including project', () {
      final q = CollectionQuery(range: range)
          .drillToZones('MDU')
          .withZone(zoneId: 11, zoneCode: 'MDU-Z5');
      final params = q.collectionListParams();
      expect(params['project'], 'MDU');
      expect(params['zone_id'], '11');
    });
  });

  group('Screen 3 — Collections by Ward', () {
    final ward = CollectionQuery(range: fixed('2026-09-08', '2026-09-08'))
        .drillToZones('MDU')
        .drillToWards(zoneId: 11, zoneCode: 'MDU-Z5')
        .withWard(wardId: 84, wardCode: 'MDU-Z5-W84');

    test('a ward header lists every type in that ward', () {
      expect(
        render(CollectionEndpoints.listQueried, ward.collectionListParams()),
        '/bins/drf_list_queried_bin_collection/'
        '?project=MDU&zone_id=11&ward_id=84'
        '&start_date=2026-09-08&end_date=2026-09-08',
      );
    });

    test('a bin-type row narrows to that type', () {
      expect(ward.withType('Dumper').collectionListParams()['bin_type'],
          'Dumper');
    });

    test('bin_type is omitted entirely when All', () {
      // The list endpoint treats bin_type as optional, so All means "send
      // nothing" rather than a literal that could be misread as a real type.
      expect(ward.collectionListParams().containsKey('bin_type'), isFalse);
      expect(ward.hasType, isFalse);
    });
  });

  group('CollectionQuery — accumulation', () {
    test('the range rides along on every drill', () {
      final range = fixed('2026-09-02', '2026-09-08');
      final q = CollectionQuery(range: range)
          .drillToZones('MDU')
          .drillToWards(zoneId: 11, zoneCode: 'Z')
          .withWard(wardId: 84, wardCode: 'W')
          .withType('Dumper');
      expect(q.range, range);
      expect(q.collectionListParams()['start_date'], '2026-09-02');
    });

    test('drillToZones clears any deeper scope', () {
      final q = CollectionQuery(range: fixed('2026-09-08', '2026-09-08'))
          .drillToZones('MDU')
          .drillToWards(zoneId: 11, zoneCode: 'Z')
          .drillToZones('TBM');
      expect(q.project, 'TBM');
      expect(q.zoneId, isNull);
      expect(q.wardId, isNull);
    });

    test('the dashboards never send a bin_type filter', () {
      final q = CollectionQuery(range: fixed('2026-09-08', '2026-09-08'))
          .drillToZones('MDU')
          .withType('Dumper');
      expect(
        q.aggregateParams(CollectionLevel.zone).containsKey('bin_type'),
        isFalse,
      );
    });

    test('describeScope names path, type and range', () {
      final q = CollectionQuery(range: fixed('2026-09-02', '2026-09-08'))
          .drillToZones('MDU')
          .drillToWards(zoneId: 11, zoneCode: 'MDU-Z5')
          .withWard(wardId: 84, wardCode: 'MDU-Z5-W84')
          .withType('Dumper');
      expect(q.describeScope,
          'MDU › MDU-Z5 › MDU-Z5-W84 · Dumper · 02 Sep – 08 Sep 2026');
    });

    test('equality is by value, range included', () {
      final a = CollectionQuery(range: fixed('2026-09-01', '2026-09-02'));
      final b = CollectionQuery(range: fixed('2026-09-01', '2026-09-02'));
      final c = CollectionQuery(range: fixed('2026-09-01', '2026-09-03'));
      expect(a, b);
      expect(a == c, isFalse);
    });
  });

  group('CollectionGroupRow', () {
    test('parses the flat {type: count} shape', () {
      final row = CollectionGroupRow.fromJson(
        {'project': 'MDU', 'Compactor': 10, 'Dumper': 1},
        labelKey: 'project',
      );
      expect(row.label, 'MDU');
      expect(row.count('Compactor'), 10);
      expect(row.count('Dumper'), 1);
      expect(row.total, 11);
      expect(row.count('HookLoader'), 0);
    });

    test('the by-zone response has no zone_id, so the id stays null', () {
      final row = CollectionGroupRow.fromJson(
        {'zone': 'MDU-Z1', 'Compactor': 2},
        labelKey: 'zone',
        idKey: 'zone_id',
      );
      expect(row.label, 'MDU-Z1');
      expect(row.id, isNull);
      expect(row.count('Compactor'), 2);
    });

    test('reads zone_id when the response does include it', () {
      final row = CollectionGroupRow.fromJson(
        {'zone': 'MDU-Z5', 'zone_id': 11, 'Dumper': 4},
        labelKey: 'zone',
        idKey: 'zone_id',
      );
      expect(row.id, 11);
      expect(row.isUnassigned, isFalse);
    });

    test('the project level is never marked unassigned', () {
      final row = CollectionGroupRow.fromJson(
        {'project': 'MDU', 'Compactor': 1},
        labelKey: 'project',
      );
      expect(row.isUnassigned, isFalse);
      expect(row.id, isNull);
    });

    test('tolerates a nested bucket map', () {
      final row = CollectionGroupRow.fromJson(
        {
          'project': 'MDU',
          'Compactor': {'12hr': 6, '24hr': 4},
        },
        labelKey: 'project',
      );
      expect(row.count('Compactor'), 10);
    });

    test('never mistakes a meta key for a bin type', () {
      final row = CollectionGroupRow.fromJson(
        {'ward': 'MDU-Z5-W84', 'ward_id': 84, 'total': 99, 'Dumper': 3},
        labelKey: 'ward',
        idKey: 'ward_id',
      );
      expect(row.countsByType.keys, ['Dumper']);
      expect(row.total, 3);
    });

    test('survives an empty payload', () {
      final row =
          CollectionGroupRow.fromJson(const {}, labelKey: 'project');
      expect(row.label, '—');
      expect(row.total, 0);
    });

    test('unionCollectionTypes orders canonically then alphabetically', () {
      final rows = [
        CollectionGroupRow.fromJson({'project': 'A', 'Zebra': 1, 'Dumper': 2},
            labelKey: 'project'),
        CollectionGroupRow.fromJson({'project': 'B', 'Compactor': 3},
            labelKey: 'project'),
      ];
      expect(unionCollectionTypes(rows, kCollectionBinTypes),
          ['Compactor', 'Dumper', 'Zebra']);
    });
  });
}
