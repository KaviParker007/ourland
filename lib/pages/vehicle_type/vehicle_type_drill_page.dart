// ─── Screens 2 & 3 — Vehicles by Zone / by Ward ────────────────────────────────
//
// One page serves both aggregate levels of both chains; the only differences are
// which endpoint is called and what a header tap opens:
//
//   Screen 2 (zone level)  header → Screen 3 (wards)   row → Screen 4 (zone+type)
//   Screen 3 (ward level)  header → Screen 4 (ward)    row → Screen 4 (ward+type)
//
// The incoming [VehicleQuery] already carries everything accumulated so far
// (project, then +zone_id) plus the two global filters, so no screen assembles a
// query string itself.

import 'package:flutter/material.dart';

import 'vehicle_type_models.dart';
import 'vehicle_type_query.dart';
import 'vehicle_type_service.dart';
import 'vehicle_type_ui.dart';
import 'queried_vehicles_page.dart';

enum VehicleDrillLevel { zone, ward }

class VehicleDrillPage extends StatefulWidget {
  final VehicleChain chain;
  final VehicleDrillLevel level;

  /// Scope accumulated by the caller: `project` for the zone level, plus
  /// `zone_id` / `zoneCode` for the ward level.
  final VehicleQuery query;

  const VehicleDrillPage({
    super.key,
    required this.chain,
    required this.level,
    required this.query,
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

  /// Local copy of the incoming scope. It changes only when the user recovers
  /// from a 400 via the project picker, or when the global filters change.
  late VehicleQuery _query = widget.query;

  bool get _isZone => widget.level == VehicleDrillLevel.zone;
  bool get _isLocation => widget.chain == VehicleChain.location;

  /// Filters live in the process-wide holder so they survive back-navigation;
  /// the query is re-derived from them on every fetch.
  VehicleFilters get _filters => VehicleDashFilters.instance.filters;
  VehicleQuery get _liveQuery => _query.withFilters(_filters);

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
      final q = _liveQuery;
      if (_isLocation) {
        final rows =
            _isZone ? await _api.dashByZone(q) : await _api.dashByWard(q);
        if (!mounted) return;
        setState(() => _pivotRows = rows);
      } else {
        final rows =
            _isZone ? await _api.statusByZone(q) : await _api.statusByWard(q);
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
    } catch (_) {
      // Malformed payloads must not crash the screen.
      if (mounted) {
        setState(() => _error = 'Could not read the server response.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Drill navigation ──────────────────────────────────────────────────────────

  /// Group header tapped. At the zone level this opens the wards of that zone;
  /// at the ward level it opens every vehicle in that ward (vehicle_type=All).
  void _onHeaderTap(int? id, String label) {
    if (_isZone) {
      if (id == null) return; // a zone with no id cannot be drilled
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: kVtWardRoute),
          builder: (_) => VehicleDrillPage(
            chain: widget.chain,
            level: VehicleDrillLevel.ward,
            query: _liveQuery.drillToWards(zoneId: id, zoneCode: label),
          ),
        ),
      ).then((_) => _fetch());
      return;
    }
    _openVehicles(rowId: id, rowLabel: label, cellValue: kAllFilterValue);
  }

  /// A type (Chain A) or status (Chain B) row was tapped → Screen 4, narrowed.
  void _onRowTap(int? id, String label, String cellValue) =>
      _openVehicles(rowId: id, rowLabel: label, cellValue: cellValue);

  void _openVehicles({
    required int? rowId,
    required String rowLabel,
    required String cellValue,
  }) {
    // The tapped group joins the scope: on Screen 2 it is a zone, on Screen 3 a
    // ward (whose zone is already in _liveQuery).
    var query = _isZone
        ? _liveQuery.copyWith(zoneId: rowId, zoneCode: rowLabel)
        : _liveQuery.withWard(wardId: rowId, wardCode: rowLabel);

    // Chain A narrows by vehicle_type; Chain B forwards the tapped status bucket
    // as an override and leaves vehicle_type at All.
    final String? statusOverride;
    if (_isLocation) {
      query = query.withType(cellValue);
      statusOverride = null;
    } else {
      statusOverride = cellValue;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kVtVehiclesRoute),
        builder: (_) => QueriedVehiclesPage(
          title: rowLabel,
          query: query,
          statusOverride: statusOverride,
          crumbs: _terminalCrumbs(rowLabel),
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
    // Re-fetch this screen only — the navigation stack is left untouched.
    _fetch();
  }

  void _clearFilter(VehicleFilters cleared) {
    VehicleDashFilters.instance.filters = cleared;
    _fetch();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  String get _projectLabel => _query.project ?? 'Project';
  String get _zoneLabel => _query.zoneCode ?? 'Zone';

  List<VehicleCrumb> get _crumbs {
    if (_isZone) {
      return [
        const VehicleCrumb('Projects', routeName: kVtDashboardRoute),
        VehicleCrumb(_projectLabel),
      ];
    }
    return [
      const VehicleCrumb('Projects', routeName: kVtDashboardRoute),
      VehicleCrumb(_projectLabel, routeName: kVtZoneRoute),
      VehicleCrumb(_zoneLabel),
    ];
  }

  List<VehicleCrumb> _terminalCrumbs(String rowLabel) {
    if (_isZone) {
      return [
        const VehicleCrumb('Projects', routeName: kVtDashboardRoute),
        VehicleCrumb(_projectLabel, routeName: kVtZoneRoute),
        VehicleCrumb(rowLabel),
      ];
    }
    return [
      const VehicleCrumb('Projects', routeName: kVtDashboardRoute),
      VehicleCrumb(_projectLabel, routeName: kVtZoneRoute),
      VehicleCrumb(_zoneLabel, routeName: kVtWardRoute),
      VehicleCrumb(rowLabel),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Screen 2 titles with the project; Screen 3 with project and zone.
    final title = _isZone ? _projectLabel : '$_projectLabel › $_zoneLabel';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildBody() {
    if (_loading) return const VehicleLoading();
    if (_projectChoices != null) {
      return VehicleProjectPicker(
        message: 'Select a project to continue.',
        choices: _projectChoices!,
        onPick: (c) {
          setState(() => _query = _query.withProject(c.value));
          _fetch();
        },
      );
    }
    if (_error != null) return VehicleError(message: _error!, onRetry: _fetch);

    final isEmpty = _isLocation ? _pivotRows.isEmpty : _statusRows.isEmpty;
    if (isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetch,
        child: VehicleEmptyScrollable(
          message: 'No vehicles match these filters',
          hint: _isZone
              ? 'No zones with vehicles in $_projectLabel.'
              : 'No wards with vehicles in $_zoneLabel.',
          icon: Icons.inbox_outlined,
        ),
      );
    }

    final count = _isLocation ? _pivotRows.length : _statusRows.length;
    final types = _isLocation ? unionVehicleTypes(_pivotRows) : const <String>[];
    final headerNoun = _isZone ? 'wards' : 'vehicles';

    return RefreshIndicator(
      onRefresh: _fetch,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            sliver: SliverList.builder(
              itemCount: count,
              itemBuilder: (context, index) {
                if (_isLocation) {
                  final row = _pivotRows[index];
                  return buildPivotSection(
                    context: context,
                    row: row,
                    typeColumns: types,
                    headerTargetNoun: headerNoun,
                    onHeaderTap: () => _onHeaderTap(row.id, row.label),
                    onTypeTap: (type) => _onRowTap(row.id, row.label, type),
                  );
                }
                final row = _statusRows[index];
                return buildStatusSection(
                  context: context,
                  row: row,
                  headerTargetNoun: headerNoun,
                  onHeaderTap: () => _onHeaderTap(row.id, row.label),
                  onStatusTap: (status) => _onRowTap(row.id, row.label, status),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
