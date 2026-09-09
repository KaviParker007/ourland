// ─── Bins — Screens 2 & 3: by Zone / by Ward ────────────────────────────────────
//
// One page serves both aggregate levels; only the endpoint and what a header tap
// opens differ:
//
//   Screen 2 (zone level)  header → Screen 3 (wards)  row → Screen 4 (zone+type)
//   Screen 3 (ward level)  header → Screen 4 (ward)   row → Screen 4 (ward+type)
//
// The incoming BinQuery already carries the accumulated scope, so this screen
// never assembles a query string itself.

import 'package:flutter/material.dart';

import 'package:ourlandnew/services/dash_api.dart';

import 'bin_models.dart';
import 'bin_query.dart';
import 'bin_service.dart';
import 'bin_ui.dart';
import 'queried_bins_page.dart';

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

  // Note: the dashboard endpoints take no filter params — bin_type/status/owner
  // apply to the bin list only, and are offered on that screen.

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
      final q = _query;
      final rows =
          _isZone ? await _api.dashByZone(q) : await _api.dashByWard(q);
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

  /// Group header tapped. At the zone level this opens that zone's wards; at the
  /// ward level it opens every bin in that ward.
  void _onHeaderTap(BinGroupRow row) {
    if (_isZone) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: kBinWardRoute),
          builder: (_) => BinDrillPage(
            level: BinDrillLevel.ward,
            // A null id is the unassigned bucket; drillToWards records that and
            // omits zone_id, which is how the endpoint returns bins with no zone.
            query: _query
                .drillToWards(zoneId: row.id, zoneCode: row.label),
          ),
        ),
      ).then((_) => _fetch());
      return;
    }
    _openBins(row: row, binType: kBinAll);
  }

  void _openBins({required BinGroupRow row, required String binType}) {
    final scoped = _isZone
        ? _query.withZone(zoneId: row.id, zoneCode: row.label)
        : _query.withWard(wardId: row.id, wardCode: row.label);

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kBinListRoute),
        builder: (_) => QueriedBinsPage(
          title: row.label,
          query: scoped.withType(binType),
          crumbs: _terminalCrumbs(row.label),
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

  List<DashCrumb> _terminalCrumbs(String rowLabel) {
    if (_isZone) {
      return [
        const DashCrumb('Projects', routeName: kBinDashboardRoute),
        DashCrumb(_projectLabel, routeName: kBinZoneRoute),
        DashCrumb(rowLabel),
      ];
    }
    return [
      const DashCrumb('Projects', routeName: kBinDashboardRoute),
      DashCrumb(_projectLabel, routeName: kBinZoneRoute),
      DashCrumb(_zoneLabel, routeName: kBinWardRoute),
      DashCrumb(rowLabel),
    ];
  }

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

    final types = unionBinTypes(_rows, kBinTypes);
    final headerNoun = _isZone ? 'wards' : 'bins';

    return RefreshIndicator(
      onRefresh: _fetch,
      child: DashContentWidth(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              sliver: SliverList.builder(
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  return buildBinSection(
                    context: context,
                    row: row,
                    typeColumns: types,
                    headerTargetNoun: headerNoun,
                    onHeaderTap: () => _onHeaderTap(row),
                    onTypeTap: (type) => _openBins(row: row, binType: type),
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
