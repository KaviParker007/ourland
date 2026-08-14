// ─── Screen 1 — Vehicles by Project ────────────────────────────────────────────
//
// Top of both drill chains. A toggle switches between "By Location" (vehicle_type
// pivot, #1→#2→#3) and "By Status" (status buckets, #4→#5→#6).
//
//   • tapping a project header  → Screen 2 (zones of that project)
//   • tapping a vehicle-type row → Screen 4 (that project + that type)
//
// Filters set here are held in VehicleDashFilters and carried into every
// subsequent request via the VehicleQuery each screen copies and extends.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

import 'vehicle_type_models.dart';
import 'vehicle_type_query.dart';
import 'vehicle_type_service.dart';
import 'vehicle_type_ui.dart';
import 'vehicle_type_drill_page.dart';
import 'queried_vehicles_page.dart';

class VehicleTypeDashboardPage extends StatefulWidget {
  const VehicleTypeDashboardPage({super.key});

  @override
  State<VehicleTypeDashboardPage> createState() =>
      _VehicleTypeDashboardPageState();
}

class _VehicleTypeDashboardPageState extends State<VehicleTypeDashboardPage> {
  final _api = VehicleDashboardApi.instance;

  VehicleChain _chain = VehicleChain.location;

  List<VehiclePivotRow> _pivotRows = [];
  List<VehicleStatusRow> _statusRows = [];
  bool _loading = false;
  String? _error;

  VehicleFilters get _filters => VehicleDashFilters.instance.filters;
  bool get _isLocation => _chain == VehicleChain.location;

  /// Root of the drill-down: no location scope yet, just the live filters.
  VehicleQuery get _query => VehicleQuery(filters: _filters);

  @override
  void initState() {
    super.initState();
    // Fresh entry → start from clean filters (they then persist down the stack).
    VehicleDashFilters.instance.reset();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('menu', 'vehicle_type_dashboard');
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isLocation) {
        final rows = await _api.dashByProject(_query);
        if (!mounted) return;
        setState(() => _pivotRows = rows);
      } else {
        final rows = await _api.statusByProject(_query);
        if (!mounted) return;
        setState(() => _statusRows = rows);
      }
    } on VehicleDashException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      // Malformed payloads must not crash the screen.
      if (mounted) {
        setState(() => _error = 'Could not read the server response.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchChain(VehicleChain chain) {
    if (_chain == chain) return;
    setState(() {
      _chain = chain;
      _pivotRows = [];
      _statusRows = [];
    });
    _fetch();
  }

  // ── Drill navigation ──────────────────────────────────────────────────────────

  /// Project header → Screen 2.
  void _openZones(String project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kVtZoneRoute),
        builder: (_) => VehicleDrillPage(
          chain: _chain,
          level: VehicleDrillLevel.zone,
          query: _query.drillToZones(project),
        ),
      ),
    ).then((_) => _fetch());
  }

  /// Vehicle-type row → Screen 4, scoped to this project and type.
  void _openVehicles({
    required String project,
    required String cellValue,
  }) {
    // Chain A narrows by vehicle_type; Chain B forwards the tapped status bucket
    // and leaves vehicle_type at All.
    final query = _isLocation
        ? _query.drillToZones(project).withType(cellValue)
        : _query.drillToZones(project);

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kVtVehiclesRoute),
        builder: (_) => QueriedVehiclesPage(
          title: project,
          query: query,
          statusOverride: _isLocation ? null : cellValue,
          crumbs: [
            const VehicleCrumb('Projects', routeName: kVtDashboardRoute),
            VehicleCrumb(project),
          ],
          note: _isLocation ? null : idleSupersetNote(cellValue),
        ),
      ),
    ).then((_) => _fetch());
  }

  // ── Filters ───────────────────────────────────────────────────────────────────

  Future<void> _openFilters() async {
    final updated = await showVehicleFilterSheet(context, _filters);
    if (updated == null || updated == _filters) return;
    VehicleDashFilters.instance.filters = updated;
    _fetch();
  }

  void _clearFilter(VehicleFilters cleared) {
    VehicleDashFilters.instance.filters = cleared;
    _fetch();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Type',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: _openFilters,
            icon: Icon(_filters.hasActive
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
          ),
          const NotificationBellWidget(),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          _buildControls(),
          VehicleFilterBar(
            filters: _filters,
            onClear: _clearFilter,
            onEdit: _openFilters,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildControls() {
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
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black.withAlpha(40),
              border: Border.all(color: Colors.white.withAlpha(18), width: 1),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final chain in VehicleChain.values)
                  _ChainTab(
                    label: chain.label,
                    isActive: _chain == chain,
                    onTap: () => _switchChain(chain),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const VehicleLoading();
    if (_error != null) return VehicleError(message: _error!, onRetry: _fetch);

    final isEmpty = _isLocation ? _pivotRows.isEmpty : _statusRows.isEmpty;
    if (isEmpty) {
      // Pull-to-refresh has to stay reachable in the empty state, so the message
      // is hosted in a scrollable rather than a bare Center.
      return RefreshIndicator(
        onRefresh: _fetch,
        child: const VehicleEmptyScrollable(
          message: 'No vehicles match these filters',
          hint: 'Try clearing the status or owner filter.',
          icon: Icons.directions_car_outlined,
        ),
      );
    }

    final count = _isLocation ? _pivotRows.length : _statusRows.length;
    final types = _isLocation ? unionVehicleTypes(_pivotRows) : const <String>[];

    return RefreshIndicator(
      onRefresh: _fetch,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
            sliver: SliverList.builder(
              itemCount: count,
              itemBuilder: (context, index) {
                if (_isLocation) {
                  final row = _pivotRows[index];
                  return buildPivotSection(
                    context: context,
                    row: row,
                    typeColumns: types,
                    headerTargetNoun: 'zones',
                    onHeaderTap: () => _openZones(row.label),
                    onTypeTap: (type) =>
                        _openVehicles(project: row.label, cellValue: type),
                  );
                }
                final row = _statusRows[index];
                return buildStatusSection(
                  context: context,
                  row: row,
                  headerTargetNoun: 'zones',
                  onHeaderTap: () => _openZones(row.label),
                  onStatusTap: (status) =>
                      _openVehicles(project: row.label, cellValue: status),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chain toggle tab (matches the Shift Dashboard segmented control) ────────────

class _ChainTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ChainTab({
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
