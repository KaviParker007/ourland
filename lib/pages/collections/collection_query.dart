// ─── Collections — Date range, query object, endpoints & URL builder ───────────
//
// Single source of truth for every request the Collections module makes.

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:ourlandnew/services/dash_api.dart';

// ── Endpoints ──────────────────────────────────────────────────────────────────

class CollectionEndpoints {
  const CollectionEndpoints._();

  static const String byProject = 'bins/drf_bincollection_by_project/';
  static const String byZone = 'bins/drf_bincollection_by_zone/';
  static const String byWard = 'bins/drf_bincollection_by_ward/';
  static const String listQueried = 'bins/drf_list_queried_bin_collection/';
}

class CollectionParams {
  const CollectionParams._();

  static const String project = 'project';
  static const String zoneId = 'zone_id';
  static const String wardId = 'ward_id';
  static const String binType = 'bin_type';
  static const String startDate = 'start_date';
  static const String endDate = 'end_date';
}

/// Sentinel the bin-type filter defaults to.
const String kCollectionAll = 'All';

/// Documented `bin_type` values for the collection list.
const List<String> kCollectionBinTypes = <String>[
  'Compactor',
  'HookLoader',
  'Dumper',
  'Others',
];

/// Maximum span the collection endpoints accept, inclusive of both ends.
/// A range of today→today is 1 day; today→today+6 is 7.
const int kMaxCollectionRangeDays = 7;

// ── Date range ─────────────────────────────────────────────────────────────────

/// An inclusive `start_date`..`end_date` pair, normalised to whole days.
///
/// Both ends default to today. The range is validated *before* any request is
/// made — see [error] and [isValid] — so an out-of-range span never reaches the
/// API.
@immutable
class CollectionDateRange {
  final DateTime start;
  final DateTime end;

  const CollectionDateRange._(this.start, this.end);

  /// Strips the time component so comparisons and day counts are exact.
  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  factory CollectionDateRange(DateTime start, DateTime end) =>
      CollectionDateRange._(dayOf(start), dayOf(end));

  /// Both ends today — the documented default.
  factory CollectionDateRange.today() {
    final today = dayOf(DateTime.now());
    return CollectionDateRange._(today, today);
  }

  /// Inclusive length in days.
  int get lengthInDays => end.difference(start).inDays + 1;

  /// Null when the range is acceptable, otherwise a message fit for the UI.
  String? get error {
    if (end.isBefore(start)) {
      return 'The end date cannot be before the start date.';
    }
    if (lengthInDays > kMaxCollectionRangeDays) {
      return 'Please choose a range of $kMaxCollectionRangeDays days or fewer '
          '(currently $lengthInDays).';
    }
    return null;
  }

  bool get isValid => error == null;

  bool get isSingleDay => start == end;

  bool get isToday => isSingleDay && start == dayOf(DateTime.now());

  /// Latest end date allowed for the current [start], for clamping the picker.
  DateTime get maxEndForStart =>
      start.add(const Duration(days: kMaxCollectionRangeDays - 1));

  static final DateFormat _wire = DateFormat('yyyy-MM-dd');
  static final DateFormat _display = DateFormat('dd MMM yyyy');
  static final DateFormat _displayShort = DateFormat('dd MMM');

  String get startParam => _wire.format(start);
  String get endParam => _wire.format(end);

  /// `Today`, `08 Sep 2026`, or `02 Sep – 08 Sep 2026`.
  String get label {
    if (isToday) return 'Today';
    if (isSingleDay) return _display.format(start);
    final sameYear = start.year == end.year;
    final left = sameYear ? _displayShort.format(start) : _display.format(start);
    return '$left – ${_display.format(end)}';
  }

  /// Moves the start, pulling the end along when the move would either invert
  /// the range or push it past the 7-day cap. Keeps every produced range valid.
  CollectionDateRange withStart(DateTime next) {
    final s = dayOf(next);
    var e = end;
    if (e.isBefore(s)) e = s;
    final cap = s.add(const Duration(days: kMaxCollectionRangeDays - 1));
    if (e.isAfter(cap)) e = cap;
    return CollectionDateRange._(s, e);
  }

  /// Moves the end, pulling the start along under the same rules.
  CollectionDateRange withEnd(DateTime next) {
    final e = dayOf(next);
    var s = start;
    if (s.isAfter(e)) s = e;
    final floor = e.subtract(const Duration(days: kMaxCollectionRangeDays - 1));
    if (s.isBefore(floor)) s = floor;
    return CollectionDateRange._(s, e);
  }

  @override
  bool operator ==(Object other) =>
      other is CollectionDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'CollectionDateRange($startParam..$endParam)';
}

/// Process-wide holder so the chosen range survives back-navigation across the
/// Collections stack.
class CollectionDateFilter {
  CollectionDateFilter._();
  static final CollectionDateFilter instance = CollectionDateFilter._();

  CollectionDateRange range = CollectionDateRange.today();

  void reset() => range = CollectionDateRange.today();
}

// ── Drill levels ───────────────────────────────────────────────────────────────

enum CollectionLevel { project, zone, ward }

// ── CollectionQuery ────────────────────────────────────────────────────────────

/// Immutable accumulator for a Collections drill-down path.
@immutable
class CollectionQuery {
  final String? project;
  final int? zoneId;
  final String? zoneCode;
  final int? wardId;
  final String? wardCode;

  /// True when the user drilled into a group that had no id — the "without a
  /// zone/ward" bucket, expressed on the wire by omitting the parameter.
  final bool zoneIsUnassigned;
  final bool wardIsUnassigned;

