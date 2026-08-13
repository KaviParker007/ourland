// ─── Vehicle Type Dashboard — Zone & Ward drill screens ────────────────────────
//
// One generic page for both the zone level (#2/#5) and ward level (#3/#6) of
// either chain. Renders location rows with tappable type/status cells, a
// breadcrumb, persisted filters and pull-to-refresh. Zone-level cells drill to
// the ward level; ward-level cells drill to the terminal vehicle list (#3b).

import 'package:flutter/material.dart';

import 'vehicle_type_models.dart';
import 'vehicle_type_service.dart';
import 'vehicle_type_ui.dart';
import 'queried_vehicles_page.dart';

enum VehicleDrillLevel { zone, ward }

class VehicleDrillPage extends StatefulWidget {
  final VehicleChain chain;
  final VehicleDrillLevel level;

  /// Project code (needed for the zone fetch and the breadcrumb).
  final String project;

  /// Parent zone (required for the ward level).
  final int? zoneId;
  final String? zoneCode;

  const VehicleDrillPage({
    super.key,
    required this.chain,
    required this.level,
    required this.project,
    this.zoneId,
    this.zoneCode,
  });

  @override
  State<VehicleDrillPage> createState() => _VehicleDrillPageState();
}

class _VehicleDrillPageState extends State<VehicleDrillPage> {
  final _api = VehicleDashboardApi.instance;

  List<VehiclePivotRow> _pivotRows = [];
  List<VehicleStatusRow> _statusRows = [];
  bool _loading = true;
  String? _error;
  List<VehicleChoice>? _projectChoices; // 400 recovery (zone level only)

  // Project can change if the user recovers from a 400 via the picker.
  late String _project = widget.project;

  VehicleFilters get _filters => VehicleDashFilters.instance.filters;
  bool get _isZone => widget.level == VehicleDrillLevel.zone;
  bool get _isLocation => widget.chain == VehicleChain.location;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _projectChoices = null;
    });
    try {
      if (_isLocation) {
        final rows = _isZone
            ? await _api.dashByZone(_project, _filters)
            : await _api.dashByWard(widget.zoneId!, _filters);
        if (!mounted) return;
        setState(() => _pivotRows = rows);
      } else {
        final rows = _isZone
            ? await _api.statusByZone(_project, _filters)
            : await _api.statusByWard(widget.zoneId!, _filters);
        if (!mounted) return;
        setState(() => _statusRows = rows);
      }
    } on VehicleDashException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.hasProjectChoices) {
          _projectChoices = e.projectChoices;
        } else {
          _error = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Drill navigation ──────────────────────────────────────────────────────────

  /// Tapping any cell/row. [value] is the tapped vehicle_type (Chain A) or
  /// vehicle_status (Chain B); 'All' when the row label/total was tapped.
  void _onCellTap(int? id, String label, String value) {
    if (_isZone) {
      // Drill to the ward level. Intermediate endpoints (#3/#6) do not accept
      // the cell value, so it is not forwarded here — it is applied only at the
      // terminal via the ward-level tap below.
      if (id == null) return; // shouldn't happen for real zones
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: kVtWardRoute),
          builder: (_) => VehicleDrillPage(
            chain: widget.chain,
            level: VehicleDrillLevel.ward,
            project: _project,
            zoneId: id,
            zoneCode: label,
          ),
        ),
      ).then((_) => _fetch());
    } else {
      _openTerminal(wardId: id, wardLabel: label, cellValue: value);
    }
  }

  void _openTerminal({
    required int? wardId,
    required String wardLabel,
    required String cellValue,
  }) {
    // Map the tapped cell + persisted filters to the terminal query.
    final String vehicleType;
    final String vehicleStatus;
    String? note;
    if (_isLocation) {
      vehicleType = cellValue; // 'All' or a specific type
      vehicleStatus = _filters.vehicleStatus;
    } else {
      vehicleStatus = cellValue; // 'All' or a mapped status
      vehicleType = 'All'; // vehicle_type filter removed from the UI

      // Idle discrepancy: the status-chain `idle` bucket excludes never-operated
      // vehicles, but vehicle_status=Idle includes them, so the list is a
      // superset of the tapped count.
      if (cellValue == 'Idle') {
        note = 'This list uses vehicle_status=Idle, which also includes '
            'never-operated vehicles — so it may show more than the Idle count.';
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kVtVehiclesRoute),
        builder: (_) => QueriedVehiclesPage(
          title: wardLabel,
          crumbs: [
            const VehicleCrumb('Projects', routeName: kVtDashboardRoute),
            VehicleCrumb(_project, routeName: kVtZoneRoute),
            VehicleCrumb(widget.zoneCode ?? 'Zone', routeName: kVtWardRoute),
            VehicleCrumb(wardLabel),
          ],
          // Forward the full location context (matches the documented request
          // ?ward_id=..&zone_id=..&project=..), not just the deepest id.
          wardId: wardId,
          zoneId: widget.zoneId,
          project: _project,
          vehicleType: vehicleType,
          vehicleStatus: vehicleStatus,
          vehicleOwner: _filters.vehicleOwner,
          note: note,
        ),
      ),
    ).then((_) => _fetch());
  }

  // ── Filters ─────────────────────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────────

  List<VehicleCrumb> get _crumbs {
    if (_isZone) {
      return [
        const VehicleCrumb('Projects', routeName: kVtDashboardRoute),
        VehicleCrumb(_project),
      ];
    }
    return [
      const VehicleCrumb('Projects', routeName: kVtDashboardRoute),
      VehicleCrumb(_project, routeName: kVtZoneRoute),
      VehicleCrumb(widget.zoneCode ?? 'Zone'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = _isZone ? _project : (widget.zoneCode ?? 'Zone');
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        ],
      ),
      body: Column(
        children: [
          VehicleBreadcrumb(crumbs: _crumbs),
          VehicleFilterChips(filters: _filters, onClear: _clearFilter),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const VehicleLoading();
    if (_projectChoices != null) {
      return VehicleProjectPicker(
        message: 'Select a project to continue.',
        choices: _projectChoices!,
        onPick: (c) {
          setState(() => _project = c.value);
          _fetch();
        },
      );
    }
    if (_error != null) return VehicleError(message: _error!, onRetry: _fetch);

    final isEmpty = _isLocation ? _pivotRows.isEmpty : _statusRows.isEmpty;
    if (isEmpty) {
      return VehicleEmpty(
        message: _isZone ? 'No zones found' : 'No wards found',
        hint: 'No data for this selection and filters.',
        icon: Icons.inbox_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
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
          onDrill: (v) => _onCellTap(row.id, row.label, v),
        ),
    ];
  }

  List<Widget> _statusCards() {
    return [
      for (final row in _statusRows)
        buildStatusCard(
          context: context,
          row: row,
          onDrill: (v) => _onCellTap(row.id, row.label, v),
        ),
    ];
  }
}
