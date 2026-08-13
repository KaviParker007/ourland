// ─── Vehicle Type Dashboard — Terminal vehicle list (#3b) ──────────────────────
//
// Shared terminal for both chains. Reached by tapping a cell at the ward level;
// forwards the deepest location id plus the tapped-cell selection (vehicle_type
// for Chain A, vehicle_status for Chain B) alongside the persisted filters.

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import 'vehicle_type_models.dart';
import 'vehicle_type_service.dart';
import 'vehicle_type_ui.dart';

class QueriedVehiclesPage extends StatefulWidget {
  final String title;
  final List<VehicleCrumb> crumbs;

  // Deepest available location id (only one is normally set).
  final int? wardId;
  final int? zoneId;
  final String? project;

  // Effective filter values for the terminal query.
  final String vehicleType;
  final String vehicleStatus;
  final String vehicleOwner;

  /// Optional advisory note (e.g. the Idle-superset discrepancy for Chain B).
  final String? note;

  const QueriedVehiclesPage({
    super.key,
    required this.title,
    required this.crumbs,
    this.wardId,
    this.zoneId,
    this.project,
    required this.vehicleType,
    required this.vehicleStatus,
    required this.vehicleOwner,
    this.note,
  });

  @override
  State<QueriedVehiclesPage> createState() => _QueriedVehiclesPageState();
}

class _QueriedVehiclesPageState extends State<QueriedVehiclesPage> {
  final _api = VehicleDashboardApi.instance;

  List<VehicleRecord> _vehicles = [];
  bool _loading = true;
  String? _error;

  // Local, editable filters (vehicle_status + vehicle_owner) seeded from the
  // values forwarded by the drill. vehicle_type stays fixed to the carried cell
  // selection — the Vehicle Type filter option was intentionally removed.
  late VehicleFilters _filters = VehicleFilters(
    vehicleStatus: widget.vehicleStatus,
    vehicleOwner: widget.vehicleOwner,
  );

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
      final data = await _api.queriedVehicles(
        wardId: widget.wardId,
        zoneId: widget.zoneId,
        project: widget.project,
        vehicleType: widget.vehicleType,
        vehicleStatus: _filters.vehicleStatus,
        vehicleOwner: _filters.vehicleOwner,
      );
      if (!mounted) return;
      setState(() => _vehicles = data);
    } on VehicleDashException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFilters() async {
    final updated = await showVehicleFilterSheet(context, _filters);
    if (updated != null) {
      setState(() => _filters = updated);
      _fetch();
    }
  }

  void _clearFilter(VehicleFilters cleared) {
    setState(() => _filters = cleared);
    _fetch();
  }

  /// A card is swipeable (to log an idle reason) only when no reason has been
  /// logged today — i.e. `is_reasoned_today` is null. Once a reason exists the
  /// card is locked and rendered distinctly.
  bool _canReason(VehicleRecord v) => v.isReasonedToday == null;

  Future<void> _addIdleReason(VehicleRecord v) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Idle Reason',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(ctx).colorScheme.primary)),
            const SizedBox(height: 8),
            Text(v.vehicleNumber,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: reasonController,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter reason for idle status...',
                  border: OutlineInputBorder(),
                  labelText: 'Reason',
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter a reason'
                    : null,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Date: $currentDate',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withAlpha(140))),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final ok = await _api.submitIdleReason(
        vehicleId: v.id,
        reason: reasonController.text.trim(),
        idleDate: currentDate,
      );
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      if (ok) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Idle reason submitted successfully!'),
          backgroundColor: Colors.green,
        ));
        _fetch(); // refresh so is_reasoned_today reflects the new reason
      } else {
        messenger.showSnackBar(const SnackBar(
          content: Text('Failed to submit idle reason.'),
          backgroundColor: Colors.red,
        ));
      }
    } on VehicleDashException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title,
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
          VehicleBreadcrumb(crumbs: widget.crumbs),
          VehicleFilterChips(filters: _filters, onClear: _clearFilter),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const VehicleLoading();
    if (_error != null) return VehicleError(message: _error!, onRetry: _fetch);
    if (_vehicles.isEmpty) {
      return const VehicleEmpty(
        message: 'No vehicles found',
        hint: 'No vehicle records match this selection.',
        icon: Icons.search_off_rounded,
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _vehicles.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _banner();
          final vehicle = _vehicles[index - 1];
          final card = _VehicleCard(vehicle: vehicle);
          // Swipeable only while no idle reason has been logged today; once
          // reasoned, the card is locked (and visually distinct).
          if (!_canReason(vehicle)) return card;
          return Slidable(
            key: ValueKey('vt-vehicle-${vehicle.id}'),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.35,
              children: [
                SlidableAction(
                  onPressed: (_) => _addIdleReason(vehicle),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  icon: Icons.message_outlined,
                  label: 'Idle Reason',
                ),
              ],
            ),
            child: card,
          );
        },
      ),
    );
  }

  Widget _banner() {
    final count = _vehicles.length;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(15), width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.directions_car_filled_outlined,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('$count ${count == 1 ? 'vehicle' : 'vehicles'} found',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
        if (widget.note != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(28),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withAlpha(110)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.note!,
                      style: const TextStyle(fontSize: 12, color: Colors.amber)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Vehicle card ────────────────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final VehicleRecord vehicle;
  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    final typeColor = vehicleTypeColor(vehicle.vehicleType);
    final statusColor = vehicleStatusColor(vehicle.vehicleStatus);

    // A reason logged today locks the card (no swipe) and marks it distinctly.
    final reasoned =
        vehicle.isReasonedToday != null && vehicle.isReasonedToday!.isNotEmpty;
    const reasonedColor = Color(0xFF43A047); // green = "done for today"
    final cardColor = reasoned
        ? Color.alphaBlend(reasonedColor.withAlpha(28), surface)
        : null;
    final accent = reasoned ? reasonedColor : typeColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: reasoned
            ? BorderSide(color: reasonedColor.withAlpha(140), width: 1.2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: number + reasoned lock + status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    vehicle.vehicleNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        letterSpacing: 0.4),
                  ),
                ),
                if (reasoned) ...[
                  _lockPill('REASONED', reasonedColor),
                  const SizedBox(width: 6),
                ],
                if (vehicle.vehicleStatus.isNotEmpty)
                  _pill(vehicle.vehicleStatus.toUpperCase(), statusColor),
              ],
            ),
            const SizedBox(height: 6),
            // Type + project
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _pill(vehicle.vehicleType, typeColor),
                if (vehicle.project != '—') _pill(vehicle.project, onSurface.withAlpha(160)),
                if (vehicle.zoneCode != null && vehicle.zoneCode!.isNotEmpty)
                  _outlineChip(Icons.location_city_outlined, vehicle.zoneCode!),
              ],
            ),
            if (vehicle.wardCodes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.map_outlined,
                      size: 15, color: onSurface.withAlpha(130)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final w in vehicle.wardCodes)
                          _outlineChip(null, w),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (vehicle.isReasonedToday != null &&
                vehicle.isReasonedToday!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withAlpha(80)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined,
                        size: 15, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Idle reason: ${vehicle.isReasonedToday}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lockPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(120), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(110), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _outlineChip(IconData? icon, String label) {
    return Builder(builder: (context) {
      final onSurface = Theme.of(context).colorScheme.onSurface;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: onSurface.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: onSurface.withAlpha(35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: onSurface.withAlpha(150)),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: onSurface.withAlpha(200))),
          ],
        ),
      );
    });
  }
}
