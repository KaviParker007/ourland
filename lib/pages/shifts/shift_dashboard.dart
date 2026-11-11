import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';
import 'package:ourlandnew/services/dash_api.dart';
import 'queried_shifts_page.dart';
import 'add_shift.dart';
import 'shift_dash_models.dart';
import 'shift_dash_service.dart';

// ── Views ─────────────────────────────────────────────────────────────────────
//
// The dashboard has two views in a horizontal pager. Swipe left/right or tap the
// tab to switch; the status and date filters, the expanded project/zone and every
// loaded list live on this page's state, so nothing is lost or refetched by
// switching views.
//
//   By Location   project → zone → ward       (tap a count for the records)
//   By Creator    employee who started the shifts, scoped to the expanded zone

enum _DashView { location, creator }

extension on _DashView {
  String get label => this == _DashView.location ? 'By Location' : 'By Creator';
}

// ── Page ────────────────────────────────────────────────────────────────────

class ShiftDashboardPage extends StatefulWidget {
  const ShiftDashboardPage({super.key});

  @override
  State<ShiftDashboardPage> createState() => _ShiftDashboardPageState();
}

class _ShiftDashboardPageState extends State<ShiftDashboardPage> {
  final _api = ShiftDashboardApi.instance;
  final _pageController = PageController();

  _DashView _view = _DashView.location;
  ShiftDashQuery _query = ShiftDashQuery(
    status: ShiftStatus.open,
    date: DateTime.now(),
  );

  // Level 1 — projects
  List<ShiftDashRow> _projectList = [];
  bool _projectLoading = false;
  String? _projectError;

  // Level 2 — zones for the expanded project
  String? _expandedProject;
  List<ShiftDashRow> _zoneList = [];
  bool _zoneLoading = false;
  String? _zoneError;

  // Level 3 — wards for the expanded zone
  String? _expandedZone;
  List<ShiftDashRow> _wardList = [];
  bool _wardLoading = false;
  String? _wardError;

  // Creator view. Scoped to the expanded zone unless the user turns that off.
  List<ShiftDashRow> _creatorList = [];
  bool _creatorLoading = false;
  String? _creatorError;
  bool _creatorZoneScoped = true;

  /// Filters the creator list was loaded for, so switching back to the view
  /// does not refetch unless something changed.
  String? _creatorKey;

