// ─── Collections — module UI helpers ───────────────────────────────────────────
//
// Collection-specific pieces: the date-range bar and picker, the bin-type filter
// sheet, and the section builder. Generic page states, breadcrumb and
// GroupSection / TypeCountRow come from components/drill_down.dart.

import 'package:flutter/material.dart';

import 'package:ourlandnew/components/drill_down.dart';

import 'collection_models.dart';
import 'collection_query.dart';

export 'package:ourlandnew/components/drill_down.dart';

// Route names used by the breadcrumb to pop back to a specific drill level.
const String kColDashboardRoute = '/collections_dashboard';
const String kColZoneRoute = 'col_zone';
const String kColWardRoute = 'col_ward';
const String kColListRoute = 'col_list';

/// Stable colour per bin type, from the shared category palette.
Color collectionTypeColor(String type) =>
    dashCategoryColor(type, known: kCollectionBinTypes);

// ── Date range bar ─────────────────────────────────────────────────────────────

/// The always-visible date-range control. Shows the active range, offers Start /
/// End pickers and a "Today" reset, and surfaces a validation message instead of
/// letting an out-of-range span reach the API.
///
/// Stacks vertically under [kDashCompactWidth] so nothing overflows on a phone.
class CollectionDateBar extends StatelessWidget {
  final CollectionDateRange range;
  final ValueChanged<CollectionDateRange> onChanged;

  /// Filter summary appended after the range, e.g. `Dumper`.
  final String? typeSummary;

  const CollectionDateBar({
    super.key,
    required this.range,
    required this.onChanged,
    this.typeSummary,
  });

  Future<void> _pickStart(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: range.start,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select start date',
    );
    if (picked == null) return;
    // withStart pulls the end along if the move would invert the range or push
    // it past the 7-day cap, so the result is always valid.
    onChanged(range.withStart(picked));
  }

  Future<void> _pickEnd(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: range.end,
      // Clamped to the 7-day window so an invalid end is not selectable.
      firstDate: range.start,
      lastDate: range.maxEndForStart,
      helpText: 'Select end date (max $kMaxCollectionRangeDays days)',
    );
    if (picked == null) return;
    onChanged(range.withEnd(picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;
    final error = range.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // The breakpoint scales with the user's text size: at 2x, a 768 dp
              // tablet has no more usable room for a side-by-side row than a
              // phone does at 1x, so it stacks instead.
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final compact =
                  constraints.maxWidth < kDashCompactWidth * textScale;
              final buttons = [
                _dateButton(
                  context,
                  label: 'From',
                  value: range.startParam,
                  onTap: () => _pickStart(context),
                ),
                _dateButton(
                  context,
                  label: 'To',
                  value: range.endParam,
                  onTap: () => _pickEnd(context),
                ),
              ];

              final summary = Row(
                children: [
                  Icon(Icons.date_range_rounded, size: 15, color: primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      typeSummary == null
                          ? range.label
                          : '${range.label} · $typeSummary',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!range.isToday)
                    TextButton(
                      onPressed: () =>
                          onChanged(CollectionDateRange.today()),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, kDashMinTapTarget - 12),
                      ),
                      child: const Text('Today',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    summary,
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: buttons[0]),
                        const SizedBox(width: 8),
                        Expanded(child: buttons[1]),
                      ],
                    ),
                  ],
                );
              }
              // Flexible on the buttons as well as the summary: even above the
              // breakpoint they must be able to give way rather than overflow.
              return Row(
                children: [
                  Expanded(flex: 3, child: summary),
                  const SizedBox(width: 12),
                  Flexible(flex: 2, child: buttons[0]),
                  const SizedBox(width: 8),
                  Flexible(flex: 2, child: buttons[1]),
                ],
              );
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withAlpha(28),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: theme.colorScheme.error.withAlpha(110)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 15, color: theme.colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error,
                      style: TextStyle(
                          fontSize: 12, color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!range.isSingleDay) ...[
            const SizedBox(height: 4),
            Text(
              '${range.lengthInDays} of $kMaxCollectionRangeDays days',
              style: TextStyle(fontSize: 11, color: onSurface.withAlpha(120)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateButton(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      label: '$label date $value. Double tap to change.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: kDashMinTapTarget - 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: onSurface.withAlpha(45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 13, color: onSurface.withAlpha(140)),
              const SizedBox(width: 6),
              // Flexible, not a bare Column: two of these sit side by side in
              // the compact layout, so on a narrow phone (or at a large text
              // scale) the label has to be able to shrink rather than overflow.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: onSurface.withAlpha(120),
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bin-type filter sheet ──────────────────────────────────────────────────────

/// Bin-type filter for the collection list. [availableTypes] are the types the
/// API actually returned; [kCollectionBinTypes] is only a display ordering.
Future<String?> showCollectionTypeSheet(
  BuildContext context,
  String current,
  List<String> availableTypes,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _TypeSheet(current: current, availableTypes: availableTypes),
  );
}

class _TypeSheet extends StatefulWidget {
  final String current;
  final List<String> availableTypes;
  const _TypeSheet({required this.current, required this.availableTypes});

  @override
  State<_TypeSheet> createState() => _TypeSheetState();
}

class _TypeSheetState extends State<_TypeSheet> {
  late String _type = widget.current;

  /// `All` plus whatever the API returned. The current selection is always
  /// included so the dropdown can never receive a value outside its items.
  List<String> get _options {
    final present = {...widget.availableTypes, _type}
      ..removeWhere((t) => t.trim().isEmpty || t == kCollectionAll);
    final ordered = [
      for (final t in kCollectionBinTypes)
        if (present.contains(t)) t
    ];
    final extras =
        present.where((t) => !kCollectionBinTypes.contains(t)).toList()..sort();
    return [kCollectionAll, ...ordered, ...extras];
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _options
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
                  onPressed: () => Navigator.pop(context, kCollectionAll),
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
                  onPressed: () => Navigator.pop(context, _type),
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
/// the collection list at ward level); [onTypeTap] opens the list for one type.
Widget buildCollectionSection({
  required BuildContext context,
  required CollectionGroupRow row,
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
    unitNoun: 'collections',
    subtitle: row.isUnassigned ? 'No zone assigned' : null,
    rows: [
      for (final t in typeColumns)
        CountRowData(
          label: t,
          count: row.count(t),
          color: collectionTypeColor(t),
          onTap: row.count(t) > 0 ? () => onTypeTap(t) : null,
        ),
    ],
  );
}
