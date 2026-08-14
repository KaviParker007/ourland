// Widget tests for the Vehicle Type drill-down module.
//
// Covers the section list (header vs row tap targets, inert zero rows), the
// locked vehicle card, and the empty / error states. Everything here mounts a
// leaf widget directly — no screen in this module is exercised end-to-end
// because VehicleDashboardApi is a singleton over top-level `http` calls and the
// project has no HTTP mocking package.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ourlandnew/pages/vehicle_type/queried_vehicles_page.dart';
import 'package:ourlandnew/pages/vehicle_type/vehicle_type_models.dart';
import 'package:ourlandnew/pages/vehicle_type/vehicle_type_ui.dart';
import 'package:ourlandnew/theme/dark_mode.dart';

/// Mounts [child] in the real app theme, optionally at a larger text scale.
Widget host(Widget child, {double textScale = 1.0}) {
  return MaterialApp(
    theme: darkMode,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

VehicleRecord record({
  int id = 1,
  String number = 'TN12AB1234',
  String type = 'LCV',
  String project = 'MDU',
  String? zoneCode = 'MDU-Z1',
  String status = 'working',
  String? reasoned,
}) {
  return VehicleRecord(
    id: id,
    vehicleNumber: number,
    vehicleType: type,
    project: project,
    zoneCode: zoneCode,
    vehicleStatus: status,
    isReasonedToday: reasoned,
  );
}

void main() {
  group('GroupSection', () {
    final row = VehiclePivotRow.fromJson(
      {'project': 'MDU', 'EMV': 16, 'LCV': 453, 'Tipper': 0},
      labelKey: 'project',
    );

    testWidgets('renders the group header and one row per vehicle type',
        (tester) async {
      await tester.pumpWidget(host(Builder(
        builder: (context) => buildPivotSection(
          context: context,
          row: row,
          typeColumns: const ['EMV', 'LCV', 'Tipper'],
          onHeaderTap: () {},
          onTypeTap: (_) {},
        ),
      )));

      expect(find.text('MDU'), findsOneWidget);
      expect(find.text('EMV'), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
      expect(find.text('LCV'), findsOneWidget);
      expect(find.text('453'), findsOneWidget);
      expect(find.text('Tipper'), findsOneWidget);
      // Group total badge: 16 + 453 + 0.
      expect(find.text('469'), findsOneWidget);
      expect(find.byType(TypeCountRow), findsNWidgets(3));
    });

    testWidgets('header tap and type-row tap are separate destinations',
        (tester) async {
      var headerTaps = 0;
      final typeTaps = <String>[];

      await tester.pumpWidget(host(Builder(
        builder: (context) => buildPivotSection(
          context: context,
          row: row,
          typeColumns: const ['EMV', 'LCV', 'Tipper'],
          onHeaderTap: () => headerTaps++,
          onTypeTap: typeTaps.add,
        ),
      )));

      await tester.tap(find.text('MDU'));
      await tester.pump();
      expect(headerTaps, 1);
      expect(typeTaps, isEmpty);

      await tester.tap(find.text('EMV'));
      await tester.pump();
      expect(typeTaps, ['EMV']);
      // Tapping a row must not also drill the header.
      expect(headerTaps, 1);
    });

    testWidgets('a zero-count row is inert', (tester) async {
      final typeTaps = <String>[];
      await tester.pumpWidget(host(Builder(
        builder: (context) => buildPivotSection(
          context: context,
          row: row,
          typeColumns: const ['EMV', 'LCV', 'Tipper'],
          onHeaderTap: () {},
          onTypeTap: typeTaps.add,
        ),
      )));

      await tester.tap(find.text('Tipper'));
      await tester.pump();
      expect(typeTaps, isEmpty);
    });

    testWidgets('every tap target is at least 48 dp tall', (tester) async {
      await tester.pumpWidget(host(Builder(
        builder: (context) => buildPivotSection(
          context: context,
          row: row,
          typeColumns: const ['EMV', 'LCV'],
          onHeaderTap: () {},
          onTypeTap: (_) {},
        ),
      )));

      for (final element in find.byType(TypeCountRow).evaluate()) {
        expect(tester.getSize(find.byWidget(element.widget)).height,
            greaterThanOrEqualTo(kVehicleMinTapTarget));
      }
    });

    testWidgets('survives a 2x text scale without overflowing',
        (tester) async {
      await tester.pumpWidget(host(
        Builder(
          builder: (context) => buildPivotSection(
            context: context,
            row: row,
            typeColumns: const ['EMV', 'LCV', 'Tipper'],
            onHeaderTap: () {},
            onTypeTap: (_) {},
          ),
        ),
        textScale: 2.0,
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Chain B Total footer is not tappable', (tester) async {
      final total = VehicleStatusRow.fromJson(
        {'zone': 'Total', 'zone_id': 'Total', 'total': 42, 'working': 20},
        labelKey: 'zone',
        idKey: 'zone_id',
      );
      var headerTaps = 0;
      var statusTaps = 0;

      await tester.pumpWidget(host(Builder(
        builder: (context) => buildStatusSection(
          context: context,
          row: total,
          onHeaderTap: () => headerTaps++,
          onStatusTap: (_) => statusTaps++,
        ),
      )));

      await tester.tap(find.text('Total'));
      await tester.tap(find.text('Working'));
      await tester.pump();
      expect(headerTaps, 0);
      expect(statusTaps, 0);
    });
  });

  group('VehicleCard', () {
    testWidgets('shows registration, type, location code and status',
        (tester) async {
      await tester.pumpWidget(host(VehicleCard(vehicle: record())));

      expect(find.text('TN12AB1234'), findsOneWidget);
      expect(find.text('LCV'), findsOneWidget);
      expect(find.text('MDU-Z1'), findsOneWidget);
      expect(find.text('WORKING'), findsOneWidget);
    });

    testWidgets('an unlocked card carries no lock affordance', (tester) async {
      await tester.pumpWidget(host(VehicleCard(vehicle: record())));

      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.text('LOCKED'), findsNothing);
      expect(find.textContaining('Idle reason:'), findsNothing);
    });

    testWidgets('a reasoned card is marked locked and shows the reason',
        (tester) async {
      await tester.pumpWidget(host(
        VehicleCard(
          vehicle: record(status: 'idle', reasoned: 'Driver on leave'),
        ),
      ));

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.text('LOCKED'), findsOneWidget);
      expect(find.text('Idle reason: Driver on leave'), findsOneWidget);
    });

    testWidgets('locked cards are rendered with reduced emphasis',
        (tester) async {
      await tester.pumpWidget(host(Column(children: [
        VehicleCard(vehicle: record(id: 1)),
        VehicleCard(vehicle: record(id: 2, reasoned: 'Breakdown')),
      ])));

      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .toList();
      expect(opacities, hasLength(2));
      expect(opacities.first, 1.0);
      expect(opacities.last, lessThan(1.0));
    });

    testWidgets('a bare boolean true still locks the card', (tester) async {
      // Defensive: the field is documented as reason-text-or-null, but a switch
      // to a real boolean must not silently unlock every card.
      final v = VehicleRecord.fromJson({
        'id': 3,
        'vehicle_number': 'TN99ZZ0001',
        'vehicle_type': 'EMV',
        'project': 'MDU',
        'vehicle_status': 'idle',
        'is_reasoned_today': true,
      });
      expect(v.isLocked, isTrue);
      expect(v.idleReasonText, isNull);

      await tester.pumpWidget(host(VehicleCard(vehicle: v)));
      expect(find.text('LOCKED'), findsOneWidget);
      // No reason text to show, so no note block.
      expect(find.textContaining('Idle reason:'), findsNothing);
    });

    testWidgets('exposes a single merged semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(
        VehicleCard(vehicle: record(reasoned: 'Breakdown')),
      ));

      expect(
        find.bySemanticsLabel(RegExp(
            r'TN12AB1234, LCV, MDU-Z1, working, locked, idle reason already logged today')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('Empty and error states', () {
    testWidgets('empty state states the filter cause and stays scrollable',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: darkMode,
        home: Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {},
            child: const VehicleEmptyScrollable(
              message: 'No vehicles match these filters',
              hint: 'Try clearing the status or owner filter.',
            ),
          ),
        ),
      ));

      expect(find.text('No vehicles match these filters'), findsOneWidget);
      expect(find.text('Try clearing the status or owner filter.'),
          findsOneWidget);

      // A pull must reach the RefreshIndicator even with nothing in the list.
      await tester.fling(
          find.byType(SingleChildScrollView), const Offset(0, 300), 1000);
      await tester.pump();
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('error state offers a working retry', (tester) async {
      var retries = 0;
      await tester.pumpWidget(host(VehicleError(
        message: 'Network error. Please check your connection.',
        onRetry: () => retries++,
      )));

      expect(find.text('Network error. Please check your connection.'),
          findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retries, 1);
    });
  });

  group('VehicleFilterBar', () {
    testWidgets('states the default selection when nothing is filtered',
        (tester) async {
      await tester.pumpWidget(host(VehicleFilterBar(
        filters: const VehicleFilters(),
        onClear: (_) {},
        onEdit: () {},
      )));

      expect(find.text('All statuses · All owners'), findsOneWidget);
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('shows one deletable chip per non-default filter',
        (tester) async {
      VehicleFilters? cleared;
      await tester.pumpWidget(host(VehicleFilterBar(
        filters: const VehicleFilters(
            vehicleStatus: 'Working', vehicleOwner: 'GOVT'),
        onClear: (f) => cleared = f,
        onEdit: () {},
      )));

      expect(find.text('Status: Working'), findsOneWidget);
      expect(find.text('Owner: Government'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.cancel).first);
      await tester.pump();
      // Clearing status leaves the owner filter untouched.
      expect(cleared?.vehicleStatus, 'All');
      expect(cleared?.vehicleOwner, 'GOVT');
    });
  });

  group('VehicleBreadcrumb navigation', () {
    /// Builds: root route (named [rootName]) → zone route → vehicles route,
    /// where the vehicles route hosts the breadcrumb.
    Future<void> pushStack(WidgetTester tester, {String? rootName}) async {
      await tester.pumpWidget(MaterialApp(
        theme: darkMode,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: RouteSettings(name: rootName ?? settings.name),
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: kVtZoneRoute),
                    builder: (context) => Scaffold(
                      body: Center(
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings:
                                  const RouteSettings(name: kVtVehiclesRoute),
                              builder: (_) => const Scaffold(
                                body: VehicleBreadcrumb(crumbs: [
                                  VehicleCrumb('Projects',
                                      routeName: kVtDashboardRoute),
                                  VehicleCrumb('MDU', routeName: kVtZoneRoute),
                                  VehicleCrumb('MDU-Z1-W03'),
                                ]),
                              ),
                            ),
                          ),
                          child: const Text('to vehicles'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('HOME'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('to vehicles'));
      await tester.pumpAndSettle();
    }

    testWidgets('returns to the launch screen when it is the unnamed root',
        (tester) async {
      // The dashboard is the app's home, so at launch it is the root route
      // named '/', not kVtDashboardRoute. Popping to the "Projects" crumb must
      // stop there rather than emptying the whole stack.
      await pushStack(tester, rootName: '/');
      expect(find.text('MDU-Z1-W03'), findsOneWidget);

      await tester.tap(find.text('Projects'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('returns to the dashboard when reached via its named route',
        (tester) async {
      // Drawer entry: pushReplacementNamed('/vehicle_type_dashboard').
      await pushStack(tester, rootName: kVtDashboardRoute);

      await tester.tap(find.text('Projects'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('an intermediate crumb pops only to that level',
        (tester) async {
      await pushStack(tester, rootName: '/');

      await tester.tap(find.text('MDU'));
      await tester.pumpAndSettle();

      // Stopped at the zone route, not all the way home.
      expect(find.text('to vehicles'), findsOneWidget);
      expect(find.text('HOME'), findsNothing);
    });

    testWidgets('the current crumb is inert', (tester) async {
      await pushStack(tester, rootName: '/');

      await tester.tap(find.text('MDU-Z1-W03'));
      await tester.pumpAndSettle();

      expect(find.text('MDU-Z1-W03'), findsOneWidget);
    });
  });

  group('Filter sheet', () {
    testWidgets('opens seeded with the current selection', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: darkMode,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showVehicleFilterSheet(
                context,
                const VehicleFilters(
                    vehicleStatus: 'Working', vehicleOwner: 'OL'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Filters'), findsOneWidget);
      // The seeded values are the ones shown in the closed dropdowns.
      expect(find.text('Working'), findsOneWidget);
      expect(find.text('Ourland'), findsOneWidget);
    });

    testWidgets('changing a dropdown and applying returns the new filters',
        (tester) async {
      VehicleFilters? applied;
      await tester.pumpWidget(MaterialApp(
        theme: darkMode,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                applied = await showVehicleFilterSheet(
                    context, const VehicleFilters());
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Open the status dropdown and pick a value.
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Under Maintenance').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(applied?.vehicleStatus, 'Under Maintenance');
      expect(applied?.vehicleOwner, 'All');
    });

    testWidgets('Reset returns both filters to All', (tester) async {
      VehicleFilters? applied;
      await tester.pumpWidget(MaterialApp(
        theme: darkMode,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                applied = await showVehicleFilterSheet(
                  context,
                  const VehicleFilters(
                      vehicleStatus: 'Idle', vehicleOwner: 'RENT'),
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

      expect(applied?.vehicleStatus, 'All');
      expect(applied?.vehicleOwner, 'All');
      expect(applied?.hasActive, isFalse);
    });
  });
}
