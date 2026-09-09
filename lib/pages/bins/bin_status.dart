// ─── Bins — status vocabulary ──────────────────────────────────────────────────
//
// The dashboard endpoints nest their counts one level below the bin type:
//
//   {"project": "MDU", "Compactor": {"12hr": 789}, "Dumper": {"12hr": 64}}
//
// Those inner keys ARE the bin statuses. So every status count on the dashboard
// comes straight from the API response — there is no separate status endpoint
// and nothing is hardcoded. This file only maps the API's short bucket keys onto
// the canonical status values the list endpoint expects, and gives each one a
// colour and icon.

import 'package:flutter/material.dart';

/// The canonical `bin_status` values, exactly as the API expects them. These are
/// what go on the wire — never a display label, never a bucket key.
const List<String> kBinStatuses = <String>[
  'Collected in 12hr',
  'Collected in 24hr',
  'Collected in 48hr',
  'Yet to collect',
  'Under Maintenance',
];

/// Strips everything but lowercase alphanumerics, so `12hr`, `12 hr`, `12_hr`
/// and `Collected in 12hr` all normalise to something comparable.
String _normalise(String raw) =>
    raw.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// Maps a bucket key from a dashboard response onto a canonical [kBinStatuses]
/// value, or returns null when it does not correspond to a known status.
///
/// Deliberately tolerant: the sample payload only ever showed `12hr`, so the
/// exact spelling of the other four buckets is not yet confirmed. Anything
/// recognisable (`24hr`, `24_hr`, `collected_in_24hr`, `yet_to_collect`,
/// `pending`, `under_maintenance`, `maintenance`) resolves; anything else is
/// returned as null by this function and preserved verbatim by the caller, so an
/// unrecognised bucket is still displayed and still drillable rather than being
/// silently dropped.
String? canonicalBinStatus(String bucketKey) {
  final k = _normalise(bucketKey);
  if (k.isEmpty) return null;

  // Word-ish matches first: 'undermaintenance' contains no digits, but checking
  // these before the hour buckets keeps a key like 'maintenance24' unambiguous.
  if (k.contains('maint')) return 'Under Maintenance';
  if (k.contains('yet') ||
      k.contains('pending') ||
      k.contains('notcollected') ||
      k.contains('uncollected') ||
      k.contains('tocollect')) {
    return 'Yet to collect';
  }

  if (k.contains('12')) return 'Collected in 12hr';
  if (k.contains('24')) return 'Collected in 24hr';
  if (k.contains('48')) return 'Collected in 48hr';

  // An exact match against a canonical value that somehow reached here.
  for (final s in kBinStatuses) {
    if (_normalise(s) == k) return s;
  }
  return null;
}

/// Compact label for a stat card or chip — the full value is long and repetitive
/// across five cards, so the shared prefix is dropped for display only. The API
/// always receives the canonical value.
String binStatusShortLabel(String status) {
  switch (status) {
    case 'Collected in 12hr':
      return '12 hr';
    case 'Collected in 24hr':
      return '24 hr';
    case 'Collected in 48hr':
      return '48 hr';
    case 'Yet to collect':
      return 'Yet to collect';
    case 'Under Maintenance':
      return 'Maintenance';
    default:
      return status;
  }
}

/// True for the three "collected within N hours" buckets, which share a heading
/// on the status screen.
bool isCollectedStatus(String status) => status.startsWith('Collected in');

/// Status colour, in the same family as the app's vehicle-status palette:
/// green = healthy, amber = ageing, red = needs attention, grey = out of service.
Color binStatusColor(String status) {
  switch (status) {
    case 'Collected in 12hr':
      return const Color(0xFF43A047); // green
    case 'Collected in 24hr':
      return const Color(0xFF9CCC65); // light green
    case 'Collected in 48hr':
      return const Color(0xFFF9A825); // amber
    case 'Yet to collect':
      return const Color(0xFFE53935); // red
    case 'Under Maintenance':
      return const Color(0xFF78909C); // blue grey
    default:
      return const Color(0xFF42A5F5); // blue, for an unrecognised bucket
  }
}

IconData binStatusIcon(String status) {
  switch (status) {
    case 'Collected in 12hr':
      return Icons.check_circle_rounded;
    case 'Collected in 24hr':
      return Icons.check_circle_outline_rounded;
    case 'Collected in 48hr':
      return Icons.history_rounded;
    case 'Yet to collect':
      return Icons.error_outline;
    case 'Under Maintenance':
      return Icons.handyman_rounded;
    default:
      return Icons.label_outline_rounded;
  }
}

/// Orders a set of status keys: the five canonical ones in their documented
/// order, then any unrecognised buckets alphabetically so nothing is hidden.
List<String> orderBinStatuses(Iterable<String> present) {
  final set = present.toSet();
  final known = [
    for (final s in kBinStatuses)
      if (set.contains(s)) s
  ];
  final extras = set.where((s) => !kBinStatuses.contains(s)).toList()..sort();
  return [...known, ...extras];
}
