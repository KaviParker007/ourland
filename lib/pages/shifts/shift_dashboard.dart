import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/config.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';
import 'queried_shifts_page.dart';
import 'add_shift.dart';

const _kVehicleTypes = ['Tipper', 'Tractor', 'LCV', 'EMV', 'Compactor'];

const _kVehicleColors = <String, Color>{
  'Tipper':    Color(0xFFFF7043),
  'Tractor':   Color(0xFF42A5F5),
  'LCV':       Color(0xFF66BB6A),
  'EMV':       Color(0xFFAB47BC),
  'Compactor': Color(0xFF26C6DA),
};

// ── Page ────────────────────────────────────────────────────────────────────

class ShiftDashboardPage extends StatefulWidget {
  const ShiftDashboardPage({super.key});

  @override
  State<ShiftDashboardPage> createState() => _ShiftDashboardPageState();
}

class _ShiftDashboardPageState extends State<ShiftDashboardPage> {
  String? username;
  String? password;
  final String _baseUrl = AppConfig.apiUrl;

  DateTime _selectedDate = DateTime.now();
  String _shiftStatus = 'Normal';

  // Level 1 — projects
  List<Map<String, dynamic>> _projectList = [];
  bool _projectLoading = false;
  String? _projectError;

  // Level 2 — zones for the expanded project
  String? _expandedProject;
  List<Map<String, dynamic>> _zoneList = [];
  bool _zoneLoading = false;
  String? _zoneError;

  // Level 3 — wards for the expanded zone
  String? _expandedZone;
  List<Map<String, dynamic>> _wardList = [];
  bool _wardLoading = false;
  String? _wardError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('menu', 'shift_dashboard');
    username = prefs.getString('username');
    password = prefs.getString('password');
    _fetchProjects();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Map<String, String> get _authHeaders {
    final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    return {'Content-Type': 'application/json', 'authorization': auth};
  }

