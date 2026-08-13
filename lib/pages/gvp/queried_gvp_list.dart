// ─── GVP Module — Queried GVP list (final drill-down step) ─────────────────────
//
// Reached from the dashboard by tapping a project / zone / ward count. Sends
// ONLY the most specific selected filter (ward → zone → project). Renders a
// breadcrumb (Projects → Zones → Wards → GVPs); tapping any earlier crumb pops
// back to the still-expanded dashboard, preserving the selected context.

import 'package:flutter/material.dart';

import 'gvp_models.dart';
import 'gvp_service.dart';
import 'gvp_ui.dart';
import 'gvp_status.dart';
import 'gvp_daily_confirmation.dart';
import 'gvp_detail.dart';
import 'gvp_name_resolver.dart';

/// The only today_status values shown on the queried GVP screen.
const List<GvpTodayStatus> kGvpValidStatuses = [
  GvpTodayStatus.nt, // NC
  GvpTodayStatus.wip,
  GvpTodayStatus.cleared, // C
];

/// Immutable selection carried through the drill-down.
class GvpDrillContext {
  final String? project;
  final int? zoneId;
  final String? zoneCode;
  final int? wardId;
  final String? wardCode;

  const GvpDrillContext({
    this.project,
    this.zoneId,
    this.zoneCode,
    this.wardId,
    this.wardCode,
  });

  /// The deepest level selected — decides which single filter is sent.
  bool get isWardLevel => wardId != null;
  bool get isZoneLevel => wardId == null && zoneId != null;
  bool get isProjectLevel => wardId == null && zoneId == null;
}

class QueriedGvpListPage extends StatefulWidget {
  final GvpDrillContext context;

  const QueriedGvpListPage({super.key, required this.context});

  @override
  State<QueriedGvpListPage> createState() => _QueriedGvpListPageState();
}

class _QueriedGvpListPageState extends State<QueriedGvpListPage> {
  final _service = GvpService.instance;
  final _resolver = GvpNameResolver.instance;

  List<Gvp> _gvps = [];
  bool _loading = true;
  String? _error;
  bool _initialLoad = true;

  /// Selected today_status filter. Null = All (no today_status param sent).
  GvpTodayStatus? _statusFilter;

  GvpDrillContext get _ctx => widget.context;

  @override
  void initState() {
    super.initState();
    // Seed the resolver with the names we already know from the drill-down.
    _resolver.registerZone(_ctx.zoneId, _ctx.zoneCode);
    _resolver.registerWard(_ctx.wardId, _ctx.wardCode);
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getQueriedGvpList(
        wardId: _ctx.wardId,
        zoneId: _ctx.zoneId,
        project: _ctx.project,
        todayStatus: _statusFilter?.code,
      );
      if (!mounted) return;
      setState(() => _gvps = data);
      // Resolve any zone/ward names not already known for this result set.
      await _resolver.ensureZones();
      await _resolver.ensureWardsForZones(
        data.map((g) => g.zone).whereType<int>(),
      );
      if (mounted) setState(() {});
    } on GvpApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _initialLoad = false;
        });
      }
    }
  }

  /// Re-queries the API with the chosen today_status (null = All).
  void _onStatusSelected(GvpTodayStatus? status) {
    if (_statusFilter == status) return;
    setState(() => _statusFilter = status);
    _fetch();
  }

  void _openDetail(Gvp gvp) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GvpDetailPage(gvpId: gvp.id)),
    ).then((_) => _fetch());
  }

  String get _title {
    if (_ctx.isWardLevel) return _ctx.wardCode ?? 'Ward';
    if (_ctx.isZoneLevel) return _ctx.zoneCode ?? 'Zone';
    return _ctx.project ?? 'GVPs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _Breadcrumb(
            context: _ctx,
            onCrumbTap: () => Navigator.pop(context),
          ),
          // Status filter — visible after the first load (stays put during
          // filter-triggered re-fetches so the user can keep switching).
          if (!_initialLoad && _error == null)
            _StatusFilterBar(
              selected: _statusFilter,
              onSelected: _onStatusSelected,
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const GvpLoading();
    if (_error != null) return GvpFullError(message: _error!, onRetry: _fetch);
    if (_gvps.isEmpty) {
      final label = _statusFilter?.code;
      return GvpEmpty(
        message: label != null ? 'No matching GVPs' : 'No GVPs found',
        hint: label != null
            ? 'No GVPs with status "$label" in this selection.'
            : 'There are no GVP records for this selection.',
        icon: Icons.search_off_rounded,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _gvps.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _ResultBanner(count: _gvps.length);
          final gvp = _gvps[index - 1];
          return GvpDailyCard(
            gvp: gvp,
            zoneName: _resolver.zoneName(gvp.zone),
            wardName: _resolver.wardName(gvp.ward),
            onChanged: _fetch,
            onView: () => _openDetail(gvp),
          );
        },
      ),
    );
  }
}

// ── Status filter bar (NC / WIP / C) ──────────────────────────────────────────

class _StatusFilterBar extends StatelessWidget {
  final GvpTodayStatus? selected;
  final ValueChanged<GvpTodayStatus?> onSelected;

  const _StatusFilterBar({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // "All" plus the three valid statuses, in order.
    final options = <MapEntry<String, GvpTodayStatus?>>[
      const MapEntry('All', null),
      for (final s in kGvpValidStatuses) MapEntry(s.code ?? '—', s),
    ];

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _FilterChip(
                label: options[i].key,
                color: options[i].value == null
                    ? primary
                    : GvpStatusStyle.of(options[i].value!).color,
                showDot: options[i].value != null,
                selected: selected == options[i].value,
                onTap: () => onSelected(options[i].value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool showDot;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.showDot,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(40) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withAlpha(90),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Breadcrumb ────────────────────────────────────────────────────────────────

class _Breadcrumb extends StatelessWidget {
  final GvpDrillContext context;
  final VoidCallback onCrumbTap;

  const _Breadcrumb({required this.context, required this.onCrumbTap});

  @override
  Widget build(BuildContext ctx) {
    final crumbs = <_Crumb>[
      _Crumb('Projects', tappable: true),
      if (context.project != null)
        _Crumb(context.project!,
            tappable: !context.isProjectLevel),
      if (context.zoneId != null)
        _Crumb(context.zoneCode ?? 'Zone', tappable: !context.isZoneLevel),
      if (context.wardId != null)
        _Crumb(context.wardCode ?? 'Ward', tappable: false),
    ];

    final primary = Theme.of(ctx).colorScheme.primary;
    final onSurface = Theme.of(ctx).colorScheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
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
                onTap: crumbs[i].tappable ? onCrumbTap : null,
                child: Text(
                  crumbs[i].label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        i == crumbs.length - 1 ? FontWeight.w700 : FontWeight.w500,
                    color: crumbs[i].tappable
                        ? primary
                        : onSurface.withAlpha(200),
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

class _Crumb {
  final String label;
  final bool tappable;
  _Crumb(this.label, {required this.tappable});
}

// ── Result banner ─────────────────────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  final int count;

  const _ResultBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(15), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.list_alt_rounded,
              size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$count ${count == 1 ? 'GVP' : 'GVPs'} found',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
