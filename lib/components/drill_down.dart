// ─── Shared drill-down kit ─────────────────────────────────────────────────────
//
// The Project → Zone → Ward → leaf-list pattern is used by several dashboards
// (Vehicle Type, Bins, Collections). Everything in this file is deliberately
// domain-agnostic: it renders "a group of label → count rows" plus the four page
// states, and knows nothing about vehicles, bins or collections.
//
// The Vehicle Type module re-exports these under its historical `Vehicle*` names
// (see vehicle_type_ui.dart), so both naming styles resolve to one implementation.

import 'package:flutter/material.dart';

/// Minimum tap-target size, per the accessibility requirement.
const double kDashMinTapTarget = 48;

/// Width below which a layout should switch to its compact/stacked form.
/// Phones sit under this; tablets and desktop above it.
const double kDashCompactWidth = 600;

/// Width above which content is centred rather than stretched, so a desktop
/// window does not render absurdly long rows.
const double kDashMaxContentWidth = 900;

// ── Full-page states ──────────────────────────────────────────────────────────

class DashLoading extends StatelessWidget {
  const DashLoading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class DashError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const DashError({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(160))),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class DashEmpty extends StatelessWidget {
  final String message;
  final String? hint;
  final IconData icon;
  const DashEmpty({
    super.key,
    required this.message,
    this.hint,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 56,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(70)),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(120))),
            ],
          ],
        ),
      ),
    );
  }
}

/// [DashEmpty] hosted in an always-scrollable viewport so a wrapping
/// `RefreshIndicator` still responds to a pull — otherwise the empty state is the
/// one place the user cannot refresh out of.
class DashEmptyScrollable extends StatelessWidget {
  final String message;
  final String? hint;
  final IconData icon;
  const DashEmptyScrollable({
    super.key,
    required this.message,
    this.hint,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: DashEmpty(message: message, hint: hint, icon: icon),
        ),
      ),
    );
  }
}

// ── Breadcrumb ────────────────────────────────────────────────────────────────

class DashCrumb {
  final String label;

  /// Route name to pop back to when tapped; null = the current (last) crumb.
  final String? routeName;
  const DashCrumb(this.label, {this.routeName});
}