  Map<String, String> _baseParams() {
    final p = <String, String>{'shift_status': _shiftStatus};
    if (_shiftStatus == 'Normal') p['date'] = _dateStr;
    return p;
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _projectLoading = true;
      _projectError = null;
      _projectList = [];
      _expandedProject = null;
      _expandedZone = null;
    });
    try {
      final uri = Uri.parse('$_baseUrl/drf_shift_dash_by_project/')
          .replace(queryParameters: _baseParams());
      final resp = await http.get(uri, headers: _authHeaders);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map;
        final list = data[_shiftStatus] as List? ?? [];
        setState(() {
          _projectList =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      } else {
        setState(() => _projectError = 'Server error (${resp.statusCode})');
      }
    } catch (_) {
      setState(() => _projectError = 'Network error. Please retry.');
    } finally {
      setState(() => _projectLoading = false);
    }
  }

  Future<void> _fetchZones(String project) async {
    setState(() {
      _zoneLoading = true;
      _zoneError = null;
      _zoneList = [];
    });
    try {
      final params = _baseParams()..['project'] = project;
      final uri = Uri.parse('$_baseUrl/drf_shift_dash_by_zone/')
          .replace(queryParameters: params);
      final resp = await http.get(uri, headers: _authHeaders);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map;
        final list = data[_shiftStatus] as List? ?? [];
        setState(() {
          _zoneList =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      } else {
        setState(() => _zoneError = 'Server error (${resp.statusCode})');
      }
    } catch (_) {
      setState(() => _zoneError = 'Network error. Please retry.');
    } finally {
      setState(() => _zoneLoading = false);
    }
  }

  Future<void> _fetchWards(String zone) async {
    setState(() {
      _wardLoading = true;
      _wardError = null;
      _wardList = [];
    });
    try {
      final params = _baseParams()..['zone_code'] = zone;
      final uri = Uri.parse('$_baseUrl/drf_shift_dash_by_ward/')
          .replace(queryParameters: params);
      final resp = await http.get(uri, headers: _authHeaders);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map;
        final list = data[_shiftStatus] as List? ?? [];
        setState(() {
          _wardList =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      } else {
        setState(() => _wardError = 'Server error (${resp.statusCode})');
      }
    } catch (_) {
      setState(() => _wardError = 'Network error. Please retry.');
    } finally {
      setState(() => _wardLoading = false);
    }
  }

  void _toggleProject(String project) {
    if (_expandedProject == project) {
      setState(() {
        _expandedProject = null;
        _expandedZone = null;
      });
    } else {
      setState(() {
        _expandedProject = project;
        _expandedZone = null;
        _zoneList = [];
      });
      _fetchZones(project);
    }
  }

  void _toggleZone(String zone) {
    if (_expandedZone == zone) {
      setState(() {
        _expandedZone = null;
        _wardList = [];
      });
    } else {
      setState(() {
        _expandedZone = zone;
        _wardList = [];
      });
      _fetchWards(zone);
    }
  }

  void _goToQueried(Map<String, String?> extra) {
    final params = <String, String?>{
      'shift_status': _shiftStatus,
      if (_shiftStatus == 'Normal') 'date': _dateStr,
      ...extra,
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QueriedShiftsPage(
          params: params,
          username: username!,
          password: password!,
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _expandedProject = null;
        _expandedZone = null;
      });
      _fetchProjects();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shift Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [NotificationBellWidget()],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddShiftPage()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Shift',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          _buildControls(),
          Expanded(child: _buildProjectBody()),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final isNormal = _shiftStatus == 'Normal';
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Custom segmented toggle
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black.withAlpha(40),
              border: Border.all(
                color: Colors.white.withAlpha(18),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusTab(
                  label: 'Normal',
                  isActive: isNormal,
                  onTap: () {
                    if (isNormal) return;
                    setState(() {
                      _shiftStatus = 'Normal';
                      _expandedProject = null;
                      _expandedZone = null;
                    });
                    _fetchProjects();
                  },
                ),
                _StatusTab(
                  label: 'Unclosed',
                  isActive: !isNormal,
                  onTap: () {
                    if (!isNormal) return;
                    setState(() {
                      _shiftStatus = 'Unclosed';
                      _expandedProject = null;
                      _expandedZone = null;
                    });
                    _fetchProjects();
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
          // Date pill button (Normal mode only)
          if (isNormal)
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: primary.withAlpha(140), width: 1.2),
                  color: primary.withAlpha(22),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 14, color: primary),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Level 1 body ─────────────────────────────────────────────────────────

  Widget _buildProjectBody() {
    if (_projectLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_projectError != null) {
      return _FullPageError(
          message: _projectError!, onRetry: _fetchProjects);
    }
    if (_projectList.isEmpty) {
      return const _FullPageEmpty(message: 'No shift data available');
    }
    return RefreshIndicator(
      onRefresh: _fetchProjects,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
        itemCount: _projectList.length,
        itemBuilder: (context, i) {
          final row = _projectList[i];
          final project = row['project']?.toString() ?? '';
          if (project.isEmpty) return const SizedBox.shrink();
          final isExp = _expandedProject == project;
          return _ProjectCard(
            label: project,
            count: (row['total'] as num?)?.toInt() ?? 0,
            row: row,
            isExpanded: isExp,
            onToggle: () => _toggleProject(project),
            onTotalTap: () => _goToQueried({'project': project}),
            onChipTap: (vt) =>
                _goToQueried({'project': project, 'vehicle_type': vt}),
            expandedChild: isExp ? _buildZoneSection(project) : null,
          );
        },
      ),
    );
  }

  // ── Level 2 section ──────────────────────────────────────────────────────

  Widget _buildZoneSection(String project) {
    if (_zoneLoading) return const _InlineLoader();
    if (_zoneError != null) {
      return _InlineError(
          message: _zoneError!, onRetry: () => _fetchZones(project));
    }
    if (_zoneList.isEmpty) return const _InlineEmpty();
    return Column(
      children: _zoneList.map((row) {
        final zone = row['zone']?.toString() ?? '';
        if (zone.isEmpty) return const SizedBox.shrink();
        final isExp = _expandedZone == zone;
        return _ZoneRow(
          label: zone,
          count: (row['total'] as num?)?.toInt() ?? 0,
          row: row,
          isExpanded: isExp,
          onToggle: () => _toggleZone(zone),
          onTotalTap: () => _goToQueried({'zone': zone}),
          onChipTap: (vt) =>
              _goToQueried({'zone': zone, 'vehicle_type': vt}),
          expandedChild: isExp ? _buildWardSection(zone) : null,
        );
      }).toList(),
    );
  }

  // ── Level 3 section ──────────────────────────────────────────────────────

  Widget _buildWardSection(String zone) {
    if (_wardLoading) return const _InlineLoader();
    if (_wardError != null) {
      return _InlineError(
          message: _wardError!, onRetry: () => _fetchWards(zone));
    }
    if (_wardList.isEmpty) return const _InlineEmpty();
    return Column(
      children: _wardList.map((row) {
        final ward = row['ward']?.toString() ?? '';
        if (ward.isEmpty) return const SizedBox.shrink();
        return _WardRow(
          label: ward,
          count: (row['total'] as num?)?.toInt() ?? 0,
          row: row,
          onTotalTap: () => _goToQueried({'ward_code': ward}),
          onChipTap: (vt) =>
              _goToQueried({'ward_code': ward, 'vehicle_type': vt}),
        );
      }).toList(),
    );
  }
}

// ── Custom segmented toggle tab ──────────────────────────────────────────────

class _StatusTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _StatusTab({
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isActive ? primary : Colors.transparent,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: primary.withAlpha(80),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
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
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha(160),
          ),
        ),
      ),
    );
  }
}

