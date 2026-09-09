// ─── Bins — Step 1: Projects ───────────────────────────────────────────────────
//
// The entry screen: one card per project, in the Vehicle Type dashboard's card
// style, behind the same segmented control.
//
//   By Type      project → bin types → bin statuses → bin list
//   By Location  project → zones → wards → bin types → bin statuses → bin list
//
// Only this screen calls drf_bin_dash_by_project. The type and status steps read
// the counts nested in its response, so they cost no further request.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';
import 'package:ourlandnew/services/dash_api.dart';

import 'bin_drill_page.dart';
import 'bin_models.dart';
import 'bin_query.dart';
import 'bin_service.dart';
import 'bin_type_page.dart';
import 'bin_ui.dart';

class BinDashboardPage extends StatefulWidget {
  const BinDashboardPage({super.key});

  @override
  State<BinDashboardPage> createState() => _BinDashboardPageState();
}

class _BinDashboardPageState extends State<BinDashboardPage> {
  final _api = BinDashboardApi.instance;

  BinChain _chain = BinChain.type;

  List<BinGroupRow> _rows = [];
  bool _loading = true;
  String? _error;

  /// Root of the drill-down. This endpoint takes no location or filter params —
  /// bin_type/status/owner apply to the bin *list*, and are carried there by the
  /// drill or set on that screen.
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

  /// Switching chains changes only where a project card leads; the data on this
  /// screen is the same either way, so no re-fetch is needed.
  void _switchChain(BinChain chain) {
    if (_chain == chain) return;
    setState(() => _chain = chain);
  }

  // ── Navigation ───────────────────────────────────────────────────────────────

  void _onProjectTap(BinGroupRow row) {
    final query = _query.drillToZones(row.label);
    final crumbs = [
      const DashCrumb('Projects', routeName: kBinDashboardRoute),
      DashCrumb(row.label),
    ];

    if (_chain == BinChain.location) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: kBinZoneRoute),
          builder: (_) => BinDrillPage(
            level: BinDrillLevel.zone,
            query: query,
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
          query: query,
          row: row,
          crumbs: crumbs,
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
      body: Column(
        children: [
          BinChainBar(chain: _chain, onChanged: _switchChain),
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
        child: const DashEmptyScrollable(
          message: 'No bins found',
          hint: 'No bin data is available for any project yet.',
          icon: Icons.delete_outline_rounded,
        ),
      );
    }

    final targetNoun = _chain == BinChain.location ? 'zones' : 'bin types';

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
                    count: row.total,
                    accent: Theme.of(context).colorScheme.primary,
                    targetNoun: targetNoun,
                    onTap: () => _onProjectTap(row),
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
