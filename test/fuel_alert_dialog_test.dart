// Widget tests for the Add Fuel Log warning dialog and banner.
//
// The behaviour that matters: the dialog gates submission, an accidental
// dismissal cancels rather than continues, and every message the API returned is
// shown verbatim.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ourlandnew/pages/fuel_log/fuel_alert_dialog.dart';
import 'package:ourlandnew/pages/fuel_log/last_fueling_detail.dart';
import 'package:ourlandnew/theme/dark_mode.dart';

LastFuelingDetail detail({bool alert = true, List<String>? messages}) {
  return LastFuelingDetail.fromJson({
    'alert': alert,
    'alert_message': messages ??
        const ['achieved mileage 0.0 is very less than target mileage 4.0'],
  });
}

/// Mounts a button that opens the dialog and records what it resolved to.
Widget host(
  LastFuelingDetail d,
  void Function(bool) onResult, {
  double width = 400,
  double textScale = 1.0,
}) {
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
              child: Builder(
                builder: (inner) => ElevatedButton(
                  onPressed: () async {
                    onResult(await showFuelAlertDialog(inner, d));
                  },
                  child: const Text('save'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('warning dialog', () {
    testWidgets('shows the exact message returned by the API', (tester) async {
      await tester.pumpWidget(host(detail(), (_) {}));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(find.text('Fuel Log Warning'), findsOneWidget);
      expect(
        find.text('achieved mileage 0.0 is very less than target mileage 4.0'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Continue Anyway'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('Continue Anyway resolves true so the save proceeds',
        (tester) async {
      bool? result;
      await tester.pumpWidget(host(detail(), (r) => result = r));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue Anyway'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Fuel Log Warning'), findsNothing);
    });

    testWidgets('Cancel resolves false so nothing is submitted',
        (tester) async {
      bool? result;
      await tester.pumpWidget(host(detail(), (r) => result = r));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Fuel Log Warning'), findsNothing);
    });

    testWidgets('a barrier tap cannot dismiss it, preventing an accidental save',
        (tester) async {
      bool? result;
      await tester.pumpWidget(host(detail(), (r) => result = r));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      // Tap well outside the dialog.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Fuel Log Warning'), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('shows every message when the API returns several',
        (tester) async {
      await tester.pumpWidget(host(
        detail(messages: const [
          'achieved mileage 0.0 is very less than target mileage 4.0',
          'fuel frequency is unusually high',
        ]),
        (_) {},
      ));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(
        find.text('achieved mileage 0.0 is very less than target mileage 4.0'),
        findsOneWidget,
      );
      expect(find.text('fuel frequency is unusually high'), findsOneWidget);
    });

    testWidgets('alert true with no message says so instead of inventing one',
        (tester) async {
      await tester.pumpWidget(host(detail(messages: const []), (_) {}));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(find.text('Fuel Log Warning'), findsOneWidget);
      expect(find.textContaining('did not provide any details'),
          findsOneWidget);
      expect(find.text('Continue Anyway'), findsOneWidget);
    });

    testWidgets('lays out without overflow across sizes and text scales',
        (tester) async {
      final long = detail(messages: const [
        'achieved mileage 0.0 is very less than target mileage 4.0 for this '
            'vehicle over the last recorded fueling interval',
        'fuel frequency is unusually high compared with the fleet average',
        'odometer reading appears inconsistent with the previous entry',
      ]);
      for (final w in [320.0, 400.0, 768.0, 1200.0]) {
        for (final s in [1.0, 1.5, 2.0]) {
          await tester.pumpWidget(
              host(long, (_) {}, width: w, textScale: s));
          await tester.tap(find.text('save'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: 'width $w scale $s');
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        }
      }
    });
  });

  group('warning sound', () {
    testWidgets('is requested when the dialog opens', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add('${call.method}:${call.arguments}');
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(host(detail(), (_) {}));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      // The *alert* tone specifically — Material also fires a click tone on any
      // button tap, so matching the method name alone would prove nothing.
      expect(calls, contains('SystemSound.play:SystemSoundType.alert'));
      expect(calls,
          contains('HapticFeedback.vibrate:HapticFeedbackType.heavyImpact'));
    });

    testWidgets('a sound failure never blocks the dialog', (tester) async {
      // Our warning cue throws — the user must still get the dialog and still
      // be able to continue. Scoped to the alert tone and the heavy impact:
      // Material fires its own click tone on every button tap, and failing that
      // would be testing the framework rather than this code.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          final isOurCue =
              call.arguments == 'SystemSoundType.alert' ||
                  call.arguments == 'HapticFeedbackType.heavyImpact';
          if (isOurCue) {
            throw PlatformException(code: 'unavailable');
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      bool? result;
      await tester.pumpWidget(host(detail(), (r) => result = r));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(find.text('Fuel Log Warning'), findsOneWidget);
      await tester.tap(find.text('Continue Anyway'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('playFuelWarningSound swallows a platform failure',
        (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => throw PlatformException(code: 'unavailable'),
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await expectLater(playFuelWarningSound(), completes);
    });
  });

  group('inline banner', () {
    Widget bannerHost(LastFuelingDetail d, {double width = 400}) =>
        MaterialApp(
          theme: darkMode,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                    child: FuelAlertBanner(detail: d)),
              ),
            ),
          ),
        );

    testWidgets('renders nothing when there is no alert', (tester) async {
      await tester.pumpWidget(bannerHost(detail(alert: false)));
      expect(find.text('Warning'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('shows the messages when there is one', (tester) async {
      await tester.pumpWidget(bannerHost(detail()));
      expect(find.text('Warning'), findsOneWidget);
      expect(
        find.text('achieved mileage 0.0 is very less than target mileage 4.0'),
        findsOneWidget,
      );
    });

    testWidgets('does not overflow at a large text scale', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: darkMode,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: SingleChildScrollView(
                    child: FuelAlertBanner(detail: detail()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