  final String binType;
  final CollectionDateRange range;

  CollectionQuery({
    this.project,
    this.zoneId,
    this.zoneCode,
    this.wardId,
    this.wardCode,
    this.zoneIsUnassigned = false,
    this.wardIsUnassigned = false,
    this.binType = kCollectionAll,
    CollectionDateRange? range,
  }) : range = range ?? CollectionDateRange.today();

  // ── Copying / extending ──────────────────────────────────────────────────────

  CollectionQuery copyWith({
    String? project,
    int? zoneId,
    String? zoneCode,
    int? wardId,
    String? wardCode,
    bool? zoneIsUnassigned,
    bool? wardIsUnassigned,
    String? binType,
    CollectionDateRange? range,
  }) {
    return CollectionQuery(
      project: project ?? this.project,
      zoneId: zoneId ?? this.zoneId,
      zoneCode: zoneCode ?? this.zoneCode,
      wardId: wardId ?? this.wardId,
      wardCode: wardCode ?? this.wardCode,
      zoneIsUnassigned: zoneIsUnassigned ?? this.zoneIsUnassigned,
      wardIsUnassigned: wardIsUnassigned ?? this.wardIsUnassigned,
      binType: binType ?? this.binType,
      range: range ?? this.range,
    );
  }

  /// Screen 1 → Screen 2. Choosing a project discards any deeper scope.
  CollectionQuery drillToZones(String project) =>
      CollectionQuery(project: project, range: range);

  /// Screen 2 → Screen 3. Choosing a zone discards any deeper scope.
  CollectionQuery drillToWards({
    required int? zoneId,
    required String zoneCode,
  }) =>
      CollectionQuery(
        project: project,
        zoneId: zoneId,
        zoneCode: zoneCode,
        zoneIsUnassigned: zoneId == null,
        range: range,
      );

  CollectionQuery withZone({required int? zoneId, required String zoneCode}) =>
      copyWith(
        zoneId: zoneId,
        zoneCode: zoneCode,
        zoneIsUnassigned: zoneId == null,
      );

  CollectionQuery withWard({required int? wardId, required String wardCode}) =>
      copyWith(
        wardId: wardId,
        wardCode: wardCode,
        wardIsUnassigned: wardId == null,
      );

  CollectionQuery withType(String type) => copyWith(binType: type);

  CollectionQuery withRange(CollectionDateRange next) => copyWith(range: next);

  // ── Derived ──────────────────────────────────────────────────────────────────

  bool get hasType =>
      binType.trim().isNotEmpty &&
      binType.toLowerCase() != kCollectionAll.toLowerCase();

  /// Human-readable provenance for the Screen 4 header, e.g.
  /// `MDU › MDU-Z5 › MDU-Z5-W84 · Dumper · 02 Sep – 08 Sep 2026`.
  String get describeScope {
    final parts = <String>[
      if (project != null && project!.isNotEmpty) project!,
      if (zoneCode != null && zoneCode!.isNotEmpty) zoneCode!,
      if (wardCode != null && wardCode!.isNotEmpty) wardCode!,
    ];
    final where = parts.isEmpty ? 'All locations' : parts.join(' › ');
    final type = hasType ? binType : 'All bin types';
    return '$where · $type · ${range.label}';
  }

  // ── Wire format ──────────────────────────────────────────────────────────────

  Map<String, String?> _dateParams() => {
        CollectionParams.startDate: range.startParam,
        CollectionParams.endDate: range.endParam,
      };

  /// Params for an aggregate screen (Screens 1–3).
  ///
  /// ⚠️ The three levels do NOT take the same location params:
  ///   project level → dates only
  ///   zone level    → `project` + dates
  ///   ward level    → `zone_id` + dates, and deliberately **no** `project` —
  ///                   `drf_bincollection_by_ward` filters by zone_id alone.
  ///                   Omitting zone_id is how it returns collections with no
  ///                   zone.
  ///
  /// The dashboards group by bin type, so no bin_type filter is sent — doing so
  /// would hollow out every other row.
  Map<String, String> aggregateParams(CollectionLevel level) {
    return cleanParams({
      if (level == CollectionLevel.zone) CollectionParams.project: project,
      if (level == CollectionLevel.ward)
        CollectionParams.zoneId: zoneId?.toString(),
      ..._dateParams(),
    });
  }

  /// Params for the collection list (Screen 4): the full accumulated scope, the
  /// bin type and the dates.
  Map<String, String> collectionListParams() {
    return cleanParams({
      CollectionParams.project: project,
      CollectionParams.zoneId: zoneId?.toString(),
      CollectionParams.wardId: wardId?.toString(),
      if (hasType) CollectionParams.binType: binType,
      ..._dateParams(),
    });
  }

  @override
  bool operator ==(Object other) =>
      other is CollectionQuery &&
      other.project == project &&
      other.zoneId == zoneId &&
      other.zoneCode == zoneCode &&
      other.wardId == wardId &&
      other.wardCode == wardCode &&
      other.zoneIsUnassigned == zoneIsUnassigned &&
      other.wardIsUnassigned == wardIsUnassigned &&
      other.binType == binType &&
      other.range == range;

  @override
  int get hashCode => Object.hash(project, zoneId, zoneCode, wardId, wardCode,
      zoneIsUnassigned, wardIsUnassigned, binType, range);

  @override
  String toString() => 'CollectionQuery(project: $project, zoneId: $zoneId, '
      'wardId: $wardId, binType: $binType, $range)';
}
