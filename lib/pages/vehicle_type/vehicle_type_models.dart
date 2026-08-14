// ─── Vehicle Type Dashboard — Models, enums & filter state ─────────────────────
//
// Mirrors the architecture of the GVP module (plain immutable classes with
// defensive `fromJson`). Consumes the 6 (+ terminal) drf_vehicle_dash endpoints.
//
// Two independent drill-down chains share the same terminal vehicle list:
//   • Chain A (By Location / pivot) : rows = location, columns = vehicle_type.
//   • Chain B (By Status)           : rows = location, columns = status buckets.

// ─── Choice constants (from the API spec) ──────────────────────────────────────

/// vehicle_type choices — also the dynamic pivot column keys.
const List<String> kVehicleTypes = <String>[
  'Push Cart',
  'Tricycle',
  'BOV',
  'LCV',
  'HCV',
  'Compactor',
  'Hook Loader',
  'Dumper Placer',
  'Tipper',
  'SSSM',
  'LSSM',
  'EMV',
  'Tractor',
  'Others',
];

/// vehicle_status filter values — pivot chain (#1–#3) and terminal (#3b) only.
const List<String> kVehicleStatusFilters = <String>[
  'All',
  'Working',
  'Long Shift',
  'Utilized',
  'Under Maintenance',
  'Idle',
  'All Idle',
];

/// vehicle_owner choices.
const List<String> kVehicleOwners = <String>['All', 'OL', 'GOVT', 'RENT'];

/// Human labels for the owner codes.
const Map<String, String> kVehicleOwnerLabels = <String, String>{
  'All': 'All owners',
  'OL': 'Ourland',
  'GOVT': 'Government',
  'RENT': 'Private',
};

// ─── Chain / level enums ────────────────────────────────────────────────────────

enum VehicleChain { location, status }

extension VehicleChainX on VehicleChain {
  String get label =>
      this == VehicleChain.location ? 'By Location' : 'By Status';
}

/// Status buckets returned per row by the status chain (#4–#6). All seven are
/// always present; a missing key defaults to 0.
///
/// ⚠️ These buckets are NOT mutually exclusive and do NOT sum to [total]
/// (a vehicle can be both `maintenance` and `working`). Never compute a bucket
/// as `total − others` or render a stacked bar that assumes they partition it.
enum VehicleStatusBucket {
  total,
  working,
  longShift,
  utilized,
  maintenance,
  idle,
  allIdle;

  /// JSON key in the status-chain response.
  String get jsonKey {
    switch (this) {
      case VehicleStatusBucket.total:
        return 'total';
      case VehicleStatusBucket.working:
        return 'working';
      case VehicleStatusBucket.longShift:
        return 'long_shift';
      case VehicleStatusBucket.utilized:
        return 'utilized';
      case VehicleStatusBucket.maintenance:
        return 'maintenance';
      case VehicleStatusBucket.idle:
        return 'idle';
      case VehicleStatusBucket.allIdle:
        return 'all_idle';
    }
  }

  String get label {
    switch (this) {
      case VehicleStatusBucket.total:
        return 'Total';
      case VehicleStatusBucket.working:
        return 'Working';
      case VehicleStatusBucket.longShift:
        return 'Long Shift';
      case VehicleStatusBucket.utilized:
        return 'Utilized';
      case VehicleStatusBucket.maintenance:
        return 'Maintenance';
      case VehicleStatusBucket.idle:
        return 'Idle';
      case VehicleStatusBucket.allIdle:
        return 'All Idle';
    }
  }

  /// The `vehicle_status` filter value to forward to the terminal (#3b) when
  /// this column is tapped.
  ///
  /// ⚠️ Discrepancy: the status-chain `idle` bucket EXCLUDES never-operated
  /// vehicles, but forwarding `vehicle_status=Idle` to #3b INCLUDES them, so the
  /// terminal list is a superset of this cell's count. This is intentional and
  /// documented; the terminal screen notes it in the UI.
  String get vehicleStatusValue {
    switch (this) {
      case VehicleStatusBucket.total:
        return 'All';
      case VehicleStatusBucket.working:
        return 'Working';
      case VehicleStatusBucket.longShift:
        return 'Long Shift';
      case VehicleStatusBucket.utilized:
        return 'Utilized';
      case VehicleStatusBucket.maintenance:
        return 'Under Maintenance';
      case VehicleStatusBucket.idle:
        return 'Idle';
      case VehicleStatusBucket.allIdle:
        return 'All Idle';
    }
  }
}

