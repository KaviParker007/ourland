// ─── Vehicle Type Dashboard — Shared UI ───────────────────────────────────────
//
// Reusable state widgets, breadcrumb, filter sheet, the pivot/status row card
// and colour helpers. Visual language matches the Shift / GVP dashboards.

import 'package:flutter/material.dart';

import 'vehicle_type_models.dart';
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
                    : () => Navigator.of(context).popUntil(
                        (r) => r.settings.name == crumbs[i].routeName),
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

// ── Active-filter chips ─────────────────────────────────────────────────────────

class VehicleFilterChips extends StatelessWidget {
  final VehicleFilters filters;
  final void Function(VehicleFilters cleared) onClear;
  const VehicleFilterChips({
    super.key,
    required this.filters,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (!filters.hasActive) return const SizedBox.shrink();
    final chips = <Widget>[];
    void add(String label, VehicleFilters cleared) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Chip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          onDeleted: () => onClear(cleared),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ));
    }

    if (filters.vehicleStatus != 'All') {
      add('Status: ${filters.vehicleStatus}',
          filters.copyWith(vehicleStatus: 'All'));
    }
    if (filters.vehicleOwner != 'All') {
      add('Owner: ${kVehicleOwnerLabels[filters.vehicleOwner] ?? filters.vehicleOwner}',
          filters.copyWith(vehicleOwner: 'All'));
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
    return DropdownButtonFormField<String>(
      value: value,
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

// ── Row card (shared by pivot & status levels) ──────────────────────────────────

class VehicleCellChip {
  final String label;
  final int count;
  final Color color;

  /// Null when the cell is 0 → de-emphasised and non-tappable.
  final VoidCallback? onTap;
  const VehicleCellChip({
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });
}

class VehicleRowCard extends StatelessWidget {
  final String label;
  final int total;
  final Color accent;
  final List<VehicleCellChip> chips;

  /// Drill by the whole row (vehicle_type=All / vehicle_status=All).
  final VoidCallback onRowTap;

  /// Shown when the row drills to a deeper level (hidden for the Total footer).
  final bool showChevron;

  const VehicleRowCard({
    super.key,
    required this.label,
    required this.total,
    required this.accent,
    required this.chips,
    required this.onRowTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: InkWell(
        onTap: onRowTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.3),
                    ),
                  ),
                  // Total badge (row-level drill = All).
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(28),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: accent.withAlpha(110), width: 1.2),
                    ),
                    child: Text('$total',
                        style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  if (showChevron)
                    Icon(Icons.chevron_right_rounded,
                        size: 22, color: onSurface.withAlpha(120)),
                ],
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: chips.map(_buildChip).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(VehicleCellChip chip) {
    final active = chip.onTap != null && chip.count > 0;
    final fg = active ? chip.color : chip.color.withAlpha(110);
    return GestureDetector(
      onTap: active ? chip.onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: chip.color.withAlpha(active ? 24 : 10),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: chip.color.withAlpha(active ? 90 : 40), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            Text('${chip.label}  ${chip.count}',
                style: TextStyle(
                    color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Row-card builders (shared by dashboard & drill screens) ────────────────────

/// Builds a pivot (Chain A) row card. [onDrill] receives the tapped vehicle_type
/// ('All' when the row label/total is tapped).
Widget buildPivotCard({
  required BuildContext context,
  required VehiclePivotRow row,
  required List<String> typeColumns,
  required void Function(String vehicleType) onDrill,
}) {
  final primary = Theme.of(context).colorScheme.primary;
  final chips = [
    for (final t in typeColumns)
      VehicleCellChip(
        label: t,
        count: row.count(t),
        color: vehicleTypeColor(t),
        onTap: row.count(t) > 0 ? () => onDrill(t) : null,
      ),
  ];
  return VehicleRowCard(
    label: row.label,
    total: row.total,
    accent: primary,
    chips: chips,
    onRowTap: () => onDrill('All'),
  );
}

/// Builds a status (Chain B) row card. [onDrill] receives the vehicle_status
/// value ('All' when the row label/total is tapped). The Total footer row of #5
/// is rendered non-tappable.
Widget buildStatusCard({
  required BuildContext context,
  required VehicleStatusRow row,
  required void Function(String vehicleStatus) onDrill,
}) {
  final primary = Theme.of(context).colorScheme.primary;
  final isFooter = row.isTotalRow;
  final chips = [
    for (final b in kStatusColumns)
      VehicleCellChip(
        label: b.label,
        count: row.bucket(b),
        color: statusBucketColor(b),
        onTap: (!isFooter && row.bucket(b) > 0)
            ? () => onDrill(b.vehicleStatusValue)
            : null,
      ),
  ];
  return VehicleRowCard(
    label: isFooter ? 'Total' : row.label,
    total: row.total,
    accent: isFooter ? const Color(0xFF78909C) : primary,
    chips: chips,
    onRowTap: isFooter ? () {} : () => onDrill('All'),
    showChevron: !isFooter,
  );
}
