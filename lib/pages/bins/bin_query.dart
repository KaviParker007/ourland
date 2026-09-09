// ─── Bins — Query object, endpoints & URL builder ──────────────────────────────
//
// Single source of truth for every request the Bins module makes. Screens copy
// and extend a [BinQuery]; none of them assembles a query string.

import 'package:flutter/foundation.dart';

import 'package:ourlandnew/services/dash_api.dart';

// ── Endpoints ──────────────────────────────────────────────────────────────────

class BinEndpoints {
  const BinEndpoints._();

  static const String dashByProject = 'bins/drf_bin_dash_by_project/';
  static const String dashByZone = 'bins/drf_bin_dash_by_zone/';
  static const String dashByWard = 'bins/drf_bin_dash_by_ward/';
  static const String listQueriedBins = 'bins/drf_list_queried_bins/';
}

// ── Parameter names ────────────────────────────────────────────────────────────

class BinParams {
  const BinParams._();

  static const String project = 'project';
  static const String zoneId = 'zone_id';
  static const String wardId = 'ward_id';
  static const String binType = 'bin_type';
  static const String binStatus = 'bin_status';
  static const String binOwner = 'bin_owner';
}

/// Sentinel every bin filter defaults to.
const String kBinAll = 'All';

/// Canonical bin types, used only to give each type a stable colour and a
/// predictable filter ordering. The types actually rendered are always the keys
/// the API returned — this list never gates what is displayed.
const List<String> kBinTypes = <String>[
  'Compactor',
  'HookLoader',
  'Dumper',
  'Others',
];

/// Whether a filter left at [kBinAll] is omitted from the query string instead of
/// sent literally. The endpoints document `All` as the default, so it is sent
/// literally; flip this one constant to switch the whole module to omission.
const bool kOmitBinAllValues = false;

/// Normalises one filter value for the wire. Returns null when the parameter
/// should be left out entirely. The only place the `All` rule is expressed.
String? encodeBinFilter(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (kOmitBinAllValues && value.toLowerCase() == kBinAll.toLowerCase()) {
    return null;
  }
  return value;
}

// ── Filters ────────────────────────────────────────────────────────────────────

/// The three bin filters. All default to `All`.
///
/// These apply to the bin *list* endpoint only — the three dashboard endpoints
/// take just project/zone_id — so the filter UI lives on the bin list screen.
///
/// `binType` is driven by the UI (its values are specified). `binStatus` and
/// `binOwner` are wired end-to-end and sent on every request, but no dropdown is
/// offered for them yet because the API contract does not enumerate their
/// allowed values — see the module README.
@immutable
class BinFilters {
  final String binType;
  final String binStatus;
  final String binOwner;

  const BinFilters({
    this.binType = kBinAll,
    this.binStatus = kBinAll,
    this.binOwner = kBinAll,
  });

  bool get hasActive =>
      binType != kBinAll || binStatus != kBinAll || binOwner != kBinAll;

