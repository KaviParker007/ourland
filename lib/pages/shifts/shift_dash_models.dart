// ─── Shift Dashboard — models and query ────────────────────────────────────────
//
// Shapes returned by the v2 shift endpoints:
//
//   drf_shift_dash_by_project_v2   {<status>: [{project, total, <vehicle_type>: n}]}
//   drf_shift_dash_by_zone_v2      {<status>: [{zone, total, <vehicle_type>: n}]}
//   drf_shift_dash_by_creator_v2   {<status>: [{name, employee_code, createdby, total, <vehicle_type>: n}]}
//   drf_shift_dash_by_ward_v2      {<status>: [{ward, total, <vehicle_type>: n}]}
//   drf_list_queried_shifts_v2     [ {id, vehicle, …} ]   (flat array)
//
// Vehicle-type keys are dynamic (LCV, Compactor, Hook Loader, …) and zero counts
// are omitted per row, so every key that is not a known label/id field and
// carries a number is read as a vehicle type. Nothing is hardcoded.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ourlandnew/models/json_parse.dart';

// ── Status ────────────────────────────────────────────────────────────────────

enum ShiftStatus { open, closed, long, unclosed }

extension ShiftStatusX on ShiftStatus {
  /// The value sent as `shift_status` and the key the dashboards wrap rows in.
  String get apiValue => switch (this) {
        ShiftStatus.open => 'Open',
        ShiftStatus.closed => 'Closed',
        ShiftStatus.long => 'Long',
        ShiftStatus.unclosed => 'Unclosed',
      };

  String get description => switch (this) {
        ShiftStatus.open => 'Running for less than 13 hours',
        ShiftStatus.closed => 'Finished normally',
        ShiftStatus.long => 'Running 13 hours or more',
        ShiftStatus.unclosed => 'Running more than 24 hours, all dates',
      };

  Color get color => switch (this) {
        ShiftStatus.open => const Color(0xFF43A047),
        ShiftStatus.closed => const Color(0xFF78909C),
        ShiftStatus.long => const Color(0xFFFB8C00),
        ShiftStatus.unclosed => const Color(0xFFE53935),
      };

  /// Unclosed spans every date; the backend ignores `date`, so it is not sent.
  bool get usesDate => this != ShiftStatus.unclosed;

  static ShiftStatus? fromApi(String? value) {
    for (final s in ShiftStatus.values) {
      if (s.apiValue == value) return s;
    }
    return null;
  }
}

// ── Query ─────────────────────────────────────────────────────────────────────

/// The dashboard filters shared by every view and the record list.
@immutable
class ShiftDashQuery {
  final ShiftStatus status;
  final DateTime date;

  const ShiftDashQuery({required this.status, required this.date});

  String get dateStr => DateFormat('yyyy-MM-dd').format(date);

  ShiftDashQuery copyWith({ShiftStatus? status, DateTime? date}) =>
      ShiftDashQuery(status: status ?? this.status, date: date ?? this.date);

  /// `shift_status`, plus `date` except for Unclosed.
  Map<String, String> baseParams() => {
        'shift_status': status.apiValue,
        if (status.usesDate) 'date': dateStr,
      };

  /// Identifies a result set, so a view only refetches when filters changed.
  String key([String? scope]) =>
      '${status.apiValue}|${status.usesDate ? dateStr : '*'}|${scope ?? ''}';

  @override
  bool operator ==(Object other) =>
      other is ShiftDashQuery && other.status == status && other.dateStr == dateStr;

  @override
  int get hashCode => Object.hash(status, dateStr);
}

/// Filters for drf_list_queried_shifts_v2, plus labels for the breadcrumb.
@immutable
class ShiftListFilter {
  final ShiftDashQuery query;
  final String? project;
  final String? zoneCode;
  final String? wardCode;

  /// Employee *id* of the starter (`createdby`) — not the employee code.
  final int? createdBy;
  final String? creatorLabel;
  final String? vehicleType;

