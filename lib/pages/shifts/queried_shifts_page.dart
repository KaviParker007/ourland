import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:ourlandnew/config.dart';
import 'rotate_shift.dart';
import 'end_shift.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

const _kVtColors = <String, Color>{
  'Tipper':    Color(0xFFFF7043),
  'Tractor':   Color(0xFF42A5F5),
  'LCV':       Color(0xFF66BB6A),
  'EMV':       Color(0xFFAB47BC),
  'Compactor': Color(0xFF26C6DA),
};

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

// ── Page ─────────────────────────────────────────────────────────────────────

class QueriedShiftsPage extends StatefulWidget {
  final Map<String, String?> params;
  final String username;
  final String password;

  const QueriedShiftsPage({
    super.key,
    required this.params,
    required this.username,
    required this.password,
  });

  @override
  State<QueriedShiftsPage> createState() => _QueriedShiftsPageState();
}

class _QueriedShiftsPageState extends State<QueriedShiftsPage> {
  List shifts = [];
  bool isLoading = true;
  String? error;
  final String _baseUrl = AppConfig.apiUrl;

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
      final cleanParams = Map<String, String>.fromEntries(
        widget.params.entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
      final uri = Uri.parse('$_baseUrl/drf_list_queried_shifts/')
          .replace(queryParameters: cleanParams);
      final auth =
          'Basic ${base64Encode(utf8.encode('${widget.username}:${widget.password}'))}';
      final headers = {
        'Content-Type': 'application/json',
        'authorization': auth,
      };
      final response = await http.get(uri, headers: headers);
      print('response__check');
      print(response.statusCode);
      print(response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          if (data is List) {
            shifts = data;
          } else if (data is Map) {
            shifts = (data['results'] ?? data['shifts'] ?? data['data'] ?? [])
                as List;
          }
        });
      } else {
        setState(() => error = 'Server error (${response.statusCode})');
      }
    } catch (_) {
      setState(() => error = 'Network error. Please retry.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Build a human-readable scope string for the AppBar title
  String get _scopeTitle {
    final parts = <String>[];
    if (widget.params['project'] != null) parts.add(widget.params['project']!);
    if (widget.params['zone'] != null) parts.add(widget.params['zone']!);
    if (widget.params['ward_code'] != null) {
      parts.add(widget.params['ward_code']!);
    }
    return parts.isEmpty ? 'Shifts' : parts.join(' › ');
  }

  String? get _vehicleType => widget.params['vehicle_type'];
  String? get _shiftStatus => widget.params['shift_status'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _scopeTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (_vehicleType != null)
              Text(
                _vehicleType!,
                style: TextStyle(
                  fontSize: 12,
                  color: _kVtColors[_vehicleType] ??
                      Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _buildError()
              : shifts.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
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
    return Center(
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
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _fetchShifts,
      child: CustomScrollView(
        slivers: [
          // Result count + filter summary banner
          SliverToBoxAdapter(
            child: _ResultBanner(
              count: shifts.length,
              shiftStatus: _shiftStatus,
              vehicleType: _vehicleType,
              date: widget.params['date'],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final shift = shifts[index] as Map;
                  return _ShiftCard(shift: shift);
                },
                childCount: shifts.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result count + filter banner ─────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  final int count;
  final String? shiftStatus;
  final String? vehicleType;
  final String? date;

  const _ResultBanner({
    required this.count,
    this.shiftStatus,
    this.vehicleType,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    final vtColor = vehicleType != null
        ? (_kVtColors[vehicleType] ?? Theme.of(context).colorScheme.primary)
        : Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withAlpha(15), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.list_alt_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$count ${count == 1 ? 'shift' : 'shifts'} found',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          if (vehicleType != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: vtColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: vtColor.withAlpha(90)),
              ),
              child: Text(
                vehicleType!,
                style: TextStyle(
                  fontSize: 11,
                  color: vtColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (vehicleType != null) const SizedBox(width: 6),
          if (shiftStatus != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: shiftStatus == 'Unclosed'
                    ? Colors.orange.withAlpha(25)
                    : Colors.green.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: shiftStatus == 'Unclosed'
                      ? Colors.orange.withAlpha(90)
                      : Colors.green.withAlpha(90),
                ),
              ),
              child: Text(
                shiftStatus!,
                style: TextStyle(
                  fontSize: 11,
                  color: shiftStatus == 'Unclosed'
                      ? Colors.orange
                      : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Individual shift card ─────────────────────────────────────────────────────

class _ShiftCard extends StatelessWidget {
  final Map shift;

  const _ShiftCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    final isActive = shift['end_time'] == null;
    final vtColor =
        _kVtColors[shift['vehicle_type']?.toString()] ?? Colors.grey;
    final shiftId = (shift['id'] as num?)?.toInt() ?? 0;

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
                        _Badge(
                          label: isActive ? 'Active' : 'Closed',
                          color: isActive ? Colors.green : Colors.grey,
                        ),
                        if (shift['vehicle_type'] != null) ...[
                          const SizedBox(height: 4),
                          _Badge(
                            label: shift['vehicle_type'].toString(),
                            color: vtColor,
                          ),
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
                        size: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(120)),
                    const SizedBox(width: 5),
                    Text(
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(150),
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
                if (shift['driverr'] != null)
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Driver',
                    value:
                        '${shift['driverr']}  ·  ${shift['driver_type'] ?? ''}',
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
        ],
      ),
    );

    if (!isActive) return card;

    return Slidable(
      key: ValueKey(shiftId),
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
            width: 76,
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