// ── Level 1 — Project Card ───────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  final String label;
  final int count;
  final Map<String, dynamic> row;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onTotalTap;
  final void Function(String) onChipTap;
  final Widget? expandedChild;

  const _ProjectCard({
    required this.label,
    required this.count,
    required this.row,
    required this.isExpanded,
    required this.onToggle,
    required this.onTotalTap,
    required this.onChipTap,
    this.expandedChild,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project header row
          InkWell(
            onTap: onToggle,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: primary, width: 4),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      // Clickable total count badge
                      GestureDetector(
                        onTap: onTotalTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: primary.withAlpha(28),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: primary.withAlpha(110), width: 1.2),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      // Animated expand chevron
                      Semantics(
                        label: isExpanded
                            ? 'Collapse $label'
                            : 'Expand $label',
                        button: true,
                        excludeSemantics: true,
                        child: IconButton(
                          onPressed: onToggle,
                          tooltip: isExpanded
                              ? 'Collapse $label'
                              : 'Expand $label',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                          icon: AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            child: Icon(Icons.keyboard_arrow_down,
                                color: primary, size: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Vehicle type chips
                  _VehicleChipRow(
                      row: row, onChipTap: onChipTap, compact: false),
                ],
              ),
            ),
          ),
          // Animated expanded zone section
          if (isExpanded && expandedChild != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(28),
                  border: Border(
                    top: BorderSide(
                        color: Colors.white.withAlpha(15), width: 1),
                  ),
                ),
                child: expandedChild,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Level 2 — Zone Row ───────────────────────────────────────────────────────

class _ZoneRow extends StatelessWidget {
  final String label;
  final int count;
  final Map<String, dynamic> row;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onTotalTap;
  final void Function(String) onChipTap;
  final Widget? expandedChild;

  const _ZoneRow({
    required this.label,
    required this.count,
    required this.row,
    required this.isExpanded,
    required this.onToggle,
    required this.onTotalTap,
    required this.onChipTap,
    this.expandedChild,
  });

  static const _accent = Color(0xFF26C6DA); // cyan

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Zone indicator dot
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: const BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      _VehicleChipRow(
                          row: row, onChipTap: onChipTap, compact: true),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Count badge
                GestureDetector(
                  onTap: onTotalTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accent.withAlpha(28),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _accent.withAlpha(100), width: 1.1),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                // Expand chevron
                Semantics(
                  label: isExpanded ? 'Collapse $label' : 'Expand $label',
                  button: true,
                  excludeSemantics: true,
                  child: IconButton(
                    onPressed: onToggle,
                    tooltip:
                        isExpanded ? 'Collapse $label' : 'Expand $label',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    icon: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(Icons.keyboard_arrow_down,
                          size: 20, color: _accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Ward expanded section (with left border guide)
        if (isExpanded && expandedChild != null)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Container(
              margin: const EdgeInsets.only(left: 32),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                      color: _accent.withAlpha(70), width: 1.5),
                ),
              ),
              child: expandedChild,
            ),
          ),
        Divider(
          height: 1,
          indent: 32,
          color: Colors.white.withAlpha(15),
        ),
      ],
    );
  }
}

