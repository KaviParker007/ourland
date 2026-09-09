// ─── Collections — aggregate DTOs ──────────────────────────────────────────────
//
// The leaf-list record lives in models/bin_record.dart, shared with the Bins
// module (both list endpoints return the same shape). This file only covers the
// collection dashboard responses, whose counts are flat:
//
//   {"project": "MDU", "Compactor": 10, "Dumper": 1}

import 'package:flutter/foundation.dart';

import 'package:ourlandnew/models/json_parse.dart';

/// Keys that identify a group rather than a bin-type count column.
const Set<String> _kGroupMetaKeys = {
  'project',
  'zone',
  'zone_id',
  'ward',
  'ward_id',
  'total',
};

/// One group in a collection dashboard response.
@immutable
class CollectionGroupRow {
  /// project code / zone code / ward code.
  final String label;

  /// `zone_id` / `ward_id` when the response carries one. Null at project level,
  /// and null for the unassigned bucket — see [isUnassigned].
  final int? id;

  /// True when this group holds collections with no zone/ward assigned; the
  /// drill-down then omits the id parameter.
  final bool isUnassigned;

  /// bin type → count.
  final Map<String, int> countsByType;

  const CollectionGroupRow({
    required this.label,
    this.id,
    this.isUnassigned = false,
    this.countsByType = const {},
  });

  int count(String type) => countsByType[type] ?? 0;

  int get total => countsByType.values.fold(0, (a, b) => a + b);

  /// [labelKey] is `project` / `zone` / `ward`; [idKey] the matching id field.
  ///
  /// The by-zone response documents no `zone_id`, so [idKey] may be absent even
  /// at zone level — [id] is then null and the drill-down omits the parameter,
  /// which is the documented "without a zone" behaviour.
  factory CollectionGroupRow.fromJson(
    Map<String, dynamic> json, {
    required String labelKey,
    String? idKey,
  }) {
    final counts = <String, int>{};
    json.forEach((key, value) {
      if (key == labelKey || key == idKey) return;
      if (_kGroupMetaKeys.contains(key)) return;
      // Tolerate a nested {bucket: n} shape as well as a flat number, so a
      // backend change to match the bins dashboards cannot blank the screen.
      if (value is num) {
        counts[key] = value.toInt();
      } else if (value is Map) {
        var sum = 0;
        var sawOne = false;
        value.forEach((_, v) {
          final n = asIntOrNull(v);
          if (n != null) {
            sum += n;
            sawOne = true;
          }
        });
        if (sawOne) counts[key] = sum;
      }
    });

    // "Unassigned" only means anything below project level — the project
    // dashboard has no ids, so a nameless project row is just unknown ('—').
    final hasIdConcept = idKey != null;
    final parsedId = hasIdConcept ? asIntOrNull(json[idKey]) : null;
    final unassigned = hasIdConcept && (parsedId == null || parsedId == 0);

    return CollectionGroupRow(
      label: asStringOrNull(json[labelKey]) ?? (unassigned ? 'Unassigned' : '—'),
      id: unassigned ? null : parsedId,
      isUnassigned: unassigned,
      countsByType: counts,
    );
  }
}

/// The union of bin-type keys across [rows], ordered by [canonicalOrder] first
/// then any extras alphabetically, so every group renders the same row set.
List<String> unionCollectionTypes(
  List<CollectionGroupRow> rows,
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
