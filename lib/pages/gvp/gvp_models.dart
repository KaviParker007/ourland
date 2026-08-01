// ─── GVP Module — Strongly typed models ───────────────────────────────────────
//
// Mirrors the JSON contracts of the `/gvp` API set. Parsing is intentionally
// defensive (accepting int/String/num variants) so a minor backend field-type
// change never crashes the UI.

/// Allowed project codes accepted by the create/update endpoints.
/// Order matches the values listed in the API specification.
const List<String> kGvpProjects = <String>[
  'TBM',
  'MDU',
  'VM',
  'BBSR',
  'KRR',
  'TN',
  'CO',
  'SIPCOT',
  'Navalur',
  'Others',
];

// ─── Small parsing helpers ────────────────────────────────────────────────────

String? _asStringOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int? _asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

bool? _asBoolOrNull(Object? v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().trim().toLowerCase();
  if (s == 'true' || s == '1' || s == 'yes' || s == 'active') return true;
  if (s == 'false' || s == '0' || s == 'no' || s == 'inactive') return false;
  return null;
}

// ─── Daily cleaning status ─────────────────────────────────────────────────────
//
// The backend reports a GVP's cleaning progress for the current day via a
// `today_status` field with three values:
//   • NT  — Not Taken up (no confirmation yet)          → swipe reveals "Before"
//   • WIP — Work In Progress (before image captured)    → swipe reveals "After"
//   • C   — Cleared (after image captured, locked)      → no swipe

enum GvpTodayStatus {
  nt,
  wip,
  cleared,
  unknown;

  /// Parses the raw `today_status` string defensively (case/space insensitive).
  static GvpTodayStatus fromRaw(Object? raw) {
    final s = _asStringOrNull(raw)?.toUpperCase();
    switch (s) {
      case 'NC':
        return GvpTodayStatus.nt;
      case 'WIP':
        return GvpTodayStatus.wip;
      case 'C':
        return GvpTodayStatus.cleared;
      default:
        return GvpTodayStatus.unknown;
    }
  }

  /// The canonical code the backend uses, or null when unknown.
  String? get code {
    switch (this) {
      case GvpTodayStatus.nt:
        return 'NC';
      case GvpTodayStatus.wip:
        return 'WIP';
      case GvpTodayStatus.cleared:
        return 'C';
      case GvpTodayStatus.unknown:
        return null;
    }
  }

  bool get isSwipeable =>
      this == GvpTodayStatus.nt || this == GvpTodayStatus.wip;
}

// ─── GVP (list row) ───────────────────────────────────────────────────────────

class Gvp {
  final int id;
  final String name;
  final String project;
  final int? zone;
  final int? ward;
  final String? latitude;
  final String? longitude;
  final bool active;

  /// Cleaning status for the current day, driving both the card colour and the
  /// available swipe action.
  final GvpTodayStatus todayStatus;

  /// The open GVPDailyConfirmation record id for today (`gvp_open_dc`), present
  /// once a "Before" image has been captured (status WIP). This is the pk passed
  /// to the close (After) endpoint — note it is the confirmation id, **not** the
  /// GVP id.
  final int? gvpOpenDc;

  const Gvp({
    required this.id,
    required this.name,
    required this.project,
    this.zone,
    this.ward,
    this.latitude,
    this.longitude,
    this.active = true,
    this.todayStatus = GvpTodayStatus.unknown,
    this.gvpOpenDc,
  });

  factory Gvp.fromJson(Map<String, dynamic> json) {
    return Gvp(
      id: _asIntOrNull(json['id']) ?? 0,
      name: _asStringOrNull(json['name']) ?? '',
      project: _asStringOrNull(json['project']) ?? '',
      zone: _asIntOrNull(json['zone']),
      ward: _asIntOrNull(json['ward']),
      latitude: _asStringOrNull(json['latitude']),
      longitude: _asStringOrNull(json['longitude']),
      // The list endpoint only returns active records; default to true when
      // the flag is absent.
      active: _asBoolOrNull(json['active'] ?? json['is_active']) ?? true,
      todayStatus: GvpTodayStatus.fromRaw(json['today_status']),
      // `drf_list_queried_gvp` returns the open daily-confirmation pk here.
      gvpOpenDc: _asIntOrNull(json['gvp_open_dc']),
    );
  }
}

// ─── Daily confirmation (create / close response) ──────────────────────────────

class DailyConfirmation {
  final int id;
  final int? gvp;
  final GvpTodayStatus todayStatus;
  final bool isCleared;

  const DailyConfirmation({
    required this.id,
    this.gvp,
    this.todayStatus = GvpTodayStatus.unknown,
    this.isCleared = false,
  });

  factory DailyConfirmation.fromJson(Map<String, dynamic> json) {
    return DailyConfirmation(
      id: _asIntOrNull(json['id']) ?? 0,
      gvp: _asIntOrNull(json['gvp']),
      todayStatus: GvpTodayStatus.fromRaw(
          json['today_status'] ?? json['gvp_today_status']),
      isCleared: _asBoolOrNull(json['is_cleared']) ?? false,
    );
  }
}

