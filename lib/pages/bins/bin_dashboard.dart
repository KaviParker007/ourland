// ─── Bins — Screen 1: Bins by Project ──────────────────────────────────────────
//
//   • tapping a project header  → Screen 2 (zones of that project)
//   • tapping a bin-type row    → Screen 4 (that project + that bin type)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';
import 'package:ourlandnew/services/dash_api.dart';

import 'bin_drill_page.dart';
import 'bin_models.dart';
import 'bin_query.dart';
import 'bin_service.dart';
import 'bin_ui.dart';
import 'queried_bins_page.dart';

class BinDashboardPage extends StatefulWidget {
  const BinDashboardPage({super.key});

  @override
  State<BinDashboardPage> createState() => _BinDashboardPageState();
}

class _BinDashboardPageState extends State<BinDashboardPage> {
  final _api = BinDashboardApi.instance;

  List<BinGroupRow> _rows = [];
  bool _loading = true;
  String? _error;

  /// Root of the drill-down. This endpoint takes no location or filter params —
  /// the bin_type/status/owner filters apply to the bin *list* only, so they are
  /// offered on that screen rather than here.
  BinQuery get _query => const BinQuery();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('menu', 'bins_dashboard');
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.dashByProject(_query);
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

  void _openZones(String project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kBinZoneRoute),
        builder: (_) => BinDrillPage(
          level: BinDrillLevel.zone,
          query: _query.drillToZones(project),
        ),
      ),
    ).then((_) => _fetch());
  }

  void _openBins({required String project, required String binType}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kBinListRoute),
        builder: (_) => QueriedBinsPage(
          title: project,
          query: _query.drillToZones(project).withType(binType),
          crumbs: [
            const DashCrumb('Projects', routeName: kBinDashboardRoute),
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
        title:
            const Text('Bins', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [NotificationBellWidget()],
      ),
      drawer: const AppDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const DashLoading();
    if (_error != null) return DashError(message: _error!, onRetry: _fetch);

    if (_rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetch,
        child: const DashEmptyScrollable(
          message: 'No bins found',
          hint: 'No bin data is available for any project yet.',
          icon: Icons.delete_outline_rounded,
        ),
      );
    }

    final types = unionBinTypes(_rows, kBinTypes);

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
                  return buildBinSection(
                    context: context,
                    row: row,
                    typeColumns: types,
                    headerTargetNoun: 'zones',
                    onHeaderTap: () => _openZones(row.label),
                    onTypeTap: (type) =>
                        _openBins(project: row.label, binType: type),
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
