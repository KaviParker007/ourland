// ─── GVP Module — Dashboard (Project → Zone → Ward drill-down) ─────────────────
//
// Visual + interaction language intentionally mirrors the Shift Dashboard:
// level-1 project cards expand into level-2 zone rows, which expand into
// level-3 ward rows. Tapping any count badge opens the queried GVP list for
// that scope, carrying breadcrumb context.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

import 'gvp_models.dart';
import 'gvp_service.dart';
import 'gvp_ui.dart';
import 'gvp_form.dart';
import 'queried_gvp_list.dart';
import 'gvp_name_resolver.dart';

class GvpDashboardPage extends StatefulWidget {
  const GvpDashboardPage({super.key});

  @override
  State<GvpDashboardPage> createState() => _GvpDashboardPageState();
}

class _GvpDashboardPageState extends State<GvpDashboardPage> {
  final _service = GvpService.instance;
  final _resolver = GvpNameResolver.instance;

  // Level 1 — projects
  List<GvpProjectCount> _projects = [];
  bool _projectLoading = false;
  String? _projectError;

  // Level 2 — zones for the expanded project
  String? _expandedProject;
  List<GvpZoneCount> _zones = [];
  bool _zoneLoading = false;
  String? _zoneError;

  // Level 3 — wards for the expanded zone
  int? _expandedZoneId;
  List<GvpWardCount> _wards = [];
  bool _wardLoading = false;
  String? _wardError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('menu', 'gvp_dashboard');
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _projectLoading = true;
      _projectError = null;
      _expandedProject = null;
      _expandedZoneId = null;
    });
    try {
      final data = await _service.getGvpCountByProject();
      if (!mounted) return;
      setState(() => _projects = data);
    } on GvpApiException catch (e) {
      if (mounted) setState(() => _projectError = e.message);
    } finally {
      if (mounted) setState(() => _projectLoading = false);
    }
  }

  Future<void> _fetchZones(String project) async {
    setState(() {
      _zoneLoading = true;
      _zoneError = null;
      _zones = [];
    });
    try {
      final data = await _service.getGvpCountByZone(project: project);
      if (!mounted) return;
      for (final z in data) {
        _resolver.registerZone(z.zoneId, z.zoneCode);
      }
      setState(() => _zones = data);
    } on GvpApiException catch (e) {
      if (mounted) setState(() => _zoneError = e.message);
    } finally {
      if (mounted) setState(() => _zoneLoading = false);
    }
  }

  Future<void> _fetchWards(int zoneId) async {
    setState(() {
      _wardLoading = true;
      _wardError = null;
      _wards = [];
    });
    try {
      final data = await _service.getGvpCountByWard(zoneId: zoneId);
      if (!mounted) return;
      for (final w in data) {
        _resolver.registerWard(w.wardId, w.wardCode);
      }
      setState(() => _wards = data);
    } on GvpApiException catch (e) {
      if (mounted) setState(() => _wardError = e.message);
    } finally {
      if (mounted) setState(() => _wardLoading = false);
    }
  }

  void _toggleProject(String project) {
    if (_expandedProject == project) {
      setState(() {
        _expandedProject = null;
        _expandedZoneId = null;
      });
    } else {
      setState(() {
        _expandedProject = project;
        _expandedZoneId = null;
        _zones = [];
      });
      _fetchZones(project);
    }
  }

  void _toggleZone(int zoneId) {
    if (_expandedZoneId == zoneId) {
      setState(() {
        _expandedZoneId = null;
        _wards = [];
      });
    } else {
      setState(() {
        _expandedZoneId = zoneId;
        _wards = [];
      });
      _fetchWards(zoneId);
    }
  }

  void _openQueried(GvpDrillContext ctx) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QueriedGvpListPage(context: ctx)),
    );
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GvpFormPage()),
    );
    if (created == true) _fetchProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GVP Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [NotificationBellWidget()],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New GVP',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_projectLoading) return const GvpLoading();
    if (_projectError != null) {
      return GvpFullError(message: _projectError!, onRetry: _fetchProjects);
    }
    if (_projects.isEmpty) {
      return const GvpEmpty(
        message: 'No GVP data available',
        hint: 'Create a GVP to get started.',
        icon: Icons.bar_chart_rounded,
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchProjects,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 96),
        itemCount: _projects.length,
        itemBuilder: (context, i) {
          final row = _projects[i];
          final isExp = _expandedProject == row.project;
          return _ProjectCard(
            label: row.project,
            count: row.count,
            isExpanded: isExp,
            onToggle: () => _toggleProject(row.project),
            onTotalTap: () => _openQueried(
              GvpDrillContext(project: row.project),
            ),
            expandedChild: isExp ? _buildZoneSection(row.project) : null,
          );
        },
      ),
    );
  }

  Widget _buildZoneSection(String project) {
    if (_zoneLoading) return const GvpInlineLoader();
    if (_zoneError != null) {
      return GvpInlineError(
          message: _zoneError!, onRetry: () => _fetchZones(project));
    }
    if (_zones.isEmpty) return const GvpInlineEmpty();
    return Column(
      children: _zones.map((row) {
        final isExp = _expandedZoneId == row.zoneId;
        return _ZoneRow(
          label: row.zoneCode,
          count: row.count,
          isExpanded: isExp,
          onToggle: () => _toggleZone(row.zoneId),
          onTotalTap: () => _openQueried(
            GvpDrillContext(
              project: project,
              zoneId: row.zoneId,
              zoneCode: row.zoneCode,
            ),
          ),
          expandedChild:
              isExp ? _buildWardSection(project, row.zoneCode) : null,
        );
      }).toList(),
    );
  }

  Widget _buildWardSection(String project, String zoneCode) {
    if (_wardLoading) return const GvpInlineLoader();
    if (_wardError != null) {
      return GvpInlineError(
          message: _wardError!,
          onRetry: () => _fetchWards(_expandedZoneId!));
    }
    if (_wards.isEmpty) return const GvpInlineEmpty();
    return Column(
      children: _wards.map((row) {
        return _WardRow(
          label: row.wardCode,
          count: row.count,
          onTotalTap: () => _openQueried(
            GvpDrillContext(
              project: project,
              zoneId: _expandedZoneId,
              zoneCode: zoneCode,
              wardId: row.wardId,
              wardCode: row.wardCode,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Level 1 — Project Card ────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  final String label;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onTotalTap;
  final Widget? expandedChild;

  const _ProjectCard({
    required this.label,
    required this.count,
    required this.isExpanded,
    required this.onToggle,
    required this.onTotalTap,
    this.expandedChild,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: primary, width: 4)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_sweep_outlined,
                        size: 18, color: primary),
                  ),
                  const SizedBox(width: 12),
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
                  GvpCountBadge(
                      count: count, color: primary, onTap: onTotalTap),
                  const SizedBox(width: 2),
                  Semantics(
                    label: isExpanded ? 'Collapse $label' : 'Expand $label',
                    button: true,
                    excludeSemantics: true,
                    child: IconButton(
                      onPressed: onToggle,
                      tooltip:
                          isExpanded ? 'Collapse $label' : 'Expand $label',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
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
            ),
          ),
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

// ── Level 2 — Zone Row ────────────────────────────────────────────────────────

class _ZoneRow extends StatelessWidget {
  final String label;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onTotalTap;
  final Widget? expandedChild;

  const _ZoneRow({
    required this.label,
    required this.count,
    required this.isExpanded,
    required this.onToggle,
    required this.onTotalTap,
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
              children: [
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
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                Semantics(
                  label: isExpanded ? 'Collapse $label' : 'Expand $label',
                  button: true,
                  excludeSemantics: true,
                  child: IconButton(
                    onPressed: onToggle,
                    tooltip: isExpanded ? 'Collapse $label' : 'Expand $label',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
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
        if (isExpanded && expandedChild != null)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Container(
              margin: const EdgeInsets.only(left: 32),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: _accent.withAlpha(70), width: 1.5),
                ),
              ),
              child: expandedChild,
            ),
          ),
        Divider(height: 1, indent: 32, color: Colors.white.withAlpha(15)),
      ],
    );
  }
}

// ── Level 3 — Ward Row (leaf) ─────────────────────────────────────────────────

class _WardRow extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onTotalTap;

  const _WardRow({
    required this.label,
    required this.count,
    required this.onTotalTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTotalTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: onSurface.withAlpha(90),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
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
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: primary.withAlpha(22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primary.withAlpha(70), width: 0.8),
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
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: onSurface.withAlpha(90)),
          ],
        ),
      ),
    );
  }
}
