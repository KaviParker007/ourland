// ─── Vehicle Type Dashboard — Query object & URL builder ───────────────────────
//
// The single source of truth for *every* request this module makes. Screens
// never assemble query strings: they copy a [VehicleQuery] and extend it
// (project → +zone_id → +ward_id), then hand it to [VehicleDashboardApi].
//
// Everything that the backend team might still change — endpoint spelling,
// parameter names, whether `All` is sent or omitted — is a named constant here
// so it is a one-line edit rather than a hunt through widgets.

import 'package:flutter/foundation.dart';

import 'vehicle_type_models.dart';

// ─── Endpoint paths ─────────────────────────────────────────────────────────────

/// Paths are relative to [AppConfig.apiUrl] and keep their trailing slash
/// (Django's `APPEND_SLASH` would otherwise 301 the request and drop params).
class VehicleEndpoints {
  const VehicleEndpoints._();

  // Chain A — By Location (vehicle_type pivot).
  static const String dashByProject = 'drf_vehicle_dash_by_project/';
  static const String dashByZone = 'drf_vehicle_dash_by_zone/';
  static const String dashByWard = 'drf_vehicle_dash_by_ward/';

  // Chain B — By Status.
  static const String statusByProject = 'drf_project_vehicle_dash_by_status/';
  static const String statusByZone = 'drf_zonal_vehicle_dash_by_status/';
  static const String statusByWard = 'drf_ward_vehicle_dash_by_status/';

  /// Terminal vehicle list (Screen 4), shared by both chains.
  ///
  /// ⚠️ Two spellings appear in the specification — `list_queried_vehicles/` and
  /// `drf_list_queried_vehicles/`. They are assumed to be one endpoint; the
  /// `drf_`-prefixed spelling is treated as canonical because it is the one this
  /// app has always called successfully. If the backend team confirms the
  /// unprefixed path, change this one line.
  static const String queriedVehicles = 'drf_list_queried_vehicles/';

  /// Idle-reason POST (the swipe action on Screen 4).
  static const String idleReason = 'drf-idle-vehicle-reason/';
}

// ─── Parameter names ────────────────────────────────────────────────────────────

class VehicleParams {
  const VehicleParams._();

  static const String project = 'project';
  static const String zoneId = 'zone_id';
  static const String wardId = 'ward_id';
  static const String vehicleType = 'vehicle_type';
  static const String vehicleStatus = 'vehicle_status';

  /// ⚠️ The specification's filter table names this parameter `owner`, but every
  /// request this app makes against ourlander.in uses `vehicle_owner` and is
  /// answered correctly. `vehicle_owner` is therefore kept as canonical; flip
  /// this single constant if the backend team confirms `owner`.
  static const String vehicleOwner = 'vehicle_owner';
}

// ─── The `All` question (single point of control) ───────────────────────────────

/// The sentinel both filters default to.
const String kAllFilterValue = 'All';

/// Whether a filter left at [kAllFilterValue] is omitted from the query string
/// instead of being sent literally.
///
/// Currently `false`: the backend accepts and expects the literal `All`, which is
/// how this module has always talked to it. Set to `true` and every endpoint in
/// the module switches to omission — nothing else needs to change.
const bool kOmitAllFilterValues = false;

/// Normalises one filter value for the wire. Returns `null` when the parameter
/// should be left out entirely (empty, or `All` while [kOmitAllFilterValues]).
///
/// This is the *only* place the `All` rule is expressed.
String? encodeFilterValue(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (kOmitAllFilterValues &&
      value.toLowerCase() == kAllFilterValue.toLowerCase()) {
    return null;
  }
  return value;
}

/// Drops null/blank entries and trims the survivors, so callers can write
/// optional params inline without guarding each one.
Map<String, String> cleanParams(Map<String, String?> params) {
  final out = <String, String>{};
  params.forEach((key, value) {
    if (value == null) return;
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) out[key] = trimmed;
  });
  return out;
}

