// ─── GVP Module — Reusable GVP card ───────────────────────────────────────────
//
// One card used by both the GVP List and the Queried GVP List. Actions are
// opt-in: pass a callback to show that action, omit it to hide the button.

import 'package:flutter/material.dart';
import 'gvp_models.dart';
import 'gvp_status.dart';

class GvpCard extends StatelessWidget {
  final Gvp gvp;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onImages;

  /// Resolved zone/ward names. When null, the numeric ID is shown as a fallback.
  final String? zoneName;
  final String? wardName;

  /// When true, the daily cleaning status pill is shown in the header. Set on
  /// the Dashboard / GVP List where today_status drives colour + swipe.
  final bool showStatus;

  const GvpCard({
    super.key,
    required this.gvp,
    this.onView,
    this.onEdit,
    this.onImages,
    this.zoneName,
    this.wardName,
    this.showStatus = false,
  });

  bool get _showStatus =>
      showStatus && gvp.todayStatus != GvpTodayStatus.unknown;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    // When status is shown, the whole card adopts the cleaning-state colour
    // (NT grey / WIP amber / C green): a tinted surface, a coloured border and
    // a stronger header band, so each state is distinct at a glance.
    final accent =
        _showStatus ? GvpStatusStyle.of(gvp.todayStatus).color : primary;
    final cardColor =
        _showStatus ? Color.alphaBlend(accent.withAlpha(28), surface) : null;
    final headerBand = _showStatus ? accent.withAlpha(40) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: _showStatus
            ? BorderSide(color: accent.withAlpha(150), width: 1.4)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: InkWell(
        onTap: onView,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — name + project badge
            Container(
              decoration: BoxDecoration(
                color: headerBand,
                border: Border(left: BorderSide(color: accent, width: 4)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_sweep_outlined,
                        size: 18, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gvp.name.isEmpty ? '—' : gvp.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (_showStatus) ...[
                          const SizedBox(height: 6),
                          GvpStatusBadge(status: gvp.todayStatus),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (gvp.project.isNotEmpty)
                    _Badge(label: gvp.project, color: primary),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withAlpha(12)),

            // Info — zone / ward
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.location_city_outlined,
                      label: 'Zone',
                      value: zoneName ?? gvp.zone?.toString() ?? '—',
                    ),
                  ),
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.map_outlined,
                      label: 'Ward',
                      value: wardName ?? gvp.ward?.toString() ?? '—',
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            if (onView != null || onEdit != null || onImages != null) ...[
              Divider(height: 1, color: Colors.white.withAlpha(12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    if (onView != null)
                      _ActionButton(
                        icon: Icons.visibility_outlined,
                        label: 'View',
                        color: primary,
                        onTap: onView!,
                      ),
                    if (onEdit != null)
                      _ActionButton(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        color: onSurface.withAlpha(200),
                        onTap: onEdit!,
                      ),
                    if (onImages != null)
                      _ActionButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Images',
                        color: onSurface.withAlpha(200),
                        onTap: onImages!,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(110), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 15, color: onSurface.withAlpha(130)),
        const SizedBox(width: 6),
        Text(
          '$label:',
          style: TextStyle(fontSize: 12, color: onSurface.withAlpha(130)),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: muted ? onSurface.withAlpha(110) : onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17, color: color),
        label: Text(
          label,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        ),
      ),
    );
  }
}