class DashBreadcrumb extends StatelessWidget {
  final List<DashCrumb> crumbs;
  const DashBreadcrumb({super.key, required this.crumbs});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < crumbs.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 16, color: onSurface.withAlpha(90)),
                ),
              GestureDetector(
                onTap: crumbs[i].routeName == null
                    ? null
                    // `r.isFirst` is a required backstop, not belt-and-braces: a
                    // dashboard mounted as the app launch screen is the root
                    // route named '/', not its own named route. Without it this
                    // predicate would never match and popUntil would pop every
                    // route, leaving a blank app.
                    : () => Navigator.of(context).popUntil((r) =>
                        r.settings.name == crumbs[i].routeName || r.isFirst),
                child: Text(
                  crumbs[i].label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: i == crumbs.length - 1
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: crumbs[i].routeName == null
                        ? onSurface.withAlpha(200)
                        : primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Group section (header + one count row per label) ──────────────────────────

/// Data for one `label → count` line inside a [GroupSection].
@immutable
class CountRowData {
  final String label;
  final int count;
  final Color color;

  /// Optional secondary line, e.g. a bin type's per-capacity breakdown
  /// (`12hr 789`). Rendered small and muted under the label.
  final String? caption;

  /// Null → the row is not actionable (count is 0, or the group is a footer).
  final VoidCallback? onTap;

  const CountRowData({
    required this.label,
    required this.count,
    required this.color,
    this.caption,
    this.onTap,
  });
}

/// One `Compactor    789 ›` line. Tapping drills into whatever the host screen
/// decides; a zero count is de-emphasised and inert.
class TypeCountRow extends StatelessWidget {
  final CountRowData data;

  /// Named in the semantic label so screen-reader users get
  /// "MDU, Compactor, 789 bins" rather than a bare "Compactor, 789".
  final String groupLabel;

  /// Noun used in the semantic label ("vehicles", "bins", "collections").
  final String unitNoun;

  const TypeCountRow({
    super.key,
    required this.data,
    required this.groupLabel,
    this.unitNoun = 'items',
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final active = data.onTap != null && data.count > 0;
    final fg = active ? onSurface : onSurface.withAlpha(90);

    return Semantics(
      button: active,
      enabled: active,
      label: '$groupLabel, ${data.label}, ${data.count} $unitNoun'
          '${data.caption == null ? '' : ', ${data.caption}'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: active ? data.onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kDashMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? data.color : data.color.withAlpha(70),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: fg),
                      ),
                      if (data.caption != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          data.caption!,
                          style: TextStyle(
                              fontSize: 11,
                              color: onSurface.withAlpha(active ? 120 : 70)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${data.count}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: active ? data.color : onSurface.withAlpha(80),
                  ),
                ),
                SizedBox(
                  width: 22,
                  child: active
                      ? Icon(Icons.chevron_right_rounded,
                          size: 18, color: onSurface.withAlpha(110))
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A project / zone / ward group: a tappable header carrying the group total,
/// followed by one [TypeCountRow] per type.
///
/// The header drills to the next aggregate level (or, at the deepest level,
/// straight to the leaf list); each row drills to the leaf list narrowed to that
/// label.
class GroupSection extends StatelessWidget {
  final String title;
  final int total;
  final Color accent;
  final List<CountRowData> rows;

  /// Null → the header is inert (used for pinned `Total` footers).
  final VoidCallback? onHeaderTap;

  /// What the header opens, spoken to screen readers ("zones", "bins", …).
  final String headerTargetNoun;

  /// Noun for the counts themselves ("vehicles", "bins", "collections").
  final String unitNoun;

  /// Optional muted line under the title, e.g. an unassigned-zone note.
  final String? subtitle;

  const GroupSection({
    super.key,
    required this.title,
    required this.total,
    required this.accent,
    required this.rows,
    required this.onHeaderTap,
    this.headerTargetNoun = 'details',
    this.unitNoun = 'items',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, onSurface),
            if (rows.isNotEmpty)
              Divider(height: 1, thickness: 1, color: onSurface.withAlpha(20)),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 14,
                  endIndent: 14,
                  color: onSurface.withAlpha(12),
                ),
              TypeCountRow(
                data: rows[i],
                groupLabel: title,
                unitNoun: unitNoun,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Color onSurface) {
    final tappable = onHeaderTap != null;
    return Semantics(
      header: true,
      button: tappable,
      enabled: tappable,
      label: '$title, $total $unitNoun'
          '${subtitle == null ? '' : ', $subtitle'}'
          '${tappable ? '. Double tap to view $headerTargetNoun.' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onHeaderTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kDashMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.3),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                              fontSize: 11, color: onSurface.withAlpha(130)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(28),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: accent.withAlpha(110), width: 1.2),
                  ),
                  child: Text(
                    '$total',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                SizedBox(
                  width: 26,
                  child: tappable
                      ? Icon(Icons.chevron_right_rounded,
                          size: 22, color: onSurface.withAlpha(120))
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Responsive shell ──────────────────────────────────────────────────────────

/// Centres and width-caps content so the same sliver list reads well on a phone,
/// a tablet and a desktop window without any overflow.
class DashContentWidth extends StatelessWidget {
  final Widget child;
  const DashContentWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kDashMaxContentWidth),
        child: child,
      ),
    );
  }
}

// ── Category colours ──────────────────────────────────────────────────────────

/// One shared palette for open-ended category sets (bin types, vehicle types),
/// so the same label gets the same colour across modules.
const List<Color> kDashCategoryPalette = [
  Color(0xFFFF7043), // deep orange
  Color(0xFF42A5F5), // blue
  Color(0xFF66BB6A), // green
  Color(0xFFAB47BC), // purple
  Color(0xFF26C6DA), // cyan
  Color(0xFFFFCA28), // amber
  Color(0xFFEC407A), // pink
  Color(0xFF8D6E63), // brown
  Color(0xFF7E57C2), // deep purple
  Color(0xFF29B6F6), // light blue
  Color(0xFF9CCC65), // light green
  Color(0xFFFFA726), // orange
  Color(0xFF5C6BC0), // indigo
  Color(0xFF78909C), // blue grey
];

/// Colour for [key], stable across rebuilds. [known] gives a canonical ordering
/// so common categories get distinct, predictable colours; anything outside it is
/// hashed into the same palette.
Color dashCategoryColor(String key, {List<String> known = const []}) {
  final i = known.indexOf(key);
  if (i >= 0) return kDashCategoryPalette[i % kDashCategoryPalette.length];
  return kDashCategoryPalette[key.hashCode.abs() % kDashCategoryPalette.length];
}