/// Builds the absolute request URI. Kept as a free function so tests can assert
/// the exact query string without instantiating the API client.
Uri buildVehicleUri(String baseUrl, String path, Map<String, String> params) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final suffix = path.startsWith('/') ? path.substring(1) : path;
  return Uri.parse('$base/$suffix')
      .replace(queryParameters: params.isEmpty ? null : params);
}

// ─── Drill levels ───────────────────────────────────────────────────────────────

/// The three aggregate levels. The terminal vehicle list is not a level — it is
/// reachable from all three.
enum VehicleLevel { project, zone, ward }

extension VehicleLevelX on VehicleLevel {
  /// Label for the *group headers* rendered at this level.
  String get groupNoun {
    switch (this) {
      case VehicleLevel.project:
        return 'project';
      case VehicleLevel.zone:
        return 'zone';
      case VehicleLevel.ward:
        return 'ward';
    }
  }
}

// ─── VehicleQuery ───────────────────────────────────────────────────────────────

/// Immutable accumulator for a drill-down path.
///
/// Screens never mutate it: Screen 1 holds `VehicleQuery(filters: …)`, Screen 2
/// receives `query.drillToZones('MDU')`, Screen 3 receives
/// `query.drillToWards(zoneId: 7, zoneCode: 'MDU-Zone1')`, and Screen 4 receives
/// whichever of those the user was on, optionally narrowed with [withType].
///
/// [zoneCode] / [wardCode] are display labels used by the breadcrumb and the
/// Screen 4 provenance header. They are never serialised into a query string.
@immutable
class VehicleQuery {
  final String? project;
  final int? zoneId;
  final String? zoneCode;
  final int? wardId;
  final String? wardCode;

  /// Selected vehicle type, or [kAllFilterValue] when the user drilled by a
  /// group header rather than a type row.
  final String vehicleType;

  /// The two global filters, carried unchanged down the whole stack.
  final VehicleFilters filters;

  const VehicleQuery({
    this.project,
    this.zoneId,
    this.zoneCode,
    this.wardId,
    this.wardCode,
    this.vehicleType = kAllFilterValue,
    this.filters = const VehicleFilters(),
  });

  // ── Copying / extending ───────────────────────────────────────────────────────

  VehicleQuery copyWith({
    String? project,
    int? zoneId,
    String? zoneCode,
    int? wardId,
    String? wardCode,
    String? vehicleType,
    VehicleFilters? filters,
  }) {
    return VehicleQuery(
      project: project ?? this.project,
      zoneId: zoneId ?? this.zoneId,
      zoneCode: zoneCode ?? this.zoneCode,
      wardId: wardId ?? this.wardId,
      wardCode: wardCode ?? this.wardCode,
      vehicleType: vehicleType ?? this.vehicleType,
      filters: filters ?? this.filters,
    );
  }

  /// Screen 1 → Screen 2. Selecting a project discards any deeper scope.
  VehicleQuery drillToZones(String project) => VehicleQuery(
        project: project,
        vehicleType: kAllFilterValue,
        filters: filters,
      );

  /// Screen 2 → Screen 3. Selecting a zone discards any deeper scope.
  VehicleQuery drillToWards({required int zoneId, required String zoneCode}) =>
      VehicleQuery(
        project: project,
        zoneId: zoneId,
        zoneCode: zoneCode,
        vehicleType: kAllFilterValue,
        filters: filters,
      );

  /// Screen 3 → Screen 4 by ward header: adds the ward to the current scope.
  VehicleQuery withWard({required int? wardId, required String wardCode}) =>
      copyWith(wardId: wardId, wardCode: wardCode);

  /// Narrows to one vehicle type (a type row was tapped) — used on all three
  /// aggregate screens when opening Screen 4.
  VehicleQuery withType(String type) => copyWith(vehicleType: type);

  /// Replaces the carried filters (the filter bar changed).
  VehicleQuery withFilters(VehicleFilters next) => copyWith(filters: next);

  /// Recovery from the 400 `project_choices` response: pick a project but stay
  /// at the same level.
  VehicleQuery withProject(String next) => copyWith(project: next);

  // ── Derived scope ─────────────────────────────────────────────────────────────

