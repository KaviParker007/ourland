// ─── Screen 4 — Vehicle list (leaf) ────────────────────────────────────────────
//
// Reached from any of the three aggregate screens. The incoming [VehicleQuery]
// already carries the full accumulated scope (project → +zone_id → +ward_id), the
// selected vehicle type and both global filters, so this screen only decides how
// to render the result.
//
// Locked cards: a vehicle whose `is_reasoned_today` is set already has an idle
// reason logged for today. Such a card is marked with a lock pill, tinted down,
// and does not offer the swipe action — a second reason for the same day would be
// rejected by the backend.

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import 'vehicle_type_models.dart';
import 'vehicle_type_query.dart';
import 'vehicle_type_service.dart';
import 'vehicle_type_ui.dart';

class QueriedVehiclesPage extends StatefulWidget {
  /// The deepest location the user tapped — used as the app-bar title.
  final String title;
  final List<VehicleCrumb> crumbs;

  /// Full accumulated scope + selected type + carried filters.
  final VehicleQuery query;

  /// Chain B only: the tapped status bucket, sent instead of the carried
  /// `vehicle_status` filter.
  final String? statusOverride;

  /// Optional advisory note (e.g. the Idle-superset discrepancy for Chain B).
  final String? note;

  const QueriedVehiclesPage({
    super.key,
    required this.title,
    required this.crumbs,
    required this.query,
    this.statusOverride,
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

  /// Local scope. Editable here because the leaf screen owns its own filter
  /// state: changing a filter must not disturb the aggregate screens the user
  /// can still go back to.
  late VehicleQuery _query = widget.query;

  /// Chain B's forwarded bucket wins over the carried filter until the user
  /// edits the filters here, at which point their choice takes over.
  String? _statusOverride;

  VehicleFilters get _filters => _query.filters;

  @override
  void initState() {
    super.initState();
    _statusOverride = widget.statusOverride;
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.queriedVehicles(
        _query,
        statusOverride: _statusOverride,
      );
      if (!mounted) return;
      setState(() => _vehicles = data);
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

  // ── Filters ───────────────────────────────────────────────────────────────────

  /// The status actually in force — the forwarded bucket, else the filter.
  VehicleFilters get _displayFilters => _statusOverride == null
      ? _filters
      : _filters.copyWith(vehicleStatus: _statusOverride);

  Future<void> _openFilters() async {
    final updated = await showVehicleFilterSheet(context, _displayFilters);
    if (updated == null || updated == _displayFilters) return;
    setState(() {
      _query = _query.withFilters(updated);
      _statusOverride = null; // the user's explicit choice replaces the bucket
    });
    _fetch();
  }

  void _clearFilter(VehicleFilters cleared) {
    setState(() {
      _query = _query.withFilters(cleared);
      _statusOverride = null;
    });
    _fetch();
  }

  // ── Idle reason ───────────────────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: _openFilters,
            icon: Icon(_displayFilters.hasActive
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          VehicleBreadcrumb(crumbs: widget.crumbs),
          VehicleFilterBar(
            filters: _displayFilters,
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
    if (_error != null) return VehicleError(message: _error!, onRetry: _fetch);
    if (_vehicles.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetch,
        child: const VehicleEmptyScrollable(
          message: 'No vehicles match these filters',
          hint: 'Try a different status or owner, or go back a level.',
          icon: Icons.search_off_rounded,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            sliver: SliverToBoxAdapter(child: _provenanceHeader()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverList.builder(
              itemCount: _vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = _vehicles[index];
                final card = VehicleCard(vehicle: vehicle);
                // Locked cards do not accept the action an unlocked card does.
                if (vehicle.isLocked) return card;
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
          ),
        ],
      ),
    );
  }

  /// States where the list came from — project / zone / ward and vehicle type —
  /// and how many vehicles came back.
  Widget _provenanceHeader() {
    final count = _vehicles.length;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: '$count ${count == 1 ? 'vehicle' : 'vehicles'} '
              'in ${_query.describeScope}',
          excludeSemantics: true,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(15), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_car_filled_outlined,
                        size: 18, color: primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$count ${count == 1 ? 'vehicle' : 'vehicles'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _query.describeScope,
                  style: TextStyle(
                      fontSize: 12, color: onSurface.withAlpha(150)),
                ),
              ],
            ),
          ),
        ),
        if (widget.note != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(28),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withAlpha(110)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.note!,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.amber)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Vehicle card ────────────────────────────────────────────────────────────────

/// One vehicle. Public so widget tests can mount it directly.
///
/// Shows registration number (primary line), vehicle type, location code and the
/// `vehicle_status` returned by the API — coloured by the app-wide
/// [vehicleStatusColor] mapping, never a local palette.
class VehicleCard extends StatelessWidget {
  final VehicleRecord vehicle;
  const VehicleCard({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    final typeColor = vehicleTypeColor(vehicle.vehicleType);
    final statusColor = vehicleStatusColor(vehicle.vehicleStatus);

    final locked = vehicle.isLocked;
    const lockedColor = Color(0xFF43A047); // green = "done for today"
    final cardColor =
        locked ? Color.alphaBlend(lockedColor.withAlpha(28), surface) : null;
    final accent = locked ? lockedColor : typeColor;
    // Reduced emphasis on a locked card — it is no longer actionable.
    final contentOpacity = locked ? 0.72 : 1.0;

    final locationCode = vehicle.zoneCode?.isNotEmpty == true
        ? vehicle.zoneCode!
        : (vehicle.wardCodes.isNotEmpty ? vehicle.wardCodes.first : null);

    return Semantics(
      container: true,
      label: [
        vehicle.vehicleNumber,
        vehicle.vehicleType,
        ?locationCode,
        if (vehicle.vehicleStatus.isNotEmpty) vehicle.vehicleStatus,
        if (locked) 'locked, idle reason already logged today',
      ].join(', '),
      child: ExcludeSemantics(
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: locked
                ? BorderSide(color: lockedColor.withAlpha(140), width: 1.2)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 3,
          child: Container(
            constraints:
                const BoxConstraints(minHeight: kVehicleMinTapTarget),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Opacity(
              opacity: contentOpacity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Registration number + lock + status badge.
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
                      if (locked) ...[
                        _lockPill('LOCKED', lockedColor),
                        const SizedBox(width: 6),
                      ],
                      if (vehicle.vehicleStatus.isNotEmpty)
                        _pill(vehicle.vehicleStatus.toUpperCase(), statusColor),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Vehicle type + project + location code.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _pill(vehicle.vehicleType, typeColor),
                      if (vehicle.project != '—')
                        _pill(vehicle.project, onSurface.withAlpha(160)),
                      if (vehicle.zoneCode != null &&
                          vehicle.zoneCode!.isNotEmpty)
                        _outlineChip(
                            Icons.location_city_outlined, vehicle.zoneCode!),
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
                  if (vehicle.idleReasonText != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
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
                              'Idle reason: ${vehicle.idleReasonText}',
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
          ),
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
                style:
                    TextStyle(fontSize: 11, color: onSurface.withAlpha(200))),
          ],
        ),
      );
    });
  }
}
