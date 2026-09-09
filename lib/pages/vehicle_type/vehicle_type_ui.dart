// ─── Vehicle Type Dashboard — Shared UI ───────────────────────────────────────
//
// Vehicle-specific UI: the status/owner filter bar and sheet, the project picker,
// status colours and the two section builders.
//
// The generic drill-down pieces (page states, breadcrumb, GroupSection /
// TypeCountRow) now live in components/drill_down.dart so the Bins and
// Collections modules share one implementation. They are re-exported here, and
// the `Vehicle*` aliases below keep this module's original names working.

import 'package:flutter/material.dart';

import 'package:ourlandnew/components/drill_down.dart';

import 'vehicle_type_models.dart';
import 'vehicle_type_query.dart';
import 'vehicle_type_service.dart';

export 'package:ourlandnew/components/drill_down.dart';

// Route names used by the breadcrumb to pop back to a specific drill level.
const String kVtDashboardRoute = '/vehicle_type_dashboard';
const String kVtZoneRoute = 'vt_zone';
const String kVtWardRoute = 'vt_ward';
const String kVtVehiclesRoute = 'vt_vehicles';

// ── Aliases onto the shared drill-down kit ──────────────────────────────────────
//
// This module was written before the kit was extracted; these keep its call
// sites and tests unchanged while there is only one implementation underneath.

typedef VehicleLoading = DashLoading;
typedef VehicleError = DashError;
typedef VehicleEmpty = DashEmpty;
typedef VehicleEmptyScrollable = DashEmptyScrollable;
typedef VehicleCrumb = DashCrumb;
typedef VehicleBreadcrumb = DashBreadcrumb;

const double kVehicleMinTapTarget = kDashMinTapTarget;

// ── Colours ─────────────────────────────────────────────────────────────────

/// Stable colour per vehicle type, from the shared category palette.
Color vehicleTypeColor(String type) =>
    dashCategoryColor(type, known: kVehicleTypes);

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
    unitNoun: 'vehicles',
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
    unitNoun: 'vehicles',
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
