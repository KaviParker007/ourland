// ─── Collections — Screen 1: Collections by Project ────────────────────────────
//
//   • tapping a project header → Screen 2 (zones of that project)
//   • tapping a bin-type row   → Screen 4 (that project + that bin type)
//
// The date range is held in CollectionDateFilter so it survives back-navigation,
// and is carried into every request through the CollectionQuery.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';
import 'package:ourlandnew/services/dash_api.dart';

import 'collection_drill_page.dart';
import 'collection_models.dart';
import 'collection_query.dart';
import 'collection_service.dart';
import 'collection_ui.dart';
import 'queried_collections_page.dart';

class CollectionDashboardPage extends StatefulWidget {
  const CollectionDashboardPage({super.key});

  @override
  State<CollectionDashboardPage> createState() =>
      _CollectionDashboardPageState();
}

class _CollectionDashboardPageState extends State<CollectionDashboardPage> {
  final _api = CollectionDashboardApi.instance;

  List<CollectionGroupRow> _rows = [];
  bool _loading = true;
  String? _error;

  CollectionDateRange get _range => CollectionDateFilter.instance.range;

  /// Root of the drill-down: no location scope yet, just the live date range.
  CollectionQuery get _query => CollectionQuery(range: _range);

  @override
  void initState() {
    super.initState();
    // Fresh entry → both dates default to today.
    CollectionDateFilter.instance.reset();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('menu', 'collections_dashboard');
    _fetch();
  }

  Future<void> _fetch() async {
    // Validate before calling out — an invalid span never reaches the API.
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
      final rows = await _api.byProject(_query);
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

  /// Changing the range re-fetches this screen only; the stack is untouched.
  void _onRangeChanged(CollectionDateRange next) {
    if (next == _range) return;
    CollectionDateFilter.instance.range = next;
    _fetch();
  }

  // ── Navigation ───────────────────────────────────────────────────────────────

  void _openZones(String project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kColZoneRoute),
        builder: (_) => CollectionDrillPage(
          level: CollectionDrillLevel.zone,
          query: _query.drillToZones(project),
        ),
      ),
    ).then((_) => _fetch());
  }

  void _openCollections({required String project, required String binType}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kColListRoute),
        builder: (_) => QueriedCollectionsPage(
          title: project,
          query: _query.drillToZones(project).withType(binType),
          crumbs: [
            const DashCrumb('Projects', routeName: kColDashboardRoute),
            DashCrumb(project),
          ],
        ),
      ),
    ).then((_) => _fetch());
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [NotificationBellWidget()],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
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
          message: 'No collections in this date range',
          hint: 'Nothing was collected between '
              '${_range.startParam} and ${_range.endParam}.',
          icon: Icons.event_busy_rounded,
        ),
      );
    }

    final types = unionCollectionTypes(_rows, kCollectionBinTypes);

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
                  return buildCollectionSection(
                    context: context,
                    row: row,
                    typeColumns: types,
                    headerTargetNoun: 'zones',
                    onHeaderTap: () => _openZones(row.label),
                    onTypeTap: (type) =>
                        _openCollections(project: row.label, binType: type),
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