// ─── Reference image ──────────────────────────────────────────────────────────

class GvpReferenceImage {
  final int id;
  final String image;
  final String? caption;

  const GvpReferenceImage({
    required this.id,
    required this.image,
    this.caption,
  });

  factory GvpReferenceImage.fromJson(Map<String, dynamic> json) {
    return GvpReferenceImage(
      id: _asIntOrNull(json['id']) ?? 0,
      image: _asStringOrNull(json['image']) ?? '',
      caption: _asStringOrNull(json['caption']),
    );
  }
}

// ─── GVP detail ───────────────────────────────────────────────────────────────

class GvpDetail {
  final int id;
  final String name;
  final String project;
  final int? zone;
  final int? ward;
  final String? latitude;
  final String? longitude;
  final bool active;
  final String? createdOn;
  final String? createdBy;
  final List<GvpReferenceImage> referenceImages;

  const GvpDetail({
    required this.id,
    required this.name,
    required this.project,
    this.zone,
    this.ward,
    this.latitude,
    this.longitude,
    this.active = true,
    this.createdOn,
    this.createdBy,
    this.referenceImages = const [],
  });

  factory GvpDetail.fromJson(Map<String, dynamic> json) {
    final rawImages = json['reference_images'];
    final images = (rawImages is List)
        ? rawImages
            .whereType<Map>()
            .map((e) => GvpReferenceImage.fromJson(
                Map<String, dynamic>.from(e)))
            .toList()
        : <GvpReferenceImage>[];
    return GvpDetail(
      id: _asIntOrNull(json['id']) ?? 0,
      name: _asStringOrNull(json['name']) ?? '',
      project: _asStringOrNull(json['project']) ?? '',
      zone: _asIntOrNull(json['zone']),
      ward: _asIntOrNull(json['ward']),
      latitude: _asStringOrNull(json['latitude']),
      longitude: _asStringOrNull(json['longitude']),
      active: _asBoolOrNull(json['active'] ?? json['is_active']) ?? true,
      createdOn:
          _asStringOrNull(json['createdon'] ?? json['created_on']),
      createdBy:
          _asStringOrNull(json['createdby'] ?? json['created_by']),
      referenceImages: images,
    );
  }
}

// ─── Generic choice (project dropdown) ────────────────────────────────────────

class GvpChoice {
  final String value;
  final String label;

  const GvpChoice({required this.value, required this.label});

  /// Accepts the common Django choice shapes:
  ///   • `["TBM", "Tambaram"]`
  ///   • `{"value": "TBM", "display_name": "Tambaram"}`
  ///   • `"TBM"`
  static GvpChoice? fromDynamic(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      final s = raw.trim();
      return s.isEmpty ? null : GvpChoice(value: s, label: s);
    }
    if (raw is List && raw.isNotEmpty) {
      final value = raw[0]?.toString() ?? '';
      final label = raw.length > 1 ? (raw[1]?.toString() ?? value) : value;
      return value.isEmpty ? null : GvpChoice(value: value, label: label);
    }
    if (raw is Map) {
      final value = (raw['value'] ??
              raw['code'] ??
              raw['id'] ??
              raw['project'] ??
              '')
          .toString();
      final label = (raw['display_name'] ??
              raw['label'] ??
              raw['name'] ??
              value)
          .toString();
      return value.isEmpty ? null : GvpChoice(value: value, label: label);
    }
    return null;
  }
}

// ─── Ward choice ──────────────────────────────────────────────────────────────

class GvpWardChoice {
  final int id;
  final String code;

  const GvpWardChoice({required this.id, required this.code});

  static GvpWardChoice? fromDynamic(Object? raw) {
    if (raw == null) return null;
    if (raw is List && raw.isNotEmpty) {
      final id = _asIntOrNull(raw[0]);
      if (id == null) return null;
      final code = raw.length > 1 ? (raw[1]?.toString() ?? '$id') : '$id';
      return GvpWardChoice(id: id, code: code);
    }
    if (raw is Map) {
      final id = _asIntOrNull(
          raw['ward_id'] ?? raw['id'] ?? raw['value'] ?? raw['ward']);
      if (id == null) return null;
      final code = (raw['ward_code'] ??
              raw['code'] ??
              raw['display_name'] ??
              raw['label'] ??
              raw['name'] ??
              '$id')
          .toString();
      return GvpWardChoice(id: id, code: code);
    }
    return null;
  }
}

// ─── Zone choice (may embed its wards) ────────────────────────────────────────

class GvpZoneChoice {
  final int id;
  final String code;
  final List<GvpWardChoice> wards;

  const GvpZoneChoice({
    required this.id,
    required this.code,
    this.wards = const [],
  });

