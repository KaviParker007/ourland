// Widget tests for the Bins and Collections modules.
//
// Covers the shared drill-down section (nested bin-type captions, header vs row
// tap targets, inert zero rows), the shared record card (locked state, image
// placeholders, missing fields), and the collections date bar.
//
// Everything mounts a leaf widget directly — the services are singletons over
// top-level `http` calls and the project has no HTTP mocking package.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ourlandnew/components/bin_record_card.dart';
import 'package:ourlandnew/models/bin_record.dart';
import 'package:ourlandnew/pages/bins/bin_models.dart';
import 'package:ourlandnew/pages/bins/bin_query.dart';
import 'package:ourlandnew/pages/bins/bin_status_page.dart';
import 'package:ourlandnew/pages/bins/bin_status.dart';
import 'package:ourlandnew/pages/bins/bin_ui.dart';
import 'package:ourlandnew/pages/collections/collection_models.dart';
import 'package:ourlandnew/pages/collections/collection_query.dart';
import 'package:ourlandnew/pages/collections/collection_ui.dart';
import 'package:ourlandnew/theme/dark_mode.dart';

/// Mounts [child] in the real app theme, optionally at a larger text scale and a
/// chosen viewport width so responsive branches can be exercised.
Widget host(Widget child, {double textScale = 1.0, double width = 400}) {
  return MaterialApp(
    theme: darkMode,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

BinRecord record({
  int id = 10,
  bool locked = false,
  String number = 'Chinnakamm - CB 1',
  String type = 'Dumper',
  String? zone = 'MDU-Z5',
  String? ward = 'MDU-Z5-W84',
  String? vehicle = 'TN59BA6563',
  String? device = 'BP2A.250605.031.A3_V000L1',
  String? before = 'https://example.com/before.jpg',
  String? after = 'https://example.com/after.jpg',
  String? collectedOn = '2026-09-08 14:54:15',
  String? leftOn = '2026-09-08 14:54:23',
  String? lat = '13.048070',
  String? lng = '80.240141',
  int? collectedBy = 581,
}) {
  return BinRecord(
    id: id,
    lockCard: locked,
    binId: 789,
    binNumber: number,
    binType: type,
    zone: zone,
    ward: ward,
    collectedVehicleNumber: vehicle,
    deviceId: device,
    beforeImage: before,
    afterImage: after,
    collectedOn: collectedOn,
    leftOn: leftOn,
    latitude: lat,
    longitude: lng,
    collectedBy: collectedBy,
  );
}

void main() {
  group('BinDrillCard', () {
    testWidgets('renders title, count and chevron like a Vehicle Type card',
        (tester) async {
      await tester.pumpWidget(host(BinDrillCard(
        title: 'MDU',
        count: 853,
        accent: const Color(0xFF6A6CFF),
        onTap: () {},
      )));

      expect(find.text('MDU'), findsOneWidget);
      expect(find.text('853'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('tapping a populated card fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(BinDrillCard(
        title: 'MDU',
        count: 853,
        accent: const Color(0xFF6A6CFF),
        onTap: () => taps++,
      )));

      await tester.tap(find.text('MDU'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a zero count is inert and loses its chevron', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(BinDrillCard(
        title: 'Empty',
        count: 0,
        accent: const Color(0xFF6A6CFF),
        onTap: () => taps++,
      )));

      await tester.tap(find.text('Empty'));
      await tester.pump();
      expect(taps, 0);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      // The count is still shown — an empty bucket is information.
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('shows a subtitle and a leading dot when asked',
        (tester) async {
      await tester.pumpWidget(host(BinDrillCard(
        title: 'Unassigned',
        subtitle: 'No zone assigned',
        count: 3,
        accent: const Color(0xFF78909C),
        showDot: true,
        onTap: () {},
      )));

      expect(find.text('Unassigned'), findsOneWidget);
      expect(find.text('No zone assigned'), findsOneWidget);
    });

    testWidgets('meets the minimum tap target', (tester) async {
      await tester.pumpWidget(host(BinDrillCard(
        title: 'MDU',
        count: 1,
        accent: const Color(0xFF6A6CFF),
        onTap: () {},
      )));
      expect(tester.getSize(find.byType(BinDrillCard)).height,
          greaterThanOrEqualTo(kDashMinTapTarget));
    });
  });

  group('Bin status cards', () {
    testWidgets('each status keeps its own colour and icon', (tester) async {
      await tester.pumpWidget(host(Column(
        children: [
          for (final s in kBinStatuses)
            buildBinStatusCard(status: s, count: 5, onTap: () {}),
        ],
      )));

      // All five render, under their canonical names.
      for (final s in kBinStatuses) {
        expect(find.text(s), findsOneWidget);
      }
      // Each carries its own icon, so the status/icon pairing stays consistent
      // wherever a status appears. Derived from binStatusIcon rather than
      // hardcoded, so retuning an icon does not break this test.
      final icons = {for (final s in kBinStatuses) binStatusIcon(s)};
      expect(icons.length, kBinStatuses.length,
          reason: 'every status needs a distinct icon');
      for (final icon in icons) {
        expect(find.byIcon(icon), findsOneWidget);
      }
    });

    testWidgets('the card accent is the status colour', (tester) async {
      for (final s in kBinStatuses) {
        await tester.pumpWidget(
            host(buildBinStatusCard(status: s, count: 5, onTap: () {})));
        final card = tester.widget<BinDrillCard>(find.byType(BinDrillCard));
        expect(card.accent, binStatusColor(s), reason: s);
        expect(card.icon, binStatusIcon(s), reason: s);
      }
    });

    testWidgets('tapping reports the canonical status value', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(host(Column(
        children: [
          for (final s in kBinStatuses)
            buildBinStatusCard(status: s, count: 5, onTap: () => taps.add(s)),
        ],
      )));

      await tester.tap(find.text('Collected in 12hr'));
      await tester.tap(find.text('Yet to collect'));
      await tester.pump();
      expect(taps, ['Collected in 12hr', 'Yet to collect']);
    });

    testWidgets('the documented payload renders friendly labels, never raw keys',
        (tester) async {
      // The exact screen from the bug report: MDU › Compactor, whose payload
      // carries `ytc` and `under_maintenance`.
      final row = BinGroupRow.fromJson(
        const {
          'project': 'MDU',
          'Compactor': {
            '12hr': 1,
            '48hr': 22,
            'ytc': 766,
            'under_maintenance': 4,
          },
        },
        labelKey: 'project',
      );

      await tester.pumpWidget(MaterialApp(
        theme: darkMode,
        home: BinStatusPage(
          title: 'MDU',
          query: const BinQuery().drillToZones('MDU').withType('Compactor'),
          counts: row.statusCountsFor('Compactor'),
          crumbs: const [DashCrumb('Projects'), DashCrumb('MDU')],
        ),
      ));
      await tester.pumpAndSettle();

      // Friendly labels with the counts the API returned.
      expect(find.text('Collected in 12hr'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Collected in 48hr'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('Yet to collect'), findsOneWidget);
      expect(find.text('766'), findsOneWidget);
      expect(find.text('Under Maintenance'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      // No raw backend key anywhere on screen.
      expect(find.text('ytc'), findsNothing);
      expect(find.text('under_maintenance'), findsNothing);

      // The status the payload omitted still shows, as an inert zero.
      expect(find.text('Collected in 24hr'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('a status with no bins is inert', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(buildBinStatusCard(
        status: 'Under Maintenance',
        count: 0,
        onTap: () => taps++,
      )));
      await tester.tap(find.text('Under Maintenance'));
      await tester.pump();
      expect(taps, 0);
    });
  });

  group('Collections GroupSection', () {
    final row = CollectionGroupRow.fromJson(
      {'project': 'MDU', 'Compactor': 10, 'Dumper': 1},
      labelKey: 'project',
    );

    testWidgets('renders flat counts with no caption', (tester) async {
      await tester.pumpWidget(host(Builder(
        builder: (context) => buildCollectionSection(
          context: context,
          row: row,
          typeColumns: const ['Compactor', 'Dumper'],
          onHeaderTap: () {},
          onTypeTap: (_) {},
        ),
      )));

      expect(find.text('MDU'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget); // total
      expect(find.textContaining('12hr'), findsNothing);
    });

    testWidgets('type row reports the tapped type', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(host(Builder(
        builder: (context) => buildCollectionSection(
          context: context,
          row: row,
          typeColumns: const ['Compactor', 'Dumper'],
          onHeaderTap: () {},
          onTypeTap: taps.add,
        ),
      )));
      await tester.tap(find.text('Dumper'));
      await tester.pump();
      expect(taps, ['Dumper']);
    });
  });

  group('BinRecordCard', () {
    testWidgets('shows every documented detail field', (tester) async {
      await tester.pumpWidget(host(BinRecordCard(record: record())));

      expect(find.text('Chinnakamm - CB 1'), findsOneWidget);
      expect(find.text('Bin #789'), findsOneWidget);
      expect(find.text('Dumper'), findsOneWidget);
      expect(find.text('MDU-Z5'), findsOneWidget);
      expect(find.text('MDU-Z5-W84'), findsOneWidget);
      expect(find.text('TN59BA6563'), findsOneWidget);
      expect(find.text('BP2A.250605.031.A3_V000L1'), findsOneWidget);
      expect(find.text('Employee #581'), findsOneWidget);
      expect(find.text('13.048070, 80.240141'), findsOneWidget);
      // Timestamps are humanised, not echoed raw.
      expect(find.text('08 Sep 2026, 2:54 PM'), findsNWidgets(2));
      expect(find.text('BEFORE'), findsOneWidget);
      expect(find.text('AFTER'), findsOneWidget);
    });

    testWidgets('an unlocked card carries no lock badge', (tester) async {
      await tester.pumpWidget(host(BinRecordCard(record: record())));
      expect(find.text('LOCKED'), findsNothing);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
    });

    testWidgets('a lock_card record is badged as locked', (tester) async {
      await tester
          .pumpWidget(host(BinRecordCard(record: record(locked: true))));
      expect(find.text('LOCKED'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('missing images fall back to a placeholder, not a break',
        (tester) async {
      await tester.pumpWidget(host(BinRecordCard(
        record: record(before: null, after: '/media/relative.jpg'),
      )));
      // Both tiles degrade: one null, one non-absolute URL.
      expect(find.text('No photo'), findsNWidgets(2));
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNWidgets(2));
    });

    testWidgets('an uncollected bin omits the detail block', (tester) async {
      await tester.pumpWidget(host(BinRecordCard(
        record: record(collectedOn: null, leftOn: null),
        showCollectionDetail: false,
      )));
      expect(find.text('Collected'), findsNothing);
      expect(find.text('Employee #581'), findsNothing);
      // Identity still renders.
      expect(find.text('Chinnakamm - CB 1'), findsOneWidget);
    });

    testWidgets('a missing timestamp shows a dash rather than blank',
        (tester) async {
      await tester.pumpWidget(host(BinRecordCard(
        record: record(collectedOn: '2026-09-08 14:54:15', leftOn: null),
      )));
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('a record with no coordinates hides the location row',
        (tester) async {
      await tester.pumpWidget(
          host(BinRecordCard(record: record(lat: null, lng: null))));
      expect(find.byIcon(Icons.place_outlined), findsNothing);
      expect(find.byIcon(Icons.copy_rounded), findsNothing);
    });

    testWidgets('survives a 2x text scale and a narrow viewport',
        (tester) async {
      await tester.pumpWidget(host(
        BinRecordCard(record: record()),
        textScale: 2.0,
        width: 320,
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out without overflow on a wide viewport',
        (tester) async {
      await tester
          .pumpWidget(host(BinRecordCard(record: record()), width: 880));
      expect(tester.takeException(), isNull);
    });

    testWidgets('exposes a merged semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester
          .pumpWidget(host(BinRecordCard(record: record(locked: true))));
      expect(
        find.bySemanticsLabel(RegExp(
            r'Chinnakamm - CB 1, Dumper, zone MDU-Z5, ward MDU-Z5-W84, '
            r'vehicle TN59BA6563, locked')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('formatRecordTimestamp', () {
    test('humanises the documented format', () {
      expect(formatRecordTimestamp('2026-09-08 14:54:15'),
          '08 Sep 2026, 2:54 PM');
    });

    test('falls back to the raw string when unparseable', () {
      expect(formatRecordTimestamp('not a date'), 'not a date');
    });

    test('renders a dash for null or blank', () {
      expect(formatRecordTimestamp(null), '—');
      expect(formatRecordTimestamp('   '), '—');
    });
  });

  group('CollectionDateBar', () {
    testWidgets('shows Today for the default range and hides the reset',
        (tester) async {
      await tester.pumpWidget(host(CollectionDateBar(
        range: CollectionDateRange.today(),
        onChanged: (_) {},
      )));

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('FROM'), findsOneWidget);
      expect(find.text('TO'), findsOneWidget);
      // "Today" appears as the summary only — no reset button to return to it.
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('shows the span, the day count and a reset for a range',
        (tester) async {
      final range = CollectionDateRange(
        DateTime.parse('2026-09-02'),
        DateTime.parse('2026-09-08'),
      );
      await tester.pumpWidget(host(CollectionDateBar(
        range: range,
        onChanged: (_) {},
      )));

      expect(find.text('02 Sep – 08 Sep 2026'), findsOneWidget);
      expect(find.text('7 of 7 days'), findsOneWidget);
      expect(find.text('2026-09-02'), findsOneWidget);
      expect(find.text('2026-09-08'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget); // the reset button
    });

    testWidgets('the reset button restores today', (tester) async {
      CollectionDateRange? emitted;
      await tester.pumpWidget(host(CollectionDateBar(
        range: CollectionDateRange(
          DateTime.parse('2026-09-02'),
          DateTime.parse('2026-09-08'),
        ),
        onChanged: (r) => emitted = r,
      )));

      await tester.tap(find.widgetWithText(TextButton, 'Today'));
      await tester.pump();
      expect(emitted, CollectionDateRange.today());
    });

    testWidgets('surfaces the validation message for an over-long range',
        (tester) async {
      await tester.pumpWidget(host(CollectionDateBar(
        range: CollectionDateRange(
          DateTime.parse('2026-09-01'),
          DateTime.parse('2026-09-10'),
        ),
        onChanged: (_) {},
      )));

      expect(find.textContaining('7 days or fewer'), findsOneWidget);
      expect(find.textContaining('currently 10'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      // The day-count hint is replaced by the error, not shown alongside it.
      expect(find.text('10 of 7 days'), findsNothing);
    });

    testWidgets('appends the bin-type summary when one is active',
        (tester) async {
      await tester.pumpWidget(host(CollectionDateBar(
        range: CollectionDateRange.today(),
        onChanged: (_) {},
        typeSummary: 'Dumper',
      )));
      expect(find.text('Today · Dumper'), findsOneWidget);
    });

    testWidgets('stacks on a phone and rows on a tablet without overflow',
        (tester) async {
      for (final w in [320.0, 400.0, 720.0, 900.0]) {
        await tester.pumpWidget(host(
          CollectionDateBar(
            range: CollectionDateRange(
              DateTime.parse('2026-09-02'),
              DateTime.parse('2026-09-08'),
            ),
            onChanged: (_) {},
          ),
          width: w,
        ));
        expect(tester.takeException(), isNull, reason: 'at width $w');
      }
    });
  });

  // The flutter_test font renders every glyph a full em wide, so these sweeps
  // are a deliberately pessimistic proxy for wide fonts and large text scales —
  // it is what caught the date-button overflow at 320 dp.
  // The flutter_test font renders every glyph a full em wide, so these sweeps
  // are a deliberately pessimistic proxy for wide fonts and large text scales —
  // it is what caught the date-button overflow at 320 dp.
  group('Responsive sweep — no overflow anywhere', () {
    const widths = [320.0, 360.0, 480.0, 600.0, 768.0, 900.0, 1200.0];
    const scales = [1.0, 1.5, 2.0];

    final colRow = CollectionGroupRow.fromJson(
      {'ward': 'MDU-Z5-W84', 'ward_id': 84, 'Compactor': 10, 'Dumper': 1},
      labelKey: 'ward',
      idKey: 'ward_id',
    );

    testWidgets('bin drill cards, every variant', (tester) async {
      final variants = <BinDrillCard>[
        BinDrillCard(
          title: 'MDU-Z5-VERYLONGZONECODE-THAT-KEEPS-GOING',
          count: 123456,
          accent: const Color(0xFF6A6CFF),
          onTap: () {},
        ),
        BinDrillCard(
          title: 'Unassigned',
          subtitle: 'No zone assigned',
          count: 7,
          accent: const Color(0xFF78909C),
          showDot: true,
          onTap: () {},
        ),
        buildBinStatusCard(
            status: 'Collected in 12hr', count: 98765, onTap: () {}),
        buildBinStatusCard(status: 'Under Maintenance', count: 0, onTap: () {}),
      ];

      for (final w in widths) {
        for (final s in scales) {
          for (final card in variants) {
            await tester.pumpWidget(host(card, width: w, textScale: s));
            expect(tester.takeException(), isNull,
                reason: 'width $w scale $s "${card.title}"');
          }
        }
      }
    });

    testWidgets('the chain toggle', (tester) async {
      for (final w in widths) {
        for (final s in scales) {
          await tester.pumpWidget(host(
            BinChainBar(chain: BinChain.type, onChanged: (_) {}),
            width: w,
            textScale: s,
          ));
          expect(tester.takeException(), isNull, reason: 'width $w scale $s');
        }
      }
    });

    testWidgets('collection section', (tester) async {
      for (final w in widths) {
        for (final s in scales) {
          await tester.pumpWidget(host(
            Builder(
              builder: (context) => buildCollectionSection(
                context: context,
                row: colRow,
                typeColumns: const ['Compactor', 'Dumper'],
                onHeaderTap: () {},
                onTypeTap: (_) {},
              ),
            ),
            width: w,
            textScale: s,
          ));
          expect(tester.takeException(), isNull, reason: 'width $w scale $s');
        }
      }
    });

    testWidgets('record card', (tester) async {
      for (final w in widths) {
        for (final s in scales) {
          await tester.pumpWidget(host(
            BinRecordCard(record: record()),
            width: w,
            textScale: s,
          ));
          expect(tester.takeException(), isNull, reason: 'width $w scale $s');
        }
      }
    });

    testWidgets('date bar, including an invalid range', (tester) async {
      final ranges = [
        CollectionDateRange.today(),
        CollectionDateRange(
            DateTime.parse('2026-09-02'), DateTime.parse('2026-09-08')),
        // Invalid, so the error banner is laid out too.
        CollectionDateRange(
            DateTime.parse('2026-09-01'), DateTime.parse('2026-09-20')),
      ];
      for (final w in widths) {
        for (final s in scales) {
          for (final r in ranges) {
            await tester.pumpWidget(host(
              CollectionDateBar(
                range: r,
                onChanged: (_) {},
                typeSummary: 'Compactor',
              ),
              width: w,
              textScale: s,
            ));
            expect(tester.takeException(), isNull,
                reason: 'width $w scale $s range $r');
          }
        }
      }
    });

    testWidgets('filter bar with every chip active', (tester) async {
      for (final w in widths) {
        for (final s in scales) {
          await tester.pumpWidget(host(
            BinFilterBar(
              filters: const BinFilters(
                  binType: 'Compactor',
                  binStatus: 'Collected in 12hr',
                  binOwner: 'Corporation'),
              onClear: (_) {},
              onEdit: () {},
            ),
            width: w,
            textScale: s,
          ));
          expect(tester.takeException(), isNull, reason: 'width $w scale $s');
        }
      }
    });
  });


  group('BinFilterBar', () {
    testWidgets('states the default selection when nothing is filtered',
        (tester) async {
      await tester.pumpWidget(host(BinFilterBar(
        filters: const BinFilters(),
        onClear: (_) {},
        onEdit: () {},
      )));
      expect(find.text('All bin types · All statuses'), findsOneWidget);
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('shows a deletable chip per non-default filter',
        (tester) async {
      BinFilters? cleared;
      await tester.pumpWidget(host(BinFilterBar(
        filters: const BinFilters(binType: 'Dumper', binStatus: 'Active'),
        onClear: (f) => cleared = f,
        onEdit: () {},
      )));

      expect(find.text('Type: Dumper'), findsOneWidget);
      expect(find.text('Status: Active'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.cancel).first);
      await tester.pump();
      // Clearing the type leaves the status filter untouched.
      expect(cleared?.binType, kBinAll);
      expect(cleared?.binStatus, 'Active');
    });
  });

  group('Bin filter sheet', () {
    testWidgets('offers only All plus the types the API returned',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: darkMode,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showBinFilterSheet(
                context,
                const BinFilters(),
                const ['Dumper', 'Compactor'],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();

      // Canonical ordering, and nothing the API did not return.
      expect(find.text('Compactor').hitTestable(), findsWidgets);
      expect(find.text('Dumper').hitTestable(), findsWidgets);
      expect(find.text('HookLoader'), findsNothing);
      expect(find.text('Others'), findsNothing);
    });

    testWidgets('applying returns the chosen type', (tester) async {
      BinFilters? applied;
      await tester.pumpWidget(MaterialApp(
        theme: darkMode,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                applied = await showBinFilterSheet(
                  context,
                  const BinFilters(),
                  const ['Dumper', 'Compactor'],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dumper').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(applied?.binType, 'Dumper');
    });

    testWidgets('Reset returns filters to All', (tester) async {
      BinFilters? applied;
      await tester.pumpWidget(MaterialApp(
        theme: darkMode,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                applied = await showBinFilterSheet(
                  context,
                  const BinFilters(
                      binType: 'Dumper', binStatus: 'Yet to collect'),
                  const ['Dumper'],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(applied?.binType, kBinAll);
      expect(applied?.binStatus, kBinAll);
      expect(applied?.hasActive, isFalse);
    });

    testWidgets('the status dropdown returns the canonical API value',
        (tester) async {
      BinFilters? applied;
      await tester.pumpWidget(MaterialApp(
        theme: darkMode,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                applied = await showBinFilterSheet(
                  context,
                  const BinFilters(),
                  const ['Compactor'],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Second dropdown is Bin Status.
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Collected in 24hr').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      // Exactly the value the API expects, not a display label.
      expect(applied?.binStatus, 'Collected in 24hr');
      expect(applied?.binType, kBinAll);
    });
  });

  group('Collection type sheet', () {
    testWidgets('applying returns the chosen type', (tester) async {
      String? picked;
      await tester.pumpWidget(MaterialApp(
        theme: darkMode,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await showCollectionTypeSheet(
                  context,
                  kCollectionAll,
                  const ['Compactor'],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compactor').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(picked, 'Compactor');
    });
  });
}
