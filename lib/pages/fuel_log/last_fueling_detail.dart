// ─── Add Fuel Log — last fueling detail ────────────────────────────────────────
//
// Parses the response of `drf_get_last_fueling_detail/`:
//
//   {
//     "last_odo_reading": 0.0,
//     "last_fuel_date": "2026-09-08",
//     "last_fuel_time": "2026-09-08T14:52:15.879030",
//     "last_fuel_quantity": 20.0,
//     "mileage": 0.0,
//     "mileage_status": 0.0,
//     "fuel_freq": 0,
//     "alert": true,
//     "alert_message": ["achieved mileage 0.0 is very less than target mileage 4.0"]
//   }
//
// Every field is optional as far as this parser is concerned: a missing key, a
// null, a number arriving as a string, or `alert_message` being null / a bare
// string / an empty list must never throw. The display getters return 'N/A'
// rather than blank so an absent value is visibly absent.

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

@immutable
class LastFuelingDetail {
  final double? lastOdoReading;
  final String? lastFuelDate;
  final String? lastFuelTime;
  final double? lastFuelQuantity;
  final double? mileage;
  final double? mileageStatus;
  final int? fuelFreq;

  /// Whether the backend wants the user warned before saving.
  final bool alert;

  /// The warning text exactly as returned. Never generated or reworded here —
  /// the same strings are what get posted back with the fuel log.
  final List<String> alertMessages;

  const LastFuelingDetail({
    this.lastOdoReading,
    this.lastFuelDate,
    this.lastFuelTime,
    this.lastFuelQuantity,
    this.mileage,
    this.mileageStatus,
    this.fuelFreq,
    this.alert = false,
    this.alertMessages = const [],
  });

  /// The empty state, used before a vehicle is chosen and after a failed call.
  static const LastFuelingDetail empty = LastFuelingDetail();

  // ── Parsing ──────────────────────────────────────────────────────────────────

  static double? _double(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  static int? _int(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  static String? _string(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static bool _bool(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().trim().toLowerCase();
    return s == 'true' || s == '1';
  }

  /// Accepts a list, a bare string, or null. Blank entries are dropped, so an
  /// `["", null]` payload behaves like an empty list.
  static List<String> _messages(Object? raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }
    final s = raw.toString().trim();
    return s.isEmpty ? const [] : <String>[s];
  }

  factory LastFuelingDetail.fromJson(Map<String, dynamic> json) {
    return LastFuelingDetail(
      lastOdoReading: _double(json['last_odo_reading']),
      lastFuelDate: _string(json['last_fuel_date']),
      lastFuelTime: _string(json['last_fuel_time']),
      lastFuelQuantity: _double(json['last_fuel_quantity']),
      mileage: _double(json['mileage']),
      mileageStatus: _double(json['mileage_status']),
      fuelFreq: _int(json['fuel_freq']),
      alert: _bool(json['alert']),
      alertMessages: _messages(json['alert_message']),
    );
  }

  // ── Alert ────────────────────────────────────────────────────────────────────

  /// True when the warning dialog should gate submission.
  ///
  /// Driven by `alert` alone: the backend can flag a problem without supplying
  /// text, and swallowing the warning in that case would be worse than showing
  /// it with no detail.
  bool get shouldWarn => alert;

  bool get hasAlertMessages => alertMessages.isNotEmpty;

  /// The value posted back as `alert_message` with the fuel log, or null when
  /// there is nothing to send.
  ///
  /// A single message — the documented case — goes back verbatim. Multiple are
  /// joined rather than JSON-encoded, because multipart fields are plain
  /// strings; if the backend would rather receive a JSON array, this one getter
  /// is the place to change it.
  String? get alertMessageForSubmission {
    if (alertMessages.isEmpty) return null;
    if (alertMessages.length == 1) return alertMessages.first;
    return alertMessages.join(' | ');
  }

  // ── Display ──────────────────────────────────────────────────────────────────

  static const String _na = 'N/A';

  String get odoReadingDisplay => lastOdoReading?.toString() ?? _na;

  String get fuelDateDisplay => lastFuelDate ?? _na;

  /// `last_fuel_time` arrives as a full ISO timestamp; only the clock time is
  /// worth showing, since the date sits in its own field. Falls back to the raw
  /// string if it is not a timestamp we recognise.
  String get fuelTimeDisplay {
    final raw = lastFuelTime;
    if (raw == null) return _na;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('hh:mm a').format(parsed);
  }

  String get fuelQuantityDisplay =>
      lastFuelQuantity == null ? _na : '$lastFuelQuantity L';

  String get mileageDisplay => mileage?.toString() ?? _na;

  String get mileageStatusDisplay => mileageStatus?.toString() ?? _na;

  String get fuelFreqDisplay => fuelFreq?.toString() ?? _na;
}