  const ShiftListFilter({
    required this.query,
    this.project,
    this.zoneCode,
    this.wardCode,
    this.createdBy,
    this.creatorLabel,
    this.vehicleType,
  });

  ShiftListFilter withVehicleType(String? type) => ShiftListFilter(
        query: query,
        project: project,
        zoneCode: zoneCode,
        wardCode: wardCode,
        createdBy: createdBy,
        creatorLabel: creatorLabel,
        vehicleType: type,
      );

  Map<String, String?> toParams() => {
        ...query.baseParams(),
        'vehicle_type': vehicleType,
        'project': project,
        'zone_code': zoneCode,
        'ward_code': wardCode,
        'createdby': createdBy?.toString(),
      };
}

// ── Dashboard rows ────────────────────────────────────────────────────────────

/// Keys that describe a row rather than count a vehicle type.
const _kNonVehicleKeys = {
  'project',
  'zone',
  'zone_code',
  'ward',
  'ward_code',
  'name',
  'employee_code',
  'createdby',
  'total',
};

/// One row of any of the four dashboards.
@immutable
class ShiftDashRow {
  /// project / zone code / ward code / starter name.
  final String label;
  final int total;

  /// Vehicle type → count, in response order, zero counts dropped.
  final Map<String, int> vehicleCounts;

  // Creator rows only.
  final int? createdBy;
  final String? employeeCode;

  const ShiftDashRow({
    required this.label,
    required this.total,
    this.vehicleCounts = const {},
    this.createdBy,
    this.employeeCode,
  });

  factory ShiftDashRow.fromJson(Map<String, dynamic> json, String labelKey) {
    final counts = <String, int>{};
    json.forEach((key, value) {
      if (_kNonVehicleKeys.contains(key)) return;
      final n = value is num ? value : num.tryParse(value?.toString() ?? '');
      if (n != null && n > 0) counts[key] = n.toInt();
    });
    return ShiftDashRow(
      label: asStringOrNull(json[labelKey]) ?? '',
      total: asInt(json['total']),
      vehicleCounts: counts,
      createdBy: asIntOrNull(json['createdby']),
      employeeCode: asStringOrNull(json['employee_code']),
    );
  }
}

/// Reads `{<status>: [rows]}`. Tolerates a bare list, a missing key and
/// non-object entries; rows without a label are dropped.
List<ShiftDashRow> parseShiftDash(
    Object? decoded, ShiftStatus status, String labelKey) {
  Object? list = decoded;
  if (decoded is Map) list = decoded[status.apiValue];
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => ShiftDashRow.fromJson(Map<String, dynamic>.from(e), labelKey))
      .where((r) => r.label.isNotEmpty)
      .toList();
}

// ── Vehicle type colours ──────────────────────────────────────────────────────

const _kKnownVehicleColors = <String, Color>{
  'Tipper': Color(0xFFFF7043),
  'Tractor': Color(0xFF42A5F5),
  'LCV': Color(0xFF66BB6A),
  'EMV': Color(0xFFAB47BC),
  'Compactor': Color(0xFF26C6DA),
};

const _kFallbackVehicleColors = <Color>[
  Color(0xFFFFCA28),
  Color(0xFFEC407A),
  Color(0xFF8D6E63),
  Color(0xFF5C6BC0),
  Color(0xFF9CCC65),
  Color(0xFF26A69A),
  Color(0xFFFFA726),
  Color(0xFF7E57C2),
];

/// Stable colour for any vehicle type: the established palette for the types
/// the app already showed, and a name-derived one for any new type.
Color vehicleTypeColor(String? type) {
  if (type == null) return Colors.grey;
  final known = _kKnownVehicleColors[type];
  if (known != null) return known;
  var hash = 0;
  for (final c in type.codeUnits) {
    hash = (hash * 31 + c) & 0x7fffffff;
  }
  return _kFallbackVehicleColors[hash % _kFallbackVehicleColors.length];
}
