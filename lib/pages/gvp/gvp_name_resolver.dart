// ─── GVP Module — Zone / Ward name resolver ───────────────────────────────────
//
// The GVP list / detail APIs return zone and ward as numeric IDs only. This
// cached resolver maps those IDs to their human-readable codes/names using the
// data the module already has access to:
//   • zone names  ← `drf_gvp_create` (zonal_choices)
//   • ward names  ← `drf_gvp_by_ward?zone=<id>` (or wards embedded in a zone)
//
// Everything is cached process-wide so drilling around the module doesn't
// refetch. Lookups are synchronous and fall back to a readable placeholder
// ("Zone 10" / "Ward 25") until the real name has been loaded.

import 'gvp_models.dart';
import 'gvp_service.dart';

class GvpNameResolver {
  GvpNameResolver._();
  static final GvpNameResolver instance = GvpNameResolver._();

  final GvpService _service = GvpService.instance;

  final Map<int, String> _zoneNames = {};
  final Map<int, String> _wardNames = {};

  bool _zonesLoaded = false;
  final Set<int> _wardZonesLoaded = {};

  // ── Registration (seed the cache from data a screen already fetched) ──────────

  void registerZoneChoices(List<GvpZoneChoice> zones) {
    for (final z in zones) {
      _zoneNames[z.id] = z.code;
      for (final w in z.wards) {
        _wardNames[w.id] = w.code;
      }
    }
    if (zones.isNotEmpty) _zonesLoaded = true;
  }

  void registerZone(int? id, String? name) {
    if (id != null && name != null && name.isNotEmpty) _zoneNames[id] = name;
  }

  void registerWard(int? id, String? name) {
    if (id != null && name != null && name.isNotEmpty) _wardNames[id] = name;
  }

  // ── Ensure data is loaded ─────────────────────────────────────────────────────

  /// Loads all zone names once (via the create-form options endpoint).
  Future<void> ensureZones() async {
    if (_zonesLoaded) return;
    try {
      final opts = await _service.getGvpCreateOptions();
      registerZoneChoices(opts.zonalChoices);
      _zonesLoaded = true;
    } on GvpApiException {
      // Non-fatal: lookups will fall back to placeholders.
    }
  }

  /// Loads (and caches) the ward names for a single zone.
  Future<void> ensureWardsForZone(int zoneId) async {
    if (_wardZonesLoaded.contains(zoneId)) return;
    try {
      final wards = await _service.getGvpCountByWard(zoneId: zoneId);
      for (final w in wards) {
        _wardNames[w.wardId] = w.wardCode;
      }
      _wardZonesLoaded.add(zoneId);
    } on GvpApiException {
      // Non-fatal: lookups will fall back to placeholders.
    }
  }

  /// Ensures ward names are available for every distinct zone in [zoneIds].
  Future<void> ensureWardsForZones(Iterable<int> zoneIds) async {
    final pending =
        zoneIds.toSet().where((z) => !_wardZonesLoaded.contains(z));
    for (final z in pending) {
      await ensureWardsForZone(z);
    }
  }

  // ── Synchronous lookups (with readable fallbacks) ─────────────────────────────

  String zoneName(int? id) {
    if (id == null) return '—';
    return _zoneNames[id] ?? 'Zone $id';
  }

  String wardName(int? id) {
    if (id == null) return '—';
    return _wardNames[id] ?? 'Ward $id';
  }
}
