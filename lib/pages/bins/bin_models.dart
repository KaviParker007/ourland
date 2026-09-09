// ─── Bins — aggregate DTOs ─────────────────────────────────────────────────────
//
// The leaf-list record lives in models/bin_record.dart because the bins and
// collections list endpoints return the same shape. This file only covers the
// dashboard (project / zone / ward) responses.

import 'package:flutter/foundation.dart';

import 'package:ourlandnew/models/json_parse.dart';

import 'bin_status.dart';

/// Keys that identify a group rather than a bin-type bucket, so they are never
/// mistaken for a count column.
const Set<String> _kGroupMetaKeys = {
  'project',
  'zone',
  'zone_id',
  'ward',
  'ward_id',
  'total',
};

/// One group in a bin dashboard response.
///
/// The bin dashboards nest their counts one level deeper than a plain pivot:
///
///   {"project": "MDU", "Compactor": {"12hr": 789}, "Dumper": {"12hr": 64}}
///
/// so each bin type carries a map of sub-buckets (capacity / service window) →
/// count. [count] sums a type's buckets and [captionFor] renders the breakdown.
@immutable
class BinGroupRow {
  /// project code / zone code / ward code.
  final String label;

  /// `zone_id` / `ward_id`. Null at project level, and null when the group is
  /// the unassigned bucket — see [isUnassigned].
  final int? id;

  /// True when this group holds records with no zone/ward assigned. The
  /// drill-down then omits the id parameter, which is how the endpoints express
  /// "without a zone".
  final bool isUnassigned;

  /// bin type → (bucket label → count).
  final Map<String, Map<String, int>> countsByType;

  const BinGroupRow({
    required this.label,
    this.id,
    this.isUnassigned = false,
    this.countsByType = const {},
  });

  /// Total for [type] across its buckets — never throws on a missing key.
  int count(String type) {
    final buckets = countsByType[type];
    if (buckets == null) return 0;
    return buckets.values.fold(0, (a, b) => a + b);
  }

  /// Total across every type.
  int get total => countsByType.keys.fold(0, (sum, type) => sum + count(type));

  /// Counts for [type] re-keyed onto the canonical [kBinStatuses] values.
  ///
  /// The raw bucket keys are the API's short spellings (`12hr`); this maps them
  /// onto the values the list endpoint expects (`Collected in 12hr`) so the UI
  /// can send them straight back. A bucket that maps to no known status is kept
  /// under its raw key rather than dropped, so an unrecognised one still shows
  /// and is still drillable.
  Map<String, int> statusCountsFor(String type) {
    final out = <String, int>{};
    final buckets = countsByType[type];
    if (buckets == null) return out;
    buckets.forEach((rawKey, value) {
      if (rawKey.isEmpty) return;
      final status = canonicalBinStatus(rawKey) ?? rawKey;
      out[status] = (out[status] ?? 0) + value;
    });
    return out;
  }

  /// Status counts summed across every bin type in this group.
  Map<String, int> get statusCountsAll {
    final out = <String, int>{};
    for (final type in countsByType.keys) {
      statusCountsFor(type).forEach((status, value) {
        out[status] = (out[status] ?? 0) + value;
      });
    }
    return out;
  }

  /// `12 hr 789 · Yet to collect 12` — the per-status breakdown for [type],
  /// shown under the row label. Null when there is nothing extra to say (no
  /// buckets, or a single unnamed one), so the row stays clean.
  String? captionFor(String type) {
    final buckets = countsByType[type];
    if (buckets == null || buckets.isEmpty) return null;
    if (buckets.length == 1 && buckets.keys.first.isEmpty) return null;
    final counts = statusCountsFor(type);
    if (counts.isEmpty) return null;
    return orderBinStatuses(counts.keys)
        .map((s) => '${binStatusShortLabel(s)} ${counts[s]}')
        .join(' · ');
  }

  /// [labelKey] is `project` / `zone` / `ward`; [idKey] the matching id field
  /// (absent at project level).
  factory BinGroupRow.fromJson(
    Map<String, dynamic> json, {
    required String labelKey,
    String? idKey,
  }) {
    final counts = <String, Map<String, int>>{};

    json.forEach((key, value) {
      if (key == labelKey || key == idKey) return;
      if (_kGroupMetaKeys.contains(key)) return;

      if (value is Map) {
        // The documented shape: {"12hr": 789}
        final buckets = <String, int>{};
        value.forEach((bucketKey, bucketValue) {
          final n = asIntOrNull(bucketValue);
          if (n != null) buckets[bucketKey.toString()] = n;
        });
        if (buckets.isNotEmpty) counts[key] = buckets;
      } else if (value is num) {
        // Tolerated fallback: a flat count instead of a nested map.
        counts[key] = {'': value.toInt()};
      }
    });

    final rawId = idKey == null ? null : json[idKey];
    final parsedId = asIntOrNull(rawId);
    // A zone/ward group with no usable id is the unassigned bucket. `0` is the
    // documented alternative spelling of that, so it is treated the same.
    final unassigned = idKey != null && (parsedId == null || parsedId == 0);

    return BinGroupRow(
      label: asStringOrNull(json[labelKey]) ?? (unassigned ? 'Unassigned' : '—'),
      id: unassigned ? null : parsedId,
      isUnassigned: unassigned,
      countsByType: counts,
    );
  }
}

/// The union of bin-type keys across [rows], ordered by [canonicalOrder] first
/// and then any extras alphabetically, so every group renders the same row set
/// (a type absent from one group shows 0 rather than vanishing).
List<String> unionBinTypes(
  List<BinGroupRow> rows,
  List<String> canonicalOrder,
) {
  final present = <String>{};
  for (final r in rows) {
    present.addAll(r.countsByType.keys);
  }
  final ordered = [
    for (final t in canonicalOrder)
      if (present.contains(t)) t
  ];
  final extras = present.where((t) => !canonicalOrder.contains(t)).toList()
    ..sort();
  return [...ordered, ...extras];
}

/// Status counts summed across every group in [rows] — the figures behind the
/// dashboard's status summary cards. Entirely derived from the API response.
Map<String, int> aggregateStatusCounts(List<BinGroupRow> rows) {
  final out = <String, int>{};
  for (final row in rows) {
    row.statusCountsAll.forEach((status, value) {
      out[status] = (out[status] ?? 0) + value;
    });
  }
  return out;
}
