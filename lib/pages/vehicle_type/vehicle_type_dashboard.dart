// ─── Vehicle Type Dashboard — Entry (project level) ────────────────────────────
//
// Top of both drill chains. A toggle switches between "By Location" (vehicle_type
// pivot, #1→#2→#3) and "By Status" (status buckets, #4→#5→#6). Tapping a project
// row/cell drills to the zone level; filters set here persist across the stack.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

import 'vehicle_type_models.dart';
import 'vehicle_type_service.dart';
import 'vehicle_type_ui.dart';
import 'vehicle_type_drill_page.dart';

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
        final rows = await _api.dashByProject(_filters);
        if (!mounted) return;
        setState(() => _pivotRows = rows);
      } else {
        final rows = await _api.statusByProject(_filters);
        if (!mounted) return;
        setState(() => _statusRows = rows);
      }
    } on VehicleDashException catch (e) {
      if (mounted) setState(() => _error = e.message);
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

  void _openZone(String project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kVtZoneRoute),
        builder: (_) => VehicleDrillPage(
          chain: _chain,
          level: VehicleDrillLevel.zone,
          project: project,
        ),
      ),
    ).then((_) => _fetch());
  }

  Future<void> _openFilters() async {
    final updated = await showVehicleFilterSheet(context, _filters);
    if (updated != null) {
      VehicleDashFilters.instance.filters = updated;
      _fetch();
    }
  }

  void _clearFilter(VehicleFilters cleared) {
    VehicleDashFilters.instance.filters = cleared;
    _fetch();
  }

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
          VehicleFilterChips(filters: _filters, onClear: _clearFilter),
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
      return const VehicleEmpty(
        message: 'No projects found',
        hint: 'No vehicle data for the current filters.',
        icon: Icons.directions_car_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
        children: _isLocation ? _pivotCards() : _statusCards(),
      ),
    );
  }

  List<Widget> _pivotCards() {
    final types = unionVehicleTypes(_pivotRows);
    return [
      for (final row in _pivotRows)
        buildPivotCard(
          context: context,
          row: row,
          typeColumns: types,
          // Project level: cell value isn't used by #2, so any tap drills to
          // this project's zones.
          onDrill: (_) => _openZone(row.label),
        ),
    ];
  }

  List<Widget> _statusCards() {
    return [
      for (final row in _statusRows)
        buildStatusCard(
          context: context,
          row: row,
          onDrill: (_) => _openZone(row.label),
        ),
    ];
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
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
    );
  }
}
