// Shift Dashboard swipe navigation, against a mocked backend: swiping and
// tapping switch views, filters and loaded data survive the switch, Unclosed
// drops the date, and a creator count opens the records with `createdby`.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as raw;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ourlandnew/pages/shifts/shift_dashboard.dart';

final requests = <Uri>[];

raw.Response _respond(raw.Request req) {
  requests.add(req.url);
  final status = req.url.queryParameters['shift_status'] ?? 'Open';
  final path = req.url.path;
  Object body = const [];
  if (path.contains('drf_shift_dash_by_project_v2')) {
    body = {
      status: [
        {'project': 'MDU', 'total': 5, 'LCV': 3, 'Hook Loader': 2},
      ],
    };
  } else if (path.contains('drf_shift_dash_by_creator_v2')) {
    body = {
      status: [
        {
          'name': 'Ravi Kumar',
          'employee_code': 'OL0123',
          'createdby': 77,
          'total': 4,
          'Tipper': 4,
        },
      ],
    };
  } else if (path.contains('drf_shift_dash_by_')) {
    body = {status: []};
  }
  return raw.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
}

List<Uri> calls(String endpoint) =>
    requests.where((u) => u.path.contains(endpoint)).toList();

Future<void> pumpDashboard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await raw.runWithClient(
    () => tester.pumpWidget(const MaterialApp(home: ShiftDashboardPage())),
    () => MockClient((req) async => _respond(req)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    requests.clear();
    SharedPreferences.setMockInitialValues(
        {'username': 'tester', 'password': 'secret'});
  });

  testWidgets('loads projects with dynamic vehicle types', (tester) async {
    await pumpDashboard(tester);

    expect(find.text('MDU'), findsOneWidget);
    expect(find.text('Hook Loader  2'), findsOneWidget);
    expect(calls('drf_shift_dash_by_project_v2'), hasLength(1));
    expect(calls('drf_shift_dash_by_project_v2').single.queryParameters,
        containsPair('shift_status', 'Open'));
  });

  testWidgets('swipe right-to-left opens By Creator, left-to-right returns',
      (tester) async {
    await pumpDashboard(tester);

    await tester.fling(find.text('MDU'), const Offset(-500, 0), 1500);
    await tester.pumpAndSettle();

    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('OL0123'), findsOneWidget);
    expect(calls('drf_shift_dash_by_creator_v2'), hasLength(1));

    // Left-to-right swipe back to By Location.
    await tester.fling(find.text('Ravi Kumar'), const Offset(500, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('MDU'), findsOneWidget);

    // Loaded data is kept: nothing was refetched by swiping.
    expect(calls('drf_shift_dash_by_project_v2'), hasLength(1));

    // And swiping to creators again reuses the loaded list.
    await tester.fling(find.text('MDU'), const Offset(-500, 0), 1500);
    await tester.pumpAndSettle();
    expect(calls('drf_shift_dash_by_creator_v2'), hasLength(1));
  });

  testWidgets('tapping the view tabs switches views too', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.text('By Creator'));
    await tester.pumpAndSettle();
    expect(find.text('Ravi Kumar'), findsOneWidget);

    await tester.tap(find.text('By Location'));
    await tester.pumpAndSettle();
    expect(find.text('MDU'), findsOneWidget);
  });

  testWidgets('status filter carries across views; Unclosed sends no date',
      (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.text('Unclosed'));
    await tester.pumpAndSettle();
    final project = calls('drf_shift_dash_by_project_v2').last.queryParameters;
    expect(project['shift_status'], 'Unclosed');
    expect(project.containsKey('date'), isFalse);
    expect(find.text('All dates'), findsOneWidget);

    await tester.tap(find.text('By Creator'));
    await tester.pumpAndSettle();
    final creator = calls('drf_shift_dash_by_creator_v2').last.queryParameters;
    expect(creator['shift_status'], 'Unclosed');
    expect(creator.containsKey('date'), isFalse);
  });

  testWidgets('narrow phone with large text: no overflow, all tabs reachable',
      (tester) async {
    tester.view.physicalSize = const Size(960, 2000); // 320 dp wide
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await raw.runWithClient(
      () => tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(
            size: Size(320, 667), textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(home: ShiftDashboardPage()),
      )),
      () => MockClient((req) async => _respond(req)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final label in ['Open', 'Closed', 'Long', 'Unclosed', 'By Creator']) {
      expect(tester.getRect(find.text(label)).right,
          lessThanOrEqualTo(320), reason: label);
    }
  });

  testWidgets('a creator count opens the records filtered by createdby id',
      (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.text('By Creator'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();

    final list = calls('drf_list_queried_shifts_v2').single.queryParameters;
    expect(list['createdby'], '77');
    expect(list.values, isNot(contains('OL0123')));
    expect(find.text('No shifts found'), findsOneWidget);
  });
}
