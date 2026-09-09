// ─── Bins — module UI helpers ──────────────────────────────────────────────────
//
// The Bins module is a four-level drill where each screen shows one dimension:
//
//   Projects → Bin Types → Bin Statuses → Bin List
//
// Every level renders the same [BinDrillCard], which reuses the Vehicle Type
// dashboard's card tokens exactly — 14 px radius, elevation 3, a 4 px coloured
// left border, bold 15 px title, pill count badge and trailing chevron — so the
// two dashboards read as one application.
//
// Generic page states and the breadcrumb come from components/drill_down.dart.

import 'package:flutter/material.dart';

import 'package:ourlandnew/components/drill_down.dart';

import 'bin_query.dart';
import 'bin_status.dart';

export 'package:ourlandnew/components/drill_down.dart';

// Route names used by the breadcrumb to pop back to a specific drill level.
const String kBinDashboardRoute = '/bins_dashboard';
const String kBinZoneRoute = 'bin_zone';
const String kBinWardRoute = 'bin_ward';
const String kBinTypeRoute = 'bin_type';
const String kBinStatusRoute = 'bin_status';
const String kBinListRoute = 'bin_list';

/// Stable colour per bin type, from the shared category palette — the same one
/// the Vehicle Type dashboard uses for vehicle types.
Color binTypeColor(String type) => dashCategoryColor(type, known: kBinTypes);

// ── The one card ───────────────────────────────────────────────────────────────

/// A single drill row: project, zone, ward, bin type or bin status.
///
/// Visually identical to a Vehicle Type `GroupSection` header. A zero count is
/// de-emphasised and inert, matching how that dashboard treats an empty row.
class BinDrillCard extends StatelessWidget {
  final String title;

  /// Optional muted second line (e.g. "No zone assigned").
  final String? subtitle;

  final int count;

  /// Left border, badge and leading mark. For a bin status this is always
  /// [binStatusColor], so a status keeps the same colour everywhere it appears.
  final Color accent;

  /// Leading icon — used by status cards. Types get [showDot] instead, matching
  /// the coloured dot on a Vehicle Type count row.
  final IconData? icon;
  final bool showDot;

  final VoidCallback? onTap;

  /// Spoken after the count, e.g. "Double tap to view bin types".
  final String targetNoun;
  final String unitNoun;

  const BinDrillCard({
    super.key,
    required this.title,
    required this.count,
    required this.accent,
    this.subtitle,
    this.icon,
    this.showDot = false,
    this.onTap,
    this.targetNoun = 'details',
    this.unitNoun = 'bins',
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final active = onTap != null && count > 0;
    final fg = active ? accent : accent.withAlpha(90);

    return Semantics(
      button: active,
      enabled: active,
      label: '$title, $count $unitNoun'
          '${subtitle == null ? '' : ', $subtitle'}'
          '${active ? '. Double tap to view $targetNoun.' : ''}',
      excludeSemantics: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        elevation: active ? 3 : 1,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: fg, width: 4)),
          ),
          child: InkWell(
            onTap: active ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kDashMinTapTarget),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: fg),
                      const SizedBox(width: 10),
                    ] else if (showDot) ...[
                      Container(
                        width: 9,
                        height: 9,
                        decoration:
                            BoxDecoration(color: fg, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 0.3,
                              color: active
                                  ? onSurface
                                  : onSurface.withAlpha(120),
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: onSurface.withAlpha(130)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withAlpha(active ? 28 : 12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: accent.withAlpha(active ? 110 : 45),
                            width: 1.2),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: active ? accent : onSurface.withAlpha(90),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 26,
                      child: active
                          ? Icon(Icons.chevron_right_rounded,
                              size: 22, color: onSurface.withAlpha(120))
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds a bin-status card. Kept as a helper so the status → colour → icon
/// pairing is applied identically wherever statuses are listed.
BinDrillCard buildBinStatusCard({
  required String status,
  required int count,
  required VoidCallback onTap,
}) {
  return BinDrillCard(
    title: status,
    count: count,
    accent: binStatusColor(status),
    icon: binStatusIcon(status),
    onTap: onTap,
    targetNoun: 'bins',
  );
}

// ── Filter bar ─────────────────────────────────────────────────────────────────

/// Always-present filter summary under the app bar of the bin list, matching the
/// Vehicle Type dashboard's "All statuses · All owners" line. Non-default filters
/// render as deletable chips; at defaults a muted line states so.
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
        label: 'Filters: all bin types, all statuses. '
            'Double tap to change filters.',
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
                      'All bin types · All statuses',
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

/// Bin type + bin status filter sheet, styled like the Vehicle Type one.
///
/// [availableTypes] are the types the API actually returned, so the options are
/// never hardcoded; [kBinTypes] is used only as a display ordering. The status
/// options are the five documented [kBinStatuses] values, sent verbatim.
///
/// `bin_owner` is intentionally absent: it is wired through the query and sent
/// whenever set, but the API contract does not enumerate its allowed values, so
/// offering a guessed dropdown would be inventing data.
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
  late String _status = widget.current.binStatus;

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

  /// `All` plus the five documented statuses. The current selection is folded in
  /// so an unrecognised bucket the user drilled through is still selectable.
  List<String> get _statusOptions => [
        kBinAll,
        ...orderBinStatuses({
          ...kBinStatuses,
          if (_status != kBinAll && _status.trim().isNotEmpty) _status,
        }),
      ];

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
          _dropdown(
            label: 'Bin Type',
            value: _type,
            options: _typeOptions,
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 14),
          _dropdown(
            label: 'Bin Status',
            value: _status,
            options: _statusOptions,
            onChanged: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, const BinFilters()),
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
                    widget.current
                        .copyWith(binType: _type, binStatus: _status),
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

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
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
      items: options
          .map((v) => DropdownMenuItem(
                value: v,
                child: Text(v, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ── Chain toggle ───────────────────────────────────────────────────────────────

/// The two ways to reach a bin list, mirroring the Vehicle Type dashboard's
/// "By Location / By Status" segmented control.
enum BinChain { type, location }

extension BinChainX on BinChain {
  String get label => this == BinChain.type ? 'By Type' : 'By Location';
}

/// One pill in the segmented control. Same geometry, animation and colours as
/// the Vehicle Type dashboard's chain tabs.
class BinChainTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const BinChainTab({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isActive ? primary : Colors.transparent,
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: primary.withAlpha(80),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface.withAlpha(160),
            ),
          ),
        ),
      ),
    );
  }
}

/// The segmented control bar, including its surface and shadow.
class BinChainBar extends StatelessWidget {
  final BinChain chain;
  final ValueChanged<BinChain> onChanged;
  const BinChainBar({
    super.key,
    required this.chain,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(35),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Flexible + horizontal scroll so the pills can never overflow on a
          // narrow phone or at a large text scale; at normal sizes this looks
          // and behaves exactly like a fixed segmented control.
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black.withAlpha(40),
                  border:
                      Border.all(color: Colors.white.withAlpha(18), width: 1),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final c in BinChain.values)
                      BinChainTab(
                        label: c.label,
                        isActive: chain == c,
                        onTap: () => onChanged(c),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
