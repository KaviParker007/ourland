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
          label: 'NT',
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
