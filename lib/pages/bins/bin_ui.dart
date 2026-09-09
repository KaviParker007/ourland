// ─── Bins — module UI helpers ──────────────────────────────────────────────────
//
// Bin-specific pieces only. The generic page states, breadcrumb and
// GroupSection / TypeCountRow come from components/drill_down.dart.

import 'package:flutter/material.dart';

import 'package:ourlandnew/components/drill_down.dart';

import 'bin_models.dart';
import 'bin_query.dart';

export 'package:ourlandnew/components/drill_down.dart';

// Route names used by the breadcrumb to pop back to a specific drill level.
const String kBinDashboardRoute = '/bins_dashboard';
const String kBinZoneRoute = 'bin_zone';
const String kBinWardRoute = 'bin_ward';
const String kBinListRoute = 'bin_list';

/// Stable colour per bin type, from the shared category palette.
Color binTypeColor(String type) => dashCategoryColor(type, known: kBinTypes);

// ── Filter bar ─────────────────────────────────────────────────────────────────

/// Always-present filter summary under the app bar. Non-default filters render
/// as deletable chips; at defaults a muted line states so, so the user always
/// knows what they are looking at. Editing happens through the app-bar
/// `filter_alt` action, matching every other dashboard in the app.
class BinFilterBar extends StatelessWidget {
  final BinFilters filters;
  final void Function(BinFilters cleared) onClear;
  final VoidCallback? onEdit;

  const BinFilterBar({
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
        label: 'Filters: all bin types. Double tap to change filters.',
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
                      'All bin types',
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
    void add(String label, String semantic, BinFilters cleared) {
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

    if (filters.binType != kBinAll) {
      add('Type: ${filters.binType}', 'bin type filter ${filters.binType}',
          filters.copyWith(binType: kBinAll));
    }
    if (filters.binStatus != kBinAll) {
      add('Status: ${filters.binStatus}',
          'bin status filter ${filters.binStatus}',
          filters.copyWith(binStatus: kBinAll));
    }
    if (filters.binOwner != kBinAll) {
      add('Owner: ${filters.binOwner}', 'bin owner filter ${filters.binOwner}',
          filters.copyWith(binOwner: kBinAll));
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

// ── Filter sheet ───────────────────────────────────────────────────────────────

/// Bin-type filter sheet. Returns the new filters, or null if dismissed.
///
/// [availableTypes] are the types the API actually returned, so the options are
/// never hardcoded; [kBinTypes] is used only as a display ordering.
///
/// `bin_status` and `bin_owner` are intentionally absent: they are wired through
/// the query and sent on every request, but the API contract does not enumerate
/// their allowed values, so offering a guessed dropdown would be inventing data.
Future<BinFilters?> showBinFilterSheet(
  BuildContext context,
  BinFilters current,
  List<String> availableTypes,
) {
  return showModalBottomSheet<BinFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _BinFilterSheet(
      current: current,
      availableTypes: availableTypes,
    ),
  );
}

class _BinFilterSheet extends StatefulWidget {
  final BinFilters current;
  final List<String> availableTypes;
  const _BinFilterSheet({required this.current, required this.availableTypes});

  @override
  State<_BinFilterSheet> createState() => _BinFilterSheetState();
}

class _BinFilterSheetState extends State<_BinFilterSheet> {
  late String _type = widget.current.binType;

  /// `All` plus whatever the API returned, de-duplicated and ordered. The
  /// current selection is always included so the dropdown can never be handed a
  /// value that is not among its items.
  List<String> get _typeOptions {
    final present = {...widget.availableTypes, _type}
      ..removeWhere((t) => t.trim().isEmpty || t == kBinAll);
    final ordered = [
      for (final t in kBinTypes)
        if (present.contains(t)) t
    ];
    final extras = present.where((t) => !kBinTypes.contains(t)).toList()..sort();
    return [kBinAll, ...ordered, ...extras];
  }

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
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Bin Type',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _typeOptions
                .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _type = v);
            },
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(context, const BinFilters()),
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
                    widget.current.copyWith(binType: _type),
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
}

// ── Section builder ────────────────────────────────────────────────────────────

/// One project / zone / ward group. [onHeaderTap] drills to the next level (or
/// the bin list at ward level); [onTypeTap] opens the bin list for one bin type.
Widget buildBinSection({
  required BuildContext context,
  required BinGroupRow row,
  required List<String> typeColumns,
  required VoidCallback? onHeaderTap,
  required void Function(String binType) onTypeTap,
  String headerTargetNoun = 'details',
}) {
  return GroupSection(
    title: row.label,
    total: row.total,
    accent: row.isUnassigned
        ? const Color(0xFF78909C)
        : Theme.of(context).colorScheme.primary,
    onHeaderTap: onHeaderTap,
    headerTargetNoun: headerTargetNoun,
    unitNoun: 'bins',
    subtitle: row.isUnassigned ? 'No zone assigned' : null,
    rows: [
      for (final t in typeColumns)
        CountRowData(
          label: t,
          count: row.count(t),
          color: binTypeColor(t),
          caption: row.captionFor(t),
          onTap: row.count(t) > 0 ? () => onTypeTap(t) : null,
        ),
    ],
  );
}