/// The six data buckets shown as columns (Total is rendered as the row badge).
const List<VehicleStatusBucket> kStatusColumns = <VehicleStatusBucket>[
  VehicleStatusBucket.working,
  VehicleStatusBucket.longShift,
  VehicleStatusBucket.utilized,
  VehicleStatusBucket.maintenance,
  VehicleStatusBucket.idle,
  VehicleStatusBucket.allIdle,
];

// ─── Parsing helpers ────────────────────────────────────────────────────────────

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

int? _asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String? _asStringOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

// ─── Filters (persist across the whole drill-down stack) ────────────────────────

class VehicleFilters {
  /// Applies to the pivot chain (#1–#3) and the terminal (#3b).
  final String vehicleStatus;

  /// Applies to every endpoint.
  final String vehicleOwner;

  const VehicleFilters({
    this.vehicleStatus = 'All',
    this.vehicleOwner = 'All',
  });

  bool get hasActive => vehicleStatus != 'All' || vehicleOwner != 'All';

  VehicleFilters copyWith({
    String? vehicleStatus,
    String? vehicleOwner,
  }) {
    return VehicleFilters(
      vehicleStatus: vehicleStatus ?? this.vehicleStatus,
      vehicleOwner: vehicleOwner ?? this.vehicleOwner,
    );
  }

  // Value equality — VehicleQuery compares filters to decide whether a re-fetch
  // is actually needed.
  @override
  bool operator ==(Object other) =>
      other is VehicleFilters &&
      other.vehicleStatus == vehicleStatus &&
      other.vehicleOwner == vehicleOwner;

  @override
  int get hashCode => Object.hash(vehicleStatus, vehicleOwner);

  @override
  String toString() =>
      'VehicleFilters(status: $vehicleStatus, owner: $vehicleOwner)';
}

/// Process-wide holder so filters set in the sheet persist across every screen
/// in the drill-down stack (including back-navigation) without threading them
/// through every constructor.
class VehicleDashFilters {
  VehicleDashFilters._();
  static final VehicleDashFilters instance = VehicleDashFilters._();

  VehicleFilters filters = const VehicleFilters();

  /// Reset to defaults — called when the dashboard is opened fresh.
  void reset() => filters = const VehicleFilters();
}

// ─── Pivot row (Chain A: rows = location, columns = vehicle_type) ────────────────

class VehiclePivotRow {
  /// project code / zone_code / ward code.
  final String label;

  /// zone_id / ward_id — null for the project level (projects have no id).
  final int? id;

  /// Dynamic per-type counts; a type omitted from the JSON is treated as 0.
  final Map<String, int> countsByType;

  const VehiclePivotRow({
    required this.label,
    this.id,
    this.countsByType = const {},
  });

  /// Count for [type] — never throws on a missing key.
  int count(String type) => countsByType[type] ?? 0;

  /// Client-side total (the API provides no Total column for the pivot chain).
  int get total => countsByType.values.fold(0, (a, b) => a + b);

  factory VehiclePivotRow.fromJson(
    Map<String, dynamic> json, {
    required String labelKey,
    String? idKey,
  }) {
    final counts = <String, int>{};
    json.forEach((key, value) {
      if (key == labelKey || key == idKey) return;
      if (value is num) counts[key] = value.toInt();
    });
    return VehiclePivotRow(
      label: _asStringOrNull(json[labelKey]) ?? '—',
      id: idKey == null ? null : _asIntOrNull(json[idKey]),
      countsByType: counts,
    );
  }
}

/// The union of vehicle_type keys across [rows], ordered by the canonical list
/// (then any extras), so every pivot row renders a consistent column set
/// (columns absent from a given row show 0, not blank).
List<String> unionVehicleTypes(List<VehiclePivotRow> rows) {
  final present = <String>{};
  for (final r in rows) {
    present.addAll(r.countsByType.keys);
  }
  final ordered = [for (final t in kVehicleTypes) if (present.contains(t)) t];
  final extras = present.where((t) => !kVehicleTypes.contains(t)).toList()
    ..sort();
  return [...ordered, ...extras];
}

// ─── Status row (Chain B: rows = location, columns = status buckets) ─────────────

class VehicleStatusRow {
  final String label;
  final int? id;

  /// True for the trailing summary row of #5 (`zone_id == "Total"`). Such a row
  /// is a pinned footer and must never be tappable for drill-down.
  final bool isTotalRow;

  final int total;
  final int working;
  final int longShift;
  final int utilized;
  final int maintenance;
  final int idle;
  final int allIdle;

  const VehicleStatusRow({
    required this.label,
    this.id,
    this.isTotalRow = false,
    this.total = 0,
    this.working = 0,
    this.longShift = 0,
    this.utilized = 0,
    this.maintenance = 0,
    this.idle = 0,
    this.allIdle = 0,
  });