  String? get _creatorZone => _creatorZoneScoped ? _expandedZone : null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('menu', 'shift_dashboard');
    _fetchProjects();
  }

  static String _errorText(Object e) =>
      e is DashApiException ? e.message : 'Network error. Please retry.';

  Future<void> _fetchProjects() async {
    final query = _query;
    setState(() {
      _projectLoading = true;
      _projectError = null;
      _projectList = [];
      _expandedProject = null;
      _expandedZone = null;
    });
    try {
      final rows = await _api.byProject(query);
      if (!mounted || query != _query) return;
      setState(() => _projectList = rows);
    } catch (e) {
      if (!mounted || query != _query) return;
      setState(() => _projectError = _errorText(e));
    } finally {
      if (mounted && query == _query) setState(() => _projectLoading = false);
    }
  }

  Future<void> _fetchZones(String project) async {
    final query = _query;
    setState(() {
      _zoneLoading = true;
      _zoneError = null;
      _zoneList = [];
    });
    try {
      final rows = await _api.byZone(query, project: project);
      if (!mounted || query != _query || _expandedProject != project) return;
      setState(() => _zoneList = rows);
    } catch (e) {
      if (!mounted || query != _query || _expandedProject != project) return;
      setState(() => _zoneError = _errorText(e));
    } finally {
      if (mounted && query == _query && _expandedProject == project) {
        setState(() => _zoneLoading = false);
      }
    }
  }

  Future<void> _fetchWards(String zone) async {
    final query = _query;
    setState(() {
      _wardLoading = true;
      _wardError = null;
      _wardList = [];
    });
    try {
      final rows = await _api.byWard(query, zoneCode: zone);
      if (!mounted || query != _query || _expandedZone != zone) return;
      setState(() => _wardList = rows);
    } catch (e) {
      if (!mounted || query != _query || _expandedZone != zone) return;
      setState(() => _wardError = _errorText(e));
    } finally {
      if (mounted && query == _query && _expandedZone == zone) {
        setState(() => _wardLoading = false);
      }
    }
  }

  /// Loads the creator list unless it is already loaded for these filters.
  Future<void> _ensureCreators({bool force = false}) async {
    final query = _query;
    final zone = _creatorZone;
    final key = query.key(zone);
    if (!force && key == _creatorKey && _creatorError == null) return;

    setState(() {
      _creatorKey = key;
      _creatorLoading = true;
      _creatorError = null;
      _creatorList = [];
    });
    try {
      final rows = await _api.byCreator(query, zoneCode: zone);
      if (!mounted || _creatorKey != key) return;
      setState(() => _creatorList = rows);
    } catch (e) {
      if (!mounted || _creatorKey != key) return;
      setState(() => _creatorError = _errorText(e));
    } finally {
      if (mounted && _creatorKey == key) {
        setState(() => _creatorLoading = false);
      }
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

  void _goToQueried(ShiftListFilter filter) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QueriedShiftsPage(filter: filter)),
    );
  }

  /// Applies a status/date change: reloads the projects, and the creators too
  /// when that view is showing (otherwise they reload when next shown).
  void _applyQuery(ShiftDashQuery next) {
    if (next == _query) return;
    setState(() => _query = next);
    _fetchProjects();
    if (_view == _DashView.creator) _ensureCreators();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _query.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) _applyQuery(_query.copyWith(date: picked));
  }

  void _selectFilter(ShiftStatus status) =>
      _applyQuery(_query.copyWith(status: status));

  void _goToView(_DashView view) {
    if (_view == view) return;
    _pageController.animateToPage(
      view.index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    final view = _DashView.values[index];
    setState(() => _view = view);
    if (view == _DashView.creator) _ensureCreators();
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
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [_buildProjectBody(), _buildCreatorBody()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final primary = Theme.of(context).colorScheme.primary;
    final status = _query.status;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // View switcher (also reachable by swiping), full width so both
          // tabs stay visible on the narrowest phones.
          _segmented([
            for (final v in _DashView.values)
              Expanded(
                child: _StatusTab(
                  label: v.label,
                  isActive: _view == v,
                  onTap: () => _goToView(v),
                ),
              ),
          ], expand: true),
          const SizedBox(height: 10),
          // Status filter tabs — four equal segments; labels scale down
          // rather than overflow on narrow screens or large text sizes.
          _segmented([
            for (final s in ShiftStatus.values)
              Expanded(
                child: _StatusTab(
                  label: s.apiValue,
                  dotColor: s.color,
                  isActive: status == s,
                  onTap: () => _selectFilter(s),
                ),
              ),
          ], expand: true),
          const SizedBox(height: 8),
          // What the selected status means + the date it applies to.
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  status.description,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(150),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildDatePill(primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segmented(List<Widget> tabs, {bool expand = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withAlpha(40),
        border: Border.all(color: Colors.white.withAlpha(18), width: 1),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: tabs,
      ),
    );
  }

  Widget _buildDatePill(Color primary) {
    // Unclosed spans every date, so the picker is disabled for it.
    final usesDate = _query.status.usesDate;
    final color = usesDate
        ? primary
        : Theme.of(context).colorScheme.onSurface.withAlpha(140);
    return GestureDetector(
      onTap: usesDate ? _pickDate : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(140), width: 1.2),
          color: color.withAlpha(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              usesDate
                  ? DateFormat('dd MMM yyyy').format(_query.date)
                  : 'All dates',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── By Location: Level 1 body ────────────────────────────────────────────

  Widget _buildProjectBody() {
    if (_projectLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_projectError != null) {
      return _FullPageError(message: _projectError!, onRetry: _fetchProjects);
    }
    if (_projectList.isEmpty) {
      return _FullPageEmpty(
        message: 'No shift data available',
        onRefresh: _fetchProjects,
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchProjects,
      child: ListView.builder(
        // Keeps the scroll offset when swiping away and back.
        key: const PageStorageKey('shift-dash-location'),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 88),
        itemCount: _projectList.length,
        itemBuilder: (context, i) {
          final row = _projectList[i];
          final project = row.label;
          final isExp = _expandedProject == project;
          final filter = ShiftListFilter(query: _query, project: project);
          return _ProjectCard(
            label: project,
            count: row.total,
            row: row,
            isExpanded: isExp,
            onToggle: () => _toggleProject(project),
            onTotalTap: () => _goToQueried(filter),
            onChipTap: (vt) => _goToQueried(filter.withVehicleType(vt)),
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
        message: _zoneError!,
        onRetry: () => _fetchZones(project),
      );
    }
    if (_zoneList.isEmpty) return const _InlineEmpty();
    return Column(
      children: _zoneList.map((row) {
        final zone = row.label;
        final isExp = _expandedZone == zone;
        final filter = ShiftListFilter(
          query: _query,
          project: project,
          zoneCode: zone,
        );
        return _ZoneRow(
          label: zone,
          count: row.total,
          row: row,
          isExpanded: isExp,
          onToggle: () => _toggleZone(zone),
          onTotalTap: () => _goToQueried(filter),
          onChipTap: (vt) => _goToQueried(filter.withVehicleType(vt)),
          expandedChild: isExp ? _buildWardSection(project, zone) : null,
        );
      }).toList(),
    );
  }

  // ── Level 3 section ──────────────────────────────────────────────────────

  Widget _buildWardSection(String project, String zone) {
    if (_wardLoading) return const _InlineLoader();
    if (_wardError != null) {
      return _InlineError(
        message: _wardError!,
        onRetry: () => _fetchWards(zone),
      );
    }
    if (_wardList.isEmpty) return const _InlineEmpty();
    return Column(
      children: _wardList.map((row) {
        final ward = row.label;
        final filter = ShiftListFilter(
          query: _query,
          project: project,
          zoneCode: zone,
          wardCode: ward,
        );
        // Ward totals are distinct counts from the API — shown as returned.
        return _WardRow(
          label: ward,
          count: row.total,
          row: row,
          onTotalTap: () => _goToQueried(filter),
          onChipTap: (vt) => _goToQueried(filter.withVehicleType(vt)),
        );
      }).toList(),
    );
  }

  // ── By Creator ───────────────────────────────────────────────────────────

  Widget _buildCreatorBody() {
    return Column(
      children: [
        if (_expandedZone != null) _buildCreatorScope(),
        Expanded(child: _buildCreatorList()),
      ],
    );
  }

  /// Lets the user scope creators to the zone expanded in By Location.
  Widget _buildCreatorScope() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilterChip(
          label: Text('Zone $_expandedZone only'),
          selected: _creatorZoneScoped,
          onSelected: (on) {
            setState(() => _creatorZoneScoped = on);
            _ensureCreators();
          },
        ),
      ),
    );
  }

  Widget _buildCreatorList() {
    if (_creatorLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_creatorError != null) {
      return _FullPageError(
        message: _creatorError!,
        onRetry: () => _ensureCreators(force: true),
      );
    }
    if (_creatorList.isEmpty) {
      return _FullPageEmpty(
        message: 'No shifts started in this period',
        onRefresh: () => _ensureCreators(force: true),
      );
    }
    final zone = _creatorZone;
    return RefreshIndicator(
      onRefresh: () => _ensureCreators(force: true),
      child: ListView.builder(
        key: const PageStorageKey('shift-dash-creator'),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 88),
        itemCount: _creatorList.length,
        itemBuilder: (context, i) {
          final row = _creatorList[i];
          final filter = ShiftListFilter(
            query: _query,
            zoneCode: zone,
            // createdby is the employee id; the code is display only.
            createdBy: row.createdBy,
            creatorLabel: row.label,
          );
          return _CreatorCard(
            row: row,
            onTotalTap: row.createdBy == null
                ? null
                : () => _goToQueried(filter),
            onChipTap: row.createdBy == null
                ? null
                : (vt) => _goToQueried(filter.withVehicleType(vt)),
          );
        },
      ),
    );
  }
}

// ── Custom segmented toggle tab ──────────────────────────────────────────────

class _StatusTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  /// Optional status colour, shown as a dot before the label.
  final Color? dotColor;

  const _StatusTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.dotColor,
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
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
          // Fills its segment; scales the label down rather than overflow.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: isActive
                          ? Border.all(color: Colors.white, width: 1)
                          : null,
                    ),
                  ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isActive
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(160),
                  ),
                ),
              ],
            ),
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
  final ShiftDashRow row;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                border: Border(left: BorderSide(color: primary, width: 4)),
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
                      _CountBadge(
                        count: count,
                        color: primary,
                        onTap: onTotalTap,
                      ),
                      const SizedBox(width: 2),
                      // Animated expand chevron
                      Semantics(
                        label: isExpanded ? 'Collapse $label' : 'Expand $label',
                        button: true,
                        excludeSemantics: true,
                        child: IconButton(
                          onPressed: onToggle,
                          tooltip: isExpanded
                              ? 'Collapse $label'
                              : 'Expand $label',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: primary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Vehicle type chips
                  _VehicleChipRow(
                    row: row,
                    onChipTap: onChipTap,
                    compact: false,
                  ),
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
                      color: Colors.white.withAlpha(15),
                      width: 1,
                    ),
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

// ── Creator card ─────────────────────────────────────────────────────────────

class _CreatorCard extends StatelessWidget {
  final ShiftDashRow row;
  final VoidCallback? onTotalTap;
  final void Function(String)? onChipTap;

  const _CreatorCard({
    required this.row,
    required this.onTotalTap,
    required this.onChipTap,
  });

  static const _accent = Color(0xFF7E57C2);

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: InkWell(
        onTap: onTotalTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: _accent, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _accent.withAlpha(40),
                    child: const Icon(
                      Icons.person_outline,
                      size: 20,
                      color: _accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (row.employeeCode != null)
                          Text(
                            row.employeeCode!,
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurface.withAlpha(150),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CountBadge(
                    count: row.total,
                    color: _accent,
                    onTap: onTotalTap,
                  ),
                ],
              ),
              _VehicleChipRow(
                row: row,
                onChipTap: onChipTap ?? (_) {},
                compact: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _CountBadge({required this.count, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(28),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(110), width: 1.2),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ── Level 2 — Zone Row ───────────────────────────────────────────────────────

class _ZoneRow extends StatelessWidget {
  final String label;
  final int count;
  final ShiftDashRow row;
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
                        row: row,
                        onChipTap: onChipTap,
                        compact: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Count badge
                GestureDetector(
                  onTap: onTotalTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withAlpha(28),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _accent.withAlpha(100),
                        width: 1.1,
                      ),
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
                    tooltip: isExpanded ? 'Collapse $label' : 'Expand $label',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: _accent,
                      ),
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

// ── Level 3 — Ward Row (leaf, no chevron) ────────────────────────────────────

class _WardRow extends StatelessWidget {
  final String label;
  final int count;
  final ShiftDashRow row;
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
              style: TextStyle(fontSize: 12, color: onSurface.withAlpha(210)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          // Clickable count
          GestureDetector(
            onTap: onTotalTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
          ),
          const SizedBox(width: 8),
          // Vehicle chips — abbreviated for space
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: row.vehicleCounts.entries.map((e) {
                  final vt = e.key;
                  final color = vehicleTypeColor(vt);
                  final abbr = vt.length > 3 ? vt.substring(0, 3) : vt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: () => onChipTap(vt),
                      child: Tooltip(
                        message: vt,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withAlpha(22),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: color.withAlpha(80),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '$abbr ${e.value}',
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
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

// ── Shared vehicle chip row ──────────────────────────────────────────────────

class _VehicleChipRow extends StatelessWidget {
  final ShiftDashRow row;
  final void Function(String) onChipTap;
  final bool compact;

  const _VehicleChipRow({
    required this.row,
    required this.onChipTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    // Only the types present in this row — the API omits zero counts.
    final chips = row.vehicleCounts.entries.toList();
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: compact ? 5 : 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((e) {
            final vt = e.key;
            final color = vehicleTypeColor(vt);
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
                    border: Border.all(color: color.withAlpha(100), width: 1),
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
                        '$vt  ${e.value}',
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
          Icon(
            Icons.error_outline,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
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
          Icon(
            Icons.inbox_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
          ),
          const SizedBox(width: 8),
          Text(
            'No data',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
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
            Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
              ),
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

/// Empty state that still supports pull-to-refresh.
class _FullPageEmpty extends StatelessWidget {
  final String message;
  final Future<void> Function() onRefresh;

  const _FullPageEmpty({required this.message, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
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
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 56,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(70),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(120),
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
}
