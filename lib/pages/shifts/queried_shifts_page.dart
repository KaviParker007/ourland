import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:ourlandnew/services/dash_api.dart';
import 'rotate_shift.dart';
import 'end_shift.dart';
import 'shift_activity_image_page.dart';
import 'shift_dash_models.dart';
import 'shift_dash_service.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDateTime(Object? val) {
  if (val == null) return '—';
  try {
    final dt = DateTime.parse(val.toString());
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  } catch (_) {
    return val.toString();
  }
}

String _fmtDate(Object? val) {
  if (val == null) return '—';
  try {
    final dt = DateTime.parse(val.toString());
    return DateFormat('dd MMM yyyy').format(dt);
  } catch (_) {
    return val.toString();
  }
}

/// Checklist values arrive as booleans or strings; blank reads as absent.
String? _fmtValue(Object? val) {
  if (val == null) return null;
  if (val is bool) return val ? 'Yes' : 'No';
  final s = val.toString().trim();
  if (s.isEmpty) return null;
  if (s.toLowerCase() == 'true') return 'Yes';
  if (s.toLowerCase() == 'false') return 'No';
  return s;
}

// ── Page ─────────────────────────────────────────────────────────────────────

/// The shift records behind a dashboard cell (drf_list_queried_shifts_v2).
class QueriedShiftsPage extends StatefulWidget {
  final ShiftListFilter filter;

  const QueriedShiftsPage({super.key, required this.filter});

  @override
  State<QueriedShiftsPage> createState() => _QueriedShiftsPageState();
}

class _QueriedShiftsPageState extends State<QueriedShiftsPage> {
  final _api = ShiftDashboardApi.instance;
  List<Map<String, dynamic>> shifts = [];
  bool isLoading = true;
  String? error;

  ShiftListFilter get _filter => widget.filter;

  @override
  void initState() {
    super.initState();
    _fetchShifts();
  }

