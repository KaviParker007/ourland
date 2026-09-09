// ─── Bins — By Location: Zones & Wards ─────────────────────────────────────────
//
// The optional location chain, reached from the dashboard's "By Location" tab:
//
//   project → zones → wards → bin types → bin statuses → bin list
//
// One page serves both levels; only the endpoint and the drill target differ.
// Cards are the same [BinDrillCard] every other Bins screen uses.

import 'package:flutter/material.dart';

import 'package:ourlandnew/services/dash_api.dart';

import 'bin_models.dart';
import 'bin_query.dart';
import 'bin_service.dart';
import 'bin_type_page.dart';
import 'bin_ui.dart';

enum BinDrillLevel { zone, ward }

class BinDrillPage extends StatefulWidget {
  final BinDrillLevel level;

  /// Scope accumulated by the caller: `project` for the zone level, plus
  /// `zone_id` / `zoneCode` for the ward level.
  final BinQuery query;

  const BinDrillPage({
    super.key,
    required this.level,
    required this.query,
  });

  @override
  State<BinDrillPage> createState() => _BinDrillPageState();
}

class _BinDrillPageState extends State<BinDrillPage> {
  final _api = BinDashboardApi.instance;

  List<BinGroupRow> _rows = [];
  bool _loading = true;
  String? _error;

  late final BinQuery _query = widget.query;

  bool get _isZone => widget.level == BinDrillLevel.zone;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = _isZone
          ? await _api.dashByZone(_query)
          : await _api.dashByWard(_query);
      if (!mounted) return;
      setState(() => _rows = rows);
    } on DashApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not read the server response.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Navigation ───────────────────────────────────────────────────────────────

  /// A zone card opens its wards; a ward card opens that ward's bin types.
  void _onRowTap(BinGroupRow row) {
    if (_isZone) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: kBinWardRoute),
          builder: (_) => BinDrillPage(
            level: BinDrillLevel.ward,
            // A null id is the unassigned bucket; drillToWards records that and
            // omits zone_id, which is how the endpoint returns bins with no zone.
            query: _query.drillToWards(zoneId: row.id, zoneCode: row.label),
          ),
        ),
      ).then((_) => _fetch());
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kBinTypeRoute),
        builder: (_) => BinTypePage(
          title: row.label,
          query: _query.withWard(wardId: row.id, wardCode: row.label),
          row: row,
          crumbs: _typeCrumbs(row.label),
        ),
      ),
    ).then((_) => _fetch());
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  String get _projectLabel => _query.project ?? 'Project';
  String get _zoneLabel => _query.zoneCode ?? 'Zone';

  List<DashCrumb> get _crumbs {
    if (_isZone) {
      return [
        const DashCrumb('Projects', routeName: kBinDashboardRoute),
        DashCrumb(_projectLabel),
      ];
    }
    return [
      const DashCrumb('Projects', routeName: kBinDashboardRoute),
      DashCrumb(_projectLabel, routeName: kBinZoneRoute),
      DashCrumb(_zoneLabel),
    ];
  }

  List<DashCrumb> _typeCrumbs(String wardLabel) => [
        const DashCrumb('Projects', routeName: kBinDashboardRoute),
        DashCrumb(_projectLabel, routeName: kBinZoneRoute),
        DashCrumb(_zoneLabel, routeName: kBinWardRoute),
        DashCrumb(wardLabel),
      ];

  @override
  Widget build(BuildContext context) {
    final title = _isZone ? _projectLabel : '$_projectLabel › $_zoneLabel';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          DashBreadcrumb(crumbs: _crumbs),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const DashLoading();
    if (_error != null) return DashError(message: _error!, onRetry: _fetch);

    if (_rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetch,
        child: DashEmptyScrollable(
          message: _isZone ? 'No zones found' : 'No wards found',
          hint: _isZone
              ? 'No zones with bins in $_projectLabel.'
              : 'No wards with bins in $_zoneLabel.',
          icon: Icons.inbox_outlined,
        ),
      );
    }

    final targetNoun = _isZone ? 'wards' : 'bin types';

    return RefreshIndicator(
      onRefresh: _fetch,
      child: DashContentWidth(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
              sliver: SliverList.builder(
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  return BinDrillCard(
                    title: row.label,
                    subtitle: row.isUnassigned ? 'No zone assigned' : null,
                    count: row.total,
                    accent: row.isUnassigned
                        ? const Color(0xFF78909C)
                        : Theme.of(context).colorScheme.primary,
                    targetNoun: targetNoun,
                    onTap: () => _onRowTap(row),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
