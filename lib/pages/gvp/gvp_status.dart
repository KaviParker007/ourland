// ─── GVP Module — today_status visual mapping ─────────────────────────────────
//
// Single source of truth for how a GVP's daily cleaning status looks in the UI.
// Colour scheme per spec:  NT → Grey, WIP → Yellow (amber), C → Green.

import 'package:flutter/material.dart';
import 'gvp_models.dart';

class GvpStatusStyle {
  final Color color;
  final String label;
  final IconData icon;

  const GvpStatusStyle({
    required this.color,
    required this.label,
    required this.icon,
  });

  static GvpStatusStyle of(GvpTodayStatus status) {
    switch (status) {
      case GvpTodayStatus.nt:
        return const GvpStatusStyle(
          color: Color(0xFF9E9E9E), // grey
          label: 'NC',
          icon: Icons.radio_button_unchecked,
        );
      case GvpTodayStatus.wip:
        return const GvpStatusStyle(
          color: Color(0xFFF9A825), // amber / yellow
          label: 'WIP',
          icon: Icons.timelapse_rounded,
        );
      case GvpTodayStatus.cleared:
        return const GvpStatusStyle(
          color: Color(0xFF43A047), // green
          label: 'Closed',
          icon: Icons.check_circle_rounded,
        );
      case GvpTodayStatus.unknown:
        return const GvpStatusStyle(
          color: Color(0xFF9E9E9E),
          label: 'Unknown',
          icon: Icons.help_outline_rounded,
        );
    }
  }
}

// ── Status pill shown on the GVP card header ──────────────────────────────────

class GvpStatusBadge extends StatelessWidget {
  final GvpTodayStatus status;

  const GvpStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = GvpStatusStyle.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withAlpha(120), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 13, color: style.color),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              color: style.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status-count breakdown (NC / WIP / C) ─────────────────────────────────────
//
// Shown on every dashboard level (project / zone / ward) in place of the old
// single total. Uses a Wrap so it never overflows on narrow tablet columns.

const List<(GvpTodayStatus, String)> _kCountOrder = [
  (GvpTodayStatus.nt, 'NC'),
  (GvpTodayStatus.wip, 'WIP'),
  (GvpTodayStatus.cleared, 'C'),
];

class GvpStatusCountsBar extends StatelessWidget {
  final GvpStatusCounts counts;

  /// Compact variant (smaller pills) for the denser zone / ward rows.
  final bool compact;

  const GvpStatusCountsBar({
    super.key,
    required this.counts,
    this.compact = false,
  });

  int _valueFor(GvpTodayStatus s) {
    switch (s) {
      case GvpTodayStatus.nt:
        return counts.nc;
      case GvpTodayStatus.wip:
        return counts.wip;
      case GvpTodayStatus.cleared:
        return counts.c;
      case GvpTodayStatus.unknown:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: 4,
      children: _kCountOrder.map((entry) {
        final color = GvpStatusStyle.of(entry.$1).color;
        return _CountChip(
          label: entry.$2,
          value: _valueFor(entry.$1),
          color: color,
          compact: compact,
        );
      }).toList(),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool compact;

  const _CountChip({
    required this.label,
    required this.value,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    // Zero counts are de-emphasised so the eye lands on active work.
    final active = value > 0;
    final fg = active ? color : color.withAlpha(120);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(active ? 26 : 12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(active ? 100 : 45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            '$label $value',
            style: TextStyle(
              color: fg,
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
