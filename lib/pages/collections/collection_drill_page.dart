// ─── Collections — Screens 2 & 3: by Zone / by Ward ────────────────────────────
//
//   Screen 2 (zone level)  header → Screen 3 (wards)  row → Screen 4 (zone+type)
//   Screen 3 (ward level)  header → Screen 4 (ward)   row → Screen 4 (ward+type)
//
// ⚠️ The two endpoints take different params: by-zone needs `project`, while
// by-ward filters on `zone_id` alone and sends no project at all. That asymmetry
// lives in CollectionQuery.aggregateParams, not here.

import 'package:flutter/material.dart';

import 'package:ourlandnew/services/dash_api.dart';

import 'collection_models.dart';
import 'collection_query.dart';
import 'collection_service.dart';
import 'collection_ui.dart';
import 'queried_collections_page.dart';

enum CollectionDrillLevel { zone, ward }

class CollectionDrillPage extends StatefulWidget {
  final CollectionDrillLevel level;

  /// Scope accumulated by the caller: `project` for the zone level, plus
  /// `zone_id` / `zoneCode` for the ward level.
  final CollectionQuery query;

  const CollectionDrillPage({
    super.key,
    required this.level,
    required this.query,
  });

  @override
  State<CollectionDrillPage> createState() => _CollectionDrillPageState();
}

class _CollectionDrillPageState extends State<CollectionDrillPage> {
  final _api = CollectionDashboardApi.instance;

  List<CollectionGroupRow> _rows = [];
  bool _loading = true;
  String? _error;

  late final CollectionQuery _query = widget.query;

  bool get _isZone => widget.level == CollectionDrillLevel.zone;

  /// The range lives in the process-wide holder so it survives back-navigation.
  CollectionDateRange get _range => CollectionDateFilter.instance.range;
  CollectionQuery get _liveQuery => _query.withRange(_range);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final rangeError = _range.error;
    if (rangeError != null) {
      setState(() {
        _loading = false;
        _error = rangeError;
        _rows = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _liveQuery;
      final rows = _isZone ? await _api.byZone(q) : await _api.byWard(q);
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

  void _onRangeChanged(CollectionDateRange next) {
    if (next == _range) return;
    CollectionDateFilter.instance.range = next;
    _fetch();
  }

  // ── Navigation ───────────────────────────────────────────────────────────────

  void _onHeaderTap(CollectionGroupRow row) {
    if (_isZone) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: kColWardRoute),
          builder: (_) => CollectionDrillPage(
            level: CollectionDrillLevel.ward,
            query: _liveQuery
                .drillToWards(zoneId: row.id, zoneCode: row.label),
          ),
        ),
      ).then((_) => _fetch());
      return;
    }
    _openCollections(row: row, binType: kCollectionAll);
  }

  void _openCollections({
    required CollectionGroupRow row,
    required String binType,
  }) {
    final scoped = _isZone
        ? _liveQuery.withZone(zoneId: row.id, zoneCode: row.label)
        : _liveQuery.withWard(wardId: row.id, wardCode: row.label);

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kColListRoute),
        builder: (_) => QueriedCollectionsPage(
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
        const DashCrumb('Projects', routeName: kColDashboardRoute),
        DashCrumb(_projectLabel),
      ];
    }
    return [
      const DashCrumb('Projects', routeName: kColDashboardRoute),
      DashCrumb(_projectLabel, routeName: kColZoneRoute),
      DashCrumb(_zoneLabel),
    ];
  }

  List<DashCrumb> _terminalCrumbs(String rowLabel) {
    if (_isZone) {
      return [
        const DashCrumb('Projects', routeName: kColDashboardRoute),
        DashCrumb(_projectLabel, routeName: kColZoneRoute),
        DashCrumb(rowLabel),
      ];
    }
    return [
      const DashCrumb('Projects', routeName: kColDashboardRoute),
      DashCrumb(_projectLabel, routeName: kColZoneRoute),
      DashCrumb(_zoneLabel, routeName: kColWardRoute),
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
          CollectionDateBar(range: _range, onChanged: _onRangeChanged),
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
          message: _isZone
              ? 'No zones with collections'
              : 'No wards with collections',
          hint: 'Nothing was collected in '
              '${_isZone ? _projectLabel : _zoneLabel} between '
              '${_range.startParam} and ${_range.endParam}.',
          icon: Icons.event_busy_rounded,
        ),
      );
    }

    final types = unionCollectionTypes(_rows, kCollectionBinTypes);
    final headerNoun = _isZone ? 'wards' : 'collections';

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
                  return buildCollectionSection(
                    context: context,
                    row: row,
                    typeColumns: types,
                    headerTargetNoun: headerNoun,
                    onHeaderTap: () => _onHeaderTap(row),
                    onTypeTap: (type) =>
                        _openCollections(row: row, binType: type),
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