  Future<void> _fetchShifts() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final rows = await _api.queriedShifts(_filter);
      if (!mounted) return;
      setState(() => shifts = rows);
    } on DashApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Network error. Please retry.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// The deepest selected scope name — used as the AppBar title.
  String get _title =>
      _filter.wardCode ??
      _filter.creatorLabel ??
      _filter.zoneCode ??
      _filter.project ??
      'Shifts';

  @override
  Widget build(BuildContext context) {
    final byCreator = _filter.createdBy != null;
    final crumbs = <_Crumb>[
      _Crumb(byCreator ? 'Creators' : 'Projects', tappable: true),
      if (_filter.project != null) _Crumb(_filter.project!, tappable: true),
      if (_filter.zoneCode != null) _Crumb(_filter.zoneCode!, tappable: true),
      if (_filter.wardCode != null) _Crumb(_filter.wardCode!, tappable: true),
      if (_filter.creatorLabel != null)
        _Crumb(_filter.creatorLabel!, tappable: true),
    ];
    // The deepest crumb is this page.
    crumbs[crumbs.length - 1] = _Crumb(crumbs.last.label, tappable: false);
    final vehicleType = _filter.vehicleType;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (vehicleType != null)
              Text(
                vehicleType,
                style: TextStyle(
                  fontSize: 12,
                  color: vehicleTypeColor(vehicleType),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _Breadcrumb(
            crumbs: crumbs,
            onCrumbTap: () => Navigator.pop(context),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? _buildError()
                    : shifts.isEmpty
                        ? _buildEmpty()
                        : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 52,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha(160),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchShifts,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return RefreshIndicator(
      onRefresh: _fetchShifts,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 56,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(70)),
                      const SizedBox(height: 14),
                      const Text(
                        'No shifts found',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try adjusting your filters.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(120),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _fetchShifts,
      child: SlidableAutoCloseBehavior(
        child: CustomScrollView(
          slivers: [
            // Result count + filter summary banner
            SliverToBoxAdapter(
              child: _ResultBanner(
                count: shifts.length,
                query: _filter.query,
                vehicleType: _filter.vehicleType,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ShiftCard(
                    shift: shifts[index],
                    status: _filter.query.status,
                  ),
                  childCount: shifts.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Breadcrumb ────────────────────────────────────────────────────────────────
// Tapping any earlier crumb pops back to the Shift Dashboard, which still holds
// the selected filters and expanded project/zone.

class _Breadcrumb extends StatelessWidget {
  final List<_Crumb> crumbs;
  final VoidCallback onCrumbTap;

  const _Breadcrumb({required this.crumbs, required this.onCrumbTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < crumbs.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 16, color: onSurface.withAlpha(90)),
                ),
              GestureDetector(
                onTap: crumbs[i].tappable ? onCrumbTap : null,
                child: Text(
                  crumbs[i].label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: i == crumbs.length - 1
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: crumbs[i].tappable
                        ? primary
                        : onSurface.withAlpha(200),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Crumb {
  final String label;
  final bool tappable;
  _Crumb(this.label, {required this.tappable});
}

// ── Result count + filter banner ─────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  final int count;
  final ShiftDashQuery query;
  final String? vehicleType;

  const _ResultBanner({
    required this.count,
    required this.query,
    this.vehicleType,
  });

  @override
  Widget build(BuildContext context) {
    final status = query.status;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
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
              Icon(Icons.list_alt_rounded,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count ${count == 1 ? 'shift' : 'shifts'} found',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (vehicleType != null) ...[
                _Badge(
                    label: vehicleType!, color: vehicleTypeColor(vehicleType)),
                const SizedBox(width: 6),
              ],
              _Badge(label: status.apiValue, color: status.color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            status.usesDate
                ? '${status.description} · ${DateFormat('dd MMM yyyy').format(query.date)}'
                : status.description,
            style: TextStyle(fontSize: 11.5, color: onSurface.withAlpha(140)),
          ),
        ],
      ),
    );
  }
}

// ── Individual shift card ─────────────────────────────────────────────────────

class _ShiftCard extends StatefulWidget {
  final Map<String, dynamic> shift;

  /// The status the list was queried for. The backend classified every record
  /// in the response by it, so it is shown as-is rather than re-derived from
  /// the device clock.
  final ShiftStatus status;

  const _ShiftCard({required this.shift, required this.status});

  @override
  State<_ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends State<_ShiftCard> {
  bool _showDetails = false;

  Map<String, dynamic> get shift => widget.shift;

  /// Checklist and remark fields, shown under "Details" when present.
  List<(IconData, String, String)> get _details => [
        (Icons.business_outlined, 'Owner', _fmtValue(shift['owner'])),
        (Icons.place_outlined, 'Zone', _fmtValue(shift['zone'])),
        (Icons.badge_outlined, 'Licence',
            _fmtValue(shift['acting_driver_license'])),
        (Icons.notes_outlined, 'Driver note',
            _fmtValue(shift['other_driver_remark'])),
        (Icons.speaker_outlined, 'Audio', _fmtValue(shift['audio_system'])),
        (Icons.delete_outline, 'Barrel', _fmtValue(shift['barrel'])),
        (Icons.view_week_outlined, 'Rack', _fmtValue(shift['rack'])),
        (Icons.cleaning_services_outlined, 'Broom', _fmtValue(shift['broom'])),
        (Icons.shopping_basket_outlined, 'Annakoodai',
            _fmtValue(shift['annakoodai'])),
        (Icons.oil_barrel_outlined, 'Engine oil',
            _fmtValue(shift['engine_oil_level'])),
        (Icons.water_drop_outlined, 'Coolant',
            _fmtValue(shift['coolant_oil_level'])),
        (Icons.report_problem_outlined, 'Complaint',
            _fmtValue(shift['complaint_details'])),
        (Icons.comment_outlined, 'Remark', _fmtValue(shift['shift_remark'])),
      ]
          .where((d) => d.$3 != null)
          .map((d) => (d.$1, d.$2, d.$3!))
          .toList();

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final isActive = shift['end_time'] == null;
    final vehicleType = shift['vehicle_type']?.toString();
    final vtColor = vehicleTypeColor(vehicleType);
    final shiftId = (shift['id'] as num?)?.toInt() ?? 0;
    final details = _details;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final card = Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ──────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: vtColor, width: 4),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle number
                    Expanded(
                      child: Text(
                        shift['vehicle']?.toString() ?? '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    // Status + vehicle type badges
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Badge(label: status.apiValue, color: status.color),
                        if (vehicleType != null) ...[
                          const SizedBox(height: 4),
                          _Badge(label: vehicleType, color: vtColor),
                        ],
                      ],
                    ),
                  ],
                ),
                // Shift + Zone + Date subtitle line
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 13, color: onSurface.withAlpha(120)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        [
                          if (shift['shift_name'] != null)
                            'Shift ${shift['shift_name']}',
                          if (shift['zone_code'] != null)
                            shift['zone_code'].toString(),
                          if (shift['shift_date'] != null)
                            _fmtDate(shift['shift_date']),
                        ].join('  ·  '),
                        style: TextStyle(
                          fontSize: 12,
                          color: onSurface.withAlpha(150),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Divider ──────────────────────────────────────────────────────
          Divider(height: 1, color: Colors.white.withAlpha(12)),

          // ── Info section ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              children: [
                // driverr: assigned driver's name, or the free-text name of a
                // non-regular driver.
                if (shift['driverr'] != null)
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Driver',
                    value: [
                      shift['driverr'].toString(),
                      if (_fmtValue(shift['driver_type']) != null)
                        _fmtValue(shift['driver_type'])!,
                    ].join('  ·  '),
                  ),
                if (shift['started_by'] != null)
                  _InfoRow(
                    icon: Icons.manage_accounts_outlined,
                    label: 'Started by',
                    value: shift['started_by'].toString(),
                  ),
              ],
            ),
          ),

          // ── Divider ──────────────────────────────────────────────────────
          Divider(height: 1, color: Colors.white.withAlpha(12)),

          // ── Time & KM section ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TimeChip(
                        icon: Icons.play_circle_outline,
                        label: 'Started',
                        value: _fmtDateTime(shift['start_time']),
                        color: Colors.green,
                      ),
                      if (!isActive) ...[
                        const SizedBox(height: 4),
                        _TimeChip(
                          icon: Icons.stop_circle_outlined,
                          label: 'Ended',
                          value: _fmtDateTime(shift['end_time']),
                          color: Colors.redAccent,
                        ),
                      ],
                    ],
                  ),
                ),
                // KM info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (shift['out_km'] != null)
                      _KmBadge(
                          label: 'Out',
                          km: shift['out_km'].toString()),
                    if (!isActive && shift['in_km'] != null) ...[
                      const SizedBox(height: 4),
                      _KmBadge(
                          label: 'In',
                          km: shift['in_km'].toString()),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Details (checklist, complaint, remark) ───────────────────────
          if (details.isNotEmpty) ...[
            Divider(height: 1, color: Colors.white.withAlpha(12)),
            InkWell(
              onTap: () => setState(() => _showDetails = !_showDetails),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      _showDetails ? 'Hide details' : 'Show details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _showDetails ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _showDetails
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Column(
                        children: [
                          for (final d in details)
                            _InfoRow(icon: d.$1, label: d.$2, value: d.$3),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );

    if (!isActive) return card;

    return Slidable(
      key: ValueKey(shiftId),
      // Left-to-right swipe: attach an activity photo to the current trip.
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShiftActivityImagePage(
                  shiftId: shiftId,
                  vehicle: shift['vehicle']?.toString(),
                ),
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            borderRadius: BorderRadius.circular(15),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            icon: Icons.add_a_photo_outlined,
            label: 'Image',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RotateShiftPage(shiftId: shiftId)),
            ),
            backgroundColor:
                Theme.of(context).colorScheme.inversePrimary,
            foregroundColor: Colors.white,
            borderRadius: BorderRadius.circular(15),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            icon: Icons.repeat_rounded,
            label: 'Rotate',
          ),
          SlidableAction(
            onPressed: (_) => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EndShiftPage(shiftId: shiftId)),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
            borderRadius: BorderRadius.circular(15),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            icon: Icons.timer_off_rounded,
            label: 'End',
          ),
        ],
      ),
      child: card,
    );
  }
}

// ── Small reusable card sub-widgets ─────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty || value.trim() == '·') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 15,
              color:
                  Theme.of(context).colorScheme.onSurface.withAlpha(130)),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha(130),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TimeChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color.withAlpha(200)),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha(120),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}

class _KmBadge extends StatelessWidget {
  final String label;
  final String km;

  const _KmBadge({required this.label, required this.km});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.white.withAlpha(20), width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha(120),
            ),
          ),
          Text(
            '$km km',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