  static GvpZoneChoice? fromDynamic(Object? raw) {
    if (raw == null) return null;
    if (raw is List && raw.isNotEmpty) {
      final id = _asIntOrNull(raw[0]);
      if (id == null) return null;
      final code = raw.length > 1 ? (raw[1]?.toString() ?? '$id') : '$id';
      return GvpZoneChoice(id: id, code: code);
    }
    if (raw is Map) {
      final id = _asIntOrNull(
          raw['zone_id'] ?? raw['id'] ?? raw['value'] ?? raw['zone']);
      if (id == null) return null;
      final code = (raw['zone_code'] ??
              raw['code'] ??
              raw['display_name'] ??
              raw['label'] ??
              raw['name'] ??
              '$id')
          .toString();
      final rawWards = raw['wards'] ?? raw['ward_choices'];
      final wards = (rawWards is List)
          ? rawWards
              .map(GvpWardChoice.fromDynamic)
              .whereType<GvpWardChoice>()
              .toList()
          : <GvpWardChoice>[];
      return GvpZoneChoice(id: id, code: code, wards: wards);
    }
    return null;
  }
}

// ─── Create-form options ──────────────────────────────────────────────────────

class GvpCreateOptions {
  final List<GvpChoice> projectChoices;
  final List<GvpZoneChoice> zonalChoices;

  const GvpCreateOptions({
    required this.projectChoices,
    required this.zonalChoices,
  });

  factory GvpCreateOptions.fromJson(Map<String, dynamic> json) {
    final rawProjects = json['project_choices'];
    final rawZones = json['zonal_choices'];
    return GvpCreateOptions(
      projectChoices: (rawProjects is List)
          ? rawProjects
              .map(GvpChoice.fromDynamic)
              .whereType<GvpChoice>()
              .toList()
          : <GvpChoice>[],
      zonalChoices: (rawZones is List)
          ? rawZones
              .map(GvpZoneChoice.fromDynamic)
              .whereType<GvpZoneChoice>()
              .toList()
          : <GvpZoneChoice>[],
    );
  }
}

// ─── Drill-down status counts ─────────────────────────────────────────────────
//
// The dashboard count endpoints (by project / zone / ward) now return status-wise
// counts instead of a single `count`:
//   • NC  — Not Cleaned      (maps to the grey "NT" card state)
//   • WIP — Work In Progress
//   • C   — Cleared / Closed
// Parsing is defensive (upper/lower case, and NT as an alias for NC) so a minor
// backend key change never breaks the dashboard.

class GvpStatusCounts {
  final int nc;
  final int wip;
  final int c;

  const GvpStatusCounts({this.nc = 0, this.wip = 0, this.c = 0});

  /// Grand total across all three states.
  int get total => nc + wip + c;

  bool get isEmpty => total == 0;

  factory GvpStatusCounts.fromJson(Map<String, dynamic> json) {
    return GvpStatusCounts(
      nc: _asIntOrNull(json['NC'] ?? json['nc'] ?? json['NT'] ?? json['nt']) ?? 0,
      wip: _asIntOrNull(json['WIP'] ?? json['wip']) ?? 0,
      c: _asIntOrNull(json['C'] ?? json['c']) ?? 0,
    );
  }
}

class GvpProjectCount {
  final String project;
  final GvpStatusCounts counts;

  const GvpProjectCount({required this.project, required this.counts});

  int get total => counts.total;

  factory GvpProjectCount.fromJson(Map<String, dynamic> json) {
    return GvpProjectCount(
      project: _asStringOrNull(json['project']) ?? '',
      counts: GvpStatusCounts.fromJson(json),
    );
  }
}

class GvpZoneCount {
  final int zoneId;
  final String zoneCode;
  final GvpStatusCounts counts;

  const GvpZoneCount({
    required this.zoneId,
    required this.zoneCode,
    required this.counts,
  });

  int get total => counts.total;

  factory GvpZoneCount.fromJson(Map<String, dynamic> json) {
    return GvpZoneCount(
      zoneId: _asIntOrNull(json['zone_id']) ?? 0,
      zoneCode: _asStringOrNull(json['zone_code']) ?? '—',
      counts: GvpStatusCounts.fromJson(json),
    );
  }
}

class GvpWardCount {
  final int wardId;
  final String wardCode;
  final GvpStatusCounts counts;

  const GvpWardCount({
    required this.wardId,
    required this.wardCode,
    required this.counts,
  });

  int get total => counts.total;

  factory GvpWardCount.fromJson(Map<String, dynamic> json) {
    return GvpWardCount(
      wardId: _asIntOrNull(json['ward_id']) ?? 0,
      wardCode: _asStringOrNull(json['ward_code']) ?? '—',
      counts: GvpStatusCounts.fromJson(json),
    );
  }
}

// ─── Create / Update request payloads ─────────────────────────────────────────

class GvpCreateRequest {
  final String name;
  final String project;
  final int zone;
  final int ward;
  final String? latitude;
  final String? longitude;

  const GvpCreateRequest({
    required this.name,
    required this.project,
    required this.zone,
    required this.ward,
    this.latitude,
    this.longitude,
  });

  /// Only whitelisted fields — never the audit fields (createdon/createdby)
  /// or the read-only `reference_images`.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name.trim(),
      'project': project,
      'zone': zone,
      'ward': ward,
    };
    final lat = latitude?.trim();
    final lng = longitude?.trim();
    if (lat != null && lat.isNotEmpty) map['latitude'] = lat;
    if (lng != null && lng.isNotEmpty) map['longitude'] = lng;
    return map;
  }
}