  /// Deepest location this query is scoped to.
  VehicleLevel get scope {
    if (wardId != null) return VehicleLevel.ward;
    if (zoneId != null) return VehicleLevel.zone;
    return VehicleLevel.project;
  }

  bool get hasType =>
      vehicleType.trim().isNotEmpty &&
      vehicleType.toLowerCase() != kAllFilterValue.toLowerCase();

  /// Human-readable provenance, e.g. `MDU › MDU-Zone1 › MDU-Z1-W03 · LCV`.
  /// Used by the Screen 4 header so the user always knows where the list came
  /// from. Returns `'All vehicles'` when nothing is scoped.
  String get describeScope {
    final parts = <String>[
      if (project != null && project!.isNotEmpty) project!,
      if (zoneCode != null && zoneCode!.isNotEmpty)
        zoneCode!
      else if (zoneId != null)
        'Zone $zoneId',
      if (wardCode != null && wardCode!.isNotEmpty)
        wardCode!
      else if (wardId != null)
        'Ward $wardId',
    ];
    final where = parts.isEmpty ? 'All locations' : parts.join(' › ');
    return hasType ? '$where · $vehicleType' : '$where · All types';
  }

  // ── Wire format ───────────────────────────────────────────────────────────────

  /// The two global filters as they go on the wire. Chain A (#1–#3) and the
  /// terminal accept both; Chain B (#4–#6) takes owner only.
  Map<String, String?> _filterParams({required bool includeStatus}) => {
        if (includeStatus)
          VehicleParams.vehicleStatus: encodeFilterValue(filters.vehicleStatus),
        VehicleParams.vehicleOwner: encodeFilterValue(filters.vehicleOwner),
      };

  /// Params for an aggregate screen (Screens 1–3) on either chain.
  ///
  /// Each level carries everything accumulated so far:
  ///   project level → filters only
  ///   zone level    → `project` + filters
  ///   ward level    → `zone_id` + `project` + filters
  Map<String, String> aggregateParams({
    required VehicleChain chain,
    required VehicleLevel level,
  }) {
    final isLocationChain = chain == VehicleChain.location;
    return cleanParams({
      if (level == VehicleLevel.ward) VehicleParams.zoneId: zoneId?.toString(),
      if (level != VehicleLevel.project) VehicleParams.project: project,
      // Chain B groups across every type, so it pins vehicle_type and ignores
      // the vehicle_status filter (status *is* its axis).
      if (!isLocationChain) VehicleParams.vehicleType: kAllFilterValue,
      ..._filterParams(includeStatus: isLocationChain),
    });
  }

  /// Params for the terminal vehicle list (Screen 4). Sends the full accumulated
  /// location context — not just the deepest id — plus the selected type and
  /// both filters.
  ///
  /// [statusOverride] lets Chain B forward the tapped status bucket instead of
  /// the carried `vehicle_status` filter.
  Map<String, String> vehicleListParams({String? statusOverride}) {
    return cleanParams({
      VehicleParams.wardId: wardId?.toString(),
      VehicleParams.zoneId: zoneId?.toString(),
      VehicleParams.project: project,
      VehicleParams.vehicleType: encodeFilterValue(vehicleType),
      VehicleParams.vehicleStatus:
          encodeFilterValue(statusOverride ?? filters.vehicleStatus),
      VehicleParams.vehicleOwner: encodeFilterValue(filters.vehicleOwner),
    });
  }

  @override
  String toString() =>
      'VehicleQuery(project: $project, zoneId: $zoneId, wardId: $wardId, '
      'vehicleType: $vehicleType, status: ${filters.vehicleStatus}, '
      'owner: ${filters.vehicleOwner})';

  @override
  bool operator ==(Object other) =>
      other is VehicleQuery &&
      other.project == project &&
      other.zoneId == zoneId &&
      other.zoneCode == zoneCode &&
      other.wardId == wardId &&
      other.wardCode == wardCode &&
      other.vehicleType == vehicleType &&
      other.filters == filters;

  @override
  int get hashCode => Object.hash(
        project,
        zoneId,
        zoneCode,
        wardId,
        wardCode,
        vehicleType,
        filters,
      );
}