  int bucket(VehicleStatusBucket b) {
    switch (b) {
      case VehicleStatusBucket.total:
        return total;
      case VehicleStatusBucket.working:
        return working;
      case VehicleStatusBucket.longShift:
        return longShift;
      case VehicleStatusBucket.utilized:
        return utilized;
      case VehicleStatusBucket.maintenance:
        return maintenance;
      case VehicleStatusBucket.idle:
        return idle;
      case VehicleStatusBucket.allIdle:
        return allIdle;
    }
  }

  factory VehicleStatusRow.fromJson(
    Map<String, dynamic> json, {
    required String labelKey,
    required String idKey,
  }) {
    // #5 appends a summary row where both `zone`/`zone_id` are the string
    // "Total" — detect it via idKey so it is never treated as a real zone.
    final rawId = json[idKey];
    final isTotal = rawId?.toString().toLowerCase() == 'total' ||
        _asStringOrNull(json[labelKey])?.toLowerCase() == 'total';
    return VehicleStatusRow(
      label: _asStringOrNull(json[labelKey]) ?? '—',
      id: isTotal ? null : _asIntOrNull(rawId),
      isTotalRow: isTotal,
      total: _asInt(json['total']),
      working: _asInt(json['working']),
      longShift: _asInt(json['long_shift']),
      utilized: _asInt(json['utilized']),
      maintenance: _asInt(json['maintenance']),
      idle: _asInt(json['idle']),
      allIdle: _asInt(json['all_idle']),
    );
  }
}

// ─── Terminal vehicle record (#3b) ──────────────────────────────────────────────

class VehicleRecord {
  final int id;
  final String vehicleNumber;
  final String vehicleType;
  final String project;
  final int? zone;
  final String? zoneCode;

  /// A vehicle may map to multiple wards.
  final List<int> wards;
  final List<String> wardCodes;

  /// Computed status: working | utilized | idle | all idle | under-maintenance |
  /// in-active. Independent of the vehicle_status filter param.
  final String vehicleStatus;

  /// Idle-reason text logged today, or null.
  ///
  /// ⚠️ Despite the `is_…` name this is **not** a boolean: the API returns the
  /// reason *text* when one was logged today and `null` otherwise. Read
  /// [isLocked] rather than comparing this to `true`.
  final String? isReasonedToday;

  const VehicleRecord({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.project,
    this.zone,
    this.zoneCode,
    this.wards = const [],
    this.wardCodes = const [],
    this.vehicleStatus = '',
    this.isReasonedToday,
  });

  /// True when a reason has already been logged today, which **locks** the card
  /// on Screen 4: it is marked with a lock pill and its idle-reason action is
  /// withheld, because a second reason for the same day would be rejected.
  ///
  /// Tolerates the two shapes the field has been seen in — reason text, and a
  /// literal boolean `true` (parsed by [_asStringOrNull] into `'true'`) — so a
  /// backend change to a real boolean cannot silently unlock every card.
  bool get isLocked {
    final raw = isReasonedToday;
    if (raw == null || raw.isEmpty) return false;
    return raw.toLowerCase() != 'false';
  }

  /// The reason text to display, or null when the lock came from a bare boolean.
  String? get idleReasonText {
    if (!isLocked) return null;
    final raw = isReasonedToday!;
    return raw.toLowerCase() == 'true' ? null : raw;
  }

  factory VehicleRecord.fromJson(Map<String, dynamic> json) {
    List<int> intList(Object? v) {
      if (v is List) return v.map(_asIntOrNull).whereType<int>().toList();
      final single = _asIntOrNull(v);
      return single == null ? <int>[] : [single];
    }

    List<String> strList(Object? v) {
      if (v is List) {
        return v.map(_asStringOrNull).whereType<String>().toList();
      }
      final single = _asStringOrNull(v);
      return single == null ? <String>[] : [single];
    }

    return VehicleRecord(
      id: _asInt(json['id']),
      vehicleNumber: _asStringOrNull(json['vehicle_number']) ?? '—',
      vehicleType: _asStringOrNull(json['vehicle_type']) ?? '—',
      project: _asStringOrNull(json['project']) ?? '—',
      zone: _asIntOrNull(json['zone']),
      zoneCode: _asStringOrNull(json['zone_code']),
      wards: intList(json['ward']),
      wardCodes: strList(json['ward_code']),
      vehicleStatus: _asStringOrNull(json['vehicle_status']) ?? '',
      isReasonedToday: _asStringOrNull(json['is_reasoned_today']),
    );
  }
}