// ── Level 3 — Ward Row (leaf, no chevron) ────────────────────────────────────

class _WardRow extends StatelessWidget {
  final String label;
  final int count;
  final Map<String, dynamic> row;
  final VoidCallback onTotalTap;
  final void Function(String) onChipTap;

  const _WardRow({
    required this.label,
    required this.count,
    required this.row,
    required this.onTotalTap,
    required this.onChipTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Tiny dot
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: onSurface.withAlpha(90),
              shape: BoxShape.circle,
            ),
          ),
          // Ward name
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: onSurface.withAlpha(210),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          // Clickable count
          GestureDetector(
            onTap: onTotalTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: primary.withAlpha(22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: primary.withAlpha(70), width: 0.8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Vehicle chips — abbreviated for space
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _kVehicleTypes
                    .where((vt) =>
                        row[vt] is num && (row[vt] as num) > 0)
                    .map((vt) {
                  final color =
                      _kVehicleColors[vt] ?? Colors.grey;
                  final abbr = vt.length > 3
                      ? vt.substring(0, 3)
                      : vt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: () => onChipTap(vt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(22),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: color.withAlpha(80),
                              width: 0.8),
                        ),
                        child: Text(
                          '$abbr ${(row[vt] as num).toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared vehicle chip row (L1 and L2) ──────────────────────────────────────

class _VehicleChipRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final void Function(String) onChipTap;
  final bool compact;

  const _VehicleChipRow({
    required this.row,
    required this.onChipTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final chips = _kVehicleTypes
        .where((vt) => row[vt] is num && (row[vt] as num) > 0)
        .toList();
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: compact ? 5 : 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((vt) {
            final color = _kVehicleColors[vt] ?? Colors.grey;
            final cnt = (row[vt] as num).toInt();
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onChipTap(vt),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 9 : 11,
                    vertical: compact ? 3 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(22),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: color.withAlpha(100), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: compact ? 6 : 7,
                        height: compact ? 6 : 7,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        '$vt  $cnt',
                        style: TextStyle(
                          fontSize: compact ? 11 : 12,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Inline state widgets ─────────────────────────────────────────────────────

class _InlineLoader extends StatelessWidget {
  const _InlineLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 16, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error)),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined,
              size: 16,
              color:
                  Theme.of(context).colorScheme.onSurface.withAlpha(100)),
          const SizedBox(width: 8),
          Text(
            'No data',
            style: TextStyle(
              fontSize: 12,
              color:
                  Theme.of(context).colorScheme.onSurface.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full-page state widgets ──────────────────────────────────────────────────

class _FullPageError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FullPageError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha(160)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullPageEmpty extends StatelessWidget {
  final String message;

  const _FullPageEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 56,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha(70),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
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
}