  BinFilters copyWith({
    String? binType,
    String? binStatus,
    String? binOwner,
  }) {
    return BinFilters(
      binType: binType ?? this.binType,
      binStatus: binStatus ?? this.binStatus,
      binOwner: binOwner ?? this.binOwner,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BinFilters &&
      other.binType == binType &&
      other.binStatus == binStatus &&
      other.binOwner == binOwner;

  @override
  int get hashCode => Object.hash(binType, binStatus, binOwner);

  @override
  String toString() =>
      'BinFilters(type: $binType, status: $binStatus, owner: $binOwner)';
}

// ── Drill levels ───────────────────────────────────────────────────────────────

enum BinLevel { project, zone, ward }

// ── BinQuery ───────────────────────────────────────────────────────────────────

/// Immutable accumulator for a Bins drill-down path.
///
/// Unassigned locations matter here: the by-ward endpoint documents that
/// *omitting* `zone_id` returns bins with no zone, and the list endpoint accepts
/// `0` or `None` for the same idea. A null [zoneId] / [wardId] therefore means
/// "omit the parameter", which is exactly the unassigned case — see
/// [zoneIsUnassigned].
@immutable
class BinQuery {
  final String? project;
  final int? zoneId;
  final String? zoneCode;
  final int? wardId;
  final String? wardCode;

  /// True when the user drilled into a group that had no zone id, i.e. the
  /// "bins without a zone" bucket. Kept explicit so the UI can label it and the
  /// builder does not confuse it with "zone not yet chosen".
  final bool zoneIsUnassigned;
  final bool wardIsUnassigned;

  final BinFilters filters;

  const BinQuery({
    this.project,
    this.zoneId,
    this.zoneCode,
    this.wardId,
    this.wardCode,
    this.zoneIsUnassigned = false,
    this.wardIsUnassigned = false,
    this.filters = const BinFilters(),
  });

  // ── Copying / extending ──────────────────────────────────────────────────────

  BinQuery copyWith({
    String? project,
    int? zoneId,
    String? zoneCode,
    int? wardId,
    String? wardCode,
    bool? zoneIsUnassigned,
    bool? wardIsUnassigned,
    BinFilters? filters,
  }) {
    return BinQuery(
      project: project ?? this.project,
      zoneId: zoneId ?? this.zoneId,
      zoneCode: zoneCode ?? this.zoneCode,
      wardId: wardId ?? this.wardId,
      wardCode: wardCode ?? this.wardCode,
      zoneIsUnassigned: zoneIsUnassigned ?? this.zoneIsUnassigned,
      wardIsUnassigned: wardIsUnassigned ?? this.wardIsUnassigned,
      filters: filters ?? this.filters,
    );
  }

  /// Screen 1 → Screen 2. Choosing a project discards any deeper scope.
  BinQuery drillToZones(String project) =>
      BinQuery(project: project, filters: filters);

  /// Screen 2 → Screen 3. Choosing a zone discards any deeper scope.
  /// A null [zoneId] is the unassigned bucket, and the parameter is omitted.
  BinQuery drillToWards({
    required int? zoneId,
    required String zoneCode,
  }) =>
      BinQuery(
        project: project,
        zoneId: zoneId,
        zoneCode: zoneCode,
        zoneIsUnassigned: zoneId == null,
        filters: filters,
      );

  /// Screen 3 → Screen 4: adds the tapped ward to the current scope.
  BinQuery withWard({required int? wardId, required String wardCode}) =>
      copyWith(
        wardId: wardId,
        wardCode: wardCode,
        wardIsUnassigned: wardId == null,
      );

  /// Screen 2 → Screen 4 by a zone row: the tapped zone becomes the scope.
  BinQuery withZone({required int? zoneId, required String zoneCode}) =>
      copyWith(
        zoneId: zoneId,
        zoneCode: zoneCode,
        zoneIsUnassigned: zoneId == null,
      );

  BinQuery withType(String binType) =>
      copyWith(filters: filters.copyWith(binType: binType));

  BinQuery withFilters(BinFilters next) => copyWith(filters: next);

  // ── Derived ──────────────────────────────────────────────────────────────────

  bool get hasType =>
      filters.binType.trim().isNotEmpty &&
      filters.binType.toLowerCase() != kBinAll.toLowerCase();

  /// Human-readable provenance for the Screen 4 header, e.g.
  /// `MDU › MDU-Z5 › MDU-Z5-W84 · Dumper`.
  String get describeScope {
    final parts = <String>[
      if (project != null && project!.isNotEmpty) project!,
      if (zoneCode != null && zoneCode!.isNotEmpty) zoneCode!,
      if (wardCode != null && wardCode!.isNotEmpty) wardCode!,
    ];
    final where = parts.isEmpty ? 'All locations' : parts.join(' › ');
    return hasType ? '$where · ${filters.binType}' : '$where · All bin types';
  }

  // ── Wire format ──────────────────────────────────────────────────────────────

  Map<String, String?> _filterParams() => {
        BinParams.binType: encodeBinFilter(filters.binType),
        BinParams.binStatus: encodeBinFilter(filters.binStatus),
        BinParams.binOwner: encodeBinFilter(filters.binOwner),
      };

  /// Params for an aggregate screen (Screens 1–3).
  ///
  ///   project level → no location params
  ///   zone level    → `project` (required by the endpoint)
  ///   ward level    → `project` + `zone_id`; omitting `zone_id` is how the
  ///                   endpoint returns bins that have no zone.
  ///
  /// The dashboard endpoints group by bin type, so no bin_type/status/owner
  /// filter is sent — doing so would hollow out every other row.
  Map<String, String> aggregateParams(BinLevel level) {
    return cleanParams({
      if (level != BinLevel.project) BinParams.project: project,
      if (level == BinLevel.ward) BinParams.zoneId: zoneId?.toString(),
    });
  }

  /// Params for the bin list (Screen 4). Sends the full accumulated location
  /// scope plus all three filters.
  Map<String, String> binListParams() {
    return cleanParams({
      BinParams.project: project,
      BinParams.zoneId: zoneId?.toString(),
      BinParams.wardId: wardId?.toString(),
      ..._filterParams(),
    });
  }

  @override
  bool operator ==(Object other) =>
      other is BinQuery &&
      other.project == project &&
      other.zoneId == zoneId &&
      other.zoneCode == zoneCode &&
      other.wardId == wardId &&
      other.wardCode == wardCode &&
      other.zoneIsUnassigned == zoneIsUnassigned &&
      other.wardIsUnassigned == wardIsUnassigned &&
      other.filters == filters;

  @override
  int get hashCode => Object.hash(project, zoneId, zoneCode, wardId, wardCode,
      zoneIsUnassigned, wardIsUnassigned, filters);

  @override
  String toString() => 'BinQuery(project: $project, zoneId: $zoneId, '
      'wardId: $wardId, $filters)';
}
