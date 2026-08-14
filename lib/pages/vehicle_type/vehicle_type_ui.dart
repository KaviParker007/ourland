// ─── Vehicle Type Dashboard — Shared UI ───────────────────────────────────────
//
// Reusable state widgets, breadcrumb, filter sheet, the pivot/status row card
// and colour helpers. Visual language matches the Shift / GVP dashboards.

import 'package:flutter/material.dart';

import 'vehicle_type_models.dart';
import 'vehicle_type_query.dart';
import 'vehicle_type_service.dart';

// Route names used by the breadcrumb to pop back to a specific drill level.
const String kVtDashboardRoute = '/vehicle_type_dashboard';
const String kVtZoneRoute = 'vt_zone';
const String kVtWardRoute = 'vt_ward';
const String kVtVehiclesRoute = 'vt_vehicles';

// ── Colours ─────────────────────────────────────────────────────────────────

const List<Color> _kTypePalette = [
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

/// Stable colour per vehicle type (index into the canonical list, else hashed).
Color vehicleTypeColor(String type) {
  final i = kVehicleTypes.indexOf(type);
  if (i >= 0) return _kTypePalette[i % _kTypePalette.length];
  return _kTypePalette[type.hashCode.abs() % _kTypePalette.length];
}

Color statusBucketColor(VehicleStatusBucket b) {
  switch (b) {
    case VehicleStatusBucket.total:
      return const Color(0xFF42A5F5);
    case VehicleStatusBucket.working:
      return const Color(0xFF43A047); // green
    case VehicleStatusBucket.longShift:
      return const Color(0xFFF9A825); // amber
    case VehicleStatusBucket.utilized:
      return const Color(0xFF42A5F5); // blue
    case VehicleStatusBucket.maintenance:
      return const Color(0xFFE53935); // red
    case VehicleStatusBucket.idle:
      return const Color(0xFF9E9E9E); // grey
    case VehicleStatusBucket.allIdle:
      return const Color(0xFF78909C); // blue grey
  }
}

/// Colour for the terminal list's computed vehicle_status badge.
Color vehicleStatusColor(String status) {
  switch (status.toLowerCase().trim()) {
    case 'working':
      return const Color(0xFF43A047);
    case 'long shift':
    case 'long-shift':
      return const Color(0xFFF9A825);
    case 'utilized':
      return const Color(0xFF42A5F5);
    case 'under-maintenance':
    case 'under maintenance':
    case 'maintenance':
      return const Color(0xFFE53935);
    case 'idle':
      return const Color(0xFF9E9E9E);
    case 'all idle':
    case 'all-idle':
      return const Color(0xFF78909C);
    case 'in-active':
    case 'inactive':
      return const Color(0xFFB71C1C);
    default:
      return const Color(0xFF9E9E9E);
  }
}

// ── Full-page states ──────────────────────────────────────────────────────────

class VehicleLoading extends StatelessWidget {
  const VehicleLoading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class VehicleError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const VehicleError({super.key, required this.message, required this.onRetry});

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

class VehicleEmpty extends StatelessWidget {
  final String message;
  final String? hint;
  final IconData icon;
  const VehicleEmpty({
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

/// [VehicleEmpty] hosted in an always-scrollable viewport so a wrapping
/// `RefreshIndicator` still responds to a pull — otherwise the empty state is the
/// one place the user cannot refresh out of.
class VehicleEmptyScrollable extends StatelessWidget {
  final String message;
  final String? hint;
  final IconData icon;
  const VehicleEmptyScrollable({
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
          child: VehicleEmpty(message: message, hint: hint, icon: icon),
        ),
      ),
    );
  }
}

/// Advisory shown on Screen 4 when the user arrived by tapping Chain B's `idle`
/// bucket: that bucket excludes never-operated vehicles but `vehicle_status=Idle`
/// includes them, so the list is a superset of the tapped count. Returns null for
/// every other cell.
String? idleSupersetNote(String cellValue) {
  if (cellValue != 'Idle') return null;
  return 'This list uses vehicle_status=Idle, which also includes '
      'never-operated vehicles — so it may show more than the Idle count.';
}

/// Recoverable picker shown when #2/#5 return 400 with `project_choices`.
class VehicleProjectPicker extends StatelessWidget {
  final String message;
  final List<VehicleChoice> choices;
  final ValueChanged<VehicleChoice> onPick;
  const VehicleProjectPicker({
    super.key,
    required this.message,
    required this.choices,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_outlined,
                size: 46,
                color: Theme.of(context).colorScheme.primary.withAlpha(160)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final c in choices)
                  ActionChip(
                    label: Text(c.label),
                    onPressed: () => onPick(c),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Breadcrumb ────────────────────────────────────────────────────────────────

class VehicleCrumb {
  final String label;

  /// Route name to pop back to when tapped; null = the current (last) crumb.
  final String? routeName;
  const VehicleCrumb(this.label, {this.routeName});
}

class VehicleBreadcrumb extends StatelessWidget {
  final List<VehicleCrumb> crumbs;
  const VehicleBreadcrumb({super.key, required this.crumbs});

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
                    // `r.isFirst` is a required backstop, not belt-and-braces:
                    // the dashboard is the app's launch screen, where it is the
                    // root route named '/' rather than kVtDashboardRoute. Without
                    // it this predicate would never match and popUntil would pop
                    // every route, leaving a blank app.
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

// ── Filter bar ──────────────────────────────────────────────────────────────────

/// The always-present filter summary shown under the app bar on Screens 1–4.
///
/// Non-default filters render as deletable chips; when both are at `All` a muted
/// subtitle states so, which keeps the "the user always knows what they are
/// looking at" requirement true even in the default state. The filter *editor*
/// itself is the app-bar `filter_alt` action → [showVehicleFilterSheet], which is
/// the convention every other dashboard in this app already uses.
class VehicleFilterBar extends StatelessWidget {
  final VehicleFilters filters;

  /// Receives the filters with one facet reset back to `All`.
  final void Function(VehicleFilters cleared) onClear;

  /// Opens the filter sheet — wired to the subtitle so the default state is
  /// still a 48 dp tap target rather than dead text.
  final VoidCallback? onEdit;

  const VehicleFilterBar({
    super.key,
    required this.filters,
    required this.onClear,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (!filters.hasActive) {
      return Semantics(
        label: 'Filters: all statuses, all owners. Double tap to change filters.',
        button: onEdit != null,
        child: InkWell(
          onTap: onEdit,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            alignment: Alignment.centerLeft,
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(Icons.tune_rounded,
                      size: 14, color: onSurface.withAlpha(110)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'All statuses · All owners',
                      style: TextStyle(
                          fontSize: 12, color: onSurface.withAlpha(130)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final chips = <Widget>[];
    void add(String label, String semantic, VehicleFilters cleared) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Semantics(
          label: semantic,
          child: Chip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            onDeleted: () => onClear(cleared),
            deleteButtonTooltipMessage: 'Clear $semantic',
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ));
    }

    if (filters.vehicleStatus != kAllFilterValue) {
      add(
        'Status: ${filters.vehicleStatus}',
        'status filter ${filters.vehicleStatus}',
        filters.copyWith(vehicleStatus: kAllFilterValue),
      );
    }
    if (filters.vehicleOwner != kAllFilterValue) {
      final label =
          kVehicleOwnerLabels[filters.vehicleOwner] ?? filters.vehicleOwner;
      add(
        'Owner: $label',
        'owner filter $label',
        filters.copyWith(vehicleOwner: kAllFilterValue),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      ),
    );
  }
}

// ── Filter bottom sheet ─────────────────────────────────────────────────────────

/// Shows the three-dropdown filter sheet. Returns the new [VehicleFilters] or
/// null if dismissed without applying.
Future<VehicleFilters?> showVehicleFilterSheet(
  BuildContext context,
  VehicleFilters current,
) {
  return showModalBottomSheet<VehicleFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FilterSheet(current: current),
  );
}

class _FilterSheet extends StatefulWidget {
  final VehicleFilters current;
  const _FilterSheet({required this.current});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _status = widget.current.vehicleStatus;
  late String _owner = widget.current.vehicleOwner;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: onSurface.withAlpha(60),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Filters',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 16),
          _dropdown('Vehicle Status', _status, kVehicleStatusFilters,
              (v) => setState(() => _status = v)),
          const SizedBox(height: 14),
          _dropdown(
            'Vehicle Owner',
            _owner,
            kVehicleOwners,
            (v) => setState(() => _owner = v),
            labelFor: (v) => kVehicleOwnerLabels[v] ?? v,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    const VehicleFilters(),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    VehicleFilters(
                      vehicleStatus: _status,
                      vehicleOwner: _owner,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged, {
    String Function(String)? labelFor,
  }) {
    // `initialValue` is applied once (FormFieldState does not re-apply it on
    // rebuild), which is correct here: the dropdown owns its displayed value
    // after the first build and [value] is only ever changed by its own
    // onChanged, so the two never diverge.
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map((v) => DropdownMenuItem(
                value: v,
                child: Text(labelFor != null ? labelFor(v) : v,
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ── Group section (header + one count row per type/status) ──────────────────────

/// Minimum tap-target height, per the accessibility requirement.
const double kVehicleMinTapTarget = 48;

/// Data for one `label → count` line inside a [GroupSection].
@immutable
class CountRowData {
  final String label;
  final int count;
  final Color color;

  /// Null → the row is not actionable (count is 0, or the group is a footer).
  final VoidCallback? onTap;

  const CountRowData({
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });
}

/// One `EMV    16 ›` line. Tapping opens the vehicle list narrowed to this
/// label; a zero count is de-emphasised and inert.
class TypeCountRow extends StatelessWidget {
  final CountRowData data;

  /// Named in the semantic label so screen-reader users get
  /// "MDU, EMV, 16 vehicles" rather than a bare "EMV, 16".
  final String groupLabel;

  const TypeCountRow({
    super.key,
    required this.data,
    required this.groupLabel,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final active = data.onTap != null && data.count > 0;
    final fg = active ? onSurface : onSurface.withAlpha(90);

    return Semantics(
      button: active,
      enabled: active,
      label: '$groupLabel, ${data.label}, ${data.count} '
          '${data.count == 1 ? 'vehicle' : 'vehicles'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: active ? data.onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kVehicleMinTapTarget),
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
                  child: Text(
                    data.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: fg),
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
/// followed by one [TypeCountRow] per vehicle type (Chain A) or status bucket
/// (Chain B).
///
/// The header drills to the next aggregate level (or, at ward level, straight to
/// the vehicle list); each row drills to the vehicle list narrowed to that label.
class GroupSection extends StatelessWidget {
  final String title;
  final int total;
  final Color accent;
  final List<CountRowData> rows;

  /// Null → the header is inert (used for Chain B's pinned `Total` footer).
  final VoidCallback? onHeaderTap;

  /// What the header opens, spoken to screen readers ("zones", "vehicles", …).
  final String headerTargetNoun;

  const GroupSection({
    super.key,
    required this.title,
    required this.total,
    required this.accent,
    required this.rows,
    required this.onHeaderTap,
    this.headerTargetNoun = 'details',
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
              TypeCountRow(data: rows[i], groupLabel: title),
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
      label: '$title, $total ${total == 1 ? 'vehicle' : 'vehicles'}'
          '${tappable ? '. Double tap to view $headerTargetNoun.' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onHeaderTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kVehicleMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.3),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(28),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withAlpha(110), width: 1.2),
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

// ── Section builders (shared by dashboard & drill screens) ──────────────────────

/// Chain A section. [onHeaderTap] drills to the next level (or the vehicle list
/// at ward level); [onTypeTap] opens the vehicle list for one vehicle type.
Widget buildPivotSection({
  required BuildContext context,
  required VehiclePivotRow row,
  required List<String> typeColumns,
  required VoidCallback? onHeaderTap,
  required void Function(String vehicleType) onTypeTap,
  String headerTargetNoun = 'details',
}) {
  return GroupSection(
    title: row.label,
    total: row.total,
    accent: Theme.of(context).colorScheme.primary,
    onHeaderTap: onHeaderTap,
    headerTargetNoun: headerTargetNoun,
    rows: [
      for (final t in typeColumns)
        CountRowData(
          label: t,
          count: row.count(t),
          color: vehicleTypeColor(t),
          onTap: row.count(t) > 0 ? () => onTypeTap(t) : null,
        ),
    ],
  );
}

/// Chain B section. The trailing `Total` footer row of #5 is rendered inert.
Widget buildStatusSection({
  required BuildContext context,
  required VehicleStatusRow row,
  required VoidCallback? onHeaderTap,
  required void Function(String vehicleStatus) onStatusTap,
  String headerTargetNoun = 'details',
}) {
  final isFooter = row.isTotalRow;
  return GroupSection(
    title: isFooter ? 'Total' : row.label,
    total: row.total,
    accent: isFooter
        ? const Color(0xFF78909C)
        : Theme.of(context).colorScheme.primary,
    onHeaderTap: isFooter ? null : onHeaderTap,
    headerTargetNoun: headerTargetNoun,
    rows: [
      for (final b in kStatusColumns)
        CountRowData(
          label: b.label,
          count: row.bucket(b),
          color: statusBucketColor(b),
          onTap: (!isFooter && row.bucket(b) > 0)
              ? () => onStatusTap(b.vehicleStatusValue)
              : null,
        ),
    ],
  );
}
