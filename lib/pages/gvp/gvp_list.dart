// ─── GVP Module — GVP List screen ─────────────────────────────────────────────
//
// Filterable list of active GVPs. Project / Zone / Ward filters map to the API
// query params (empty values are never sent); name search is applied client
// side. Each row exposes View, Edit and Manage Reference Images actions.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

import 'gvp_models.dart';
import 'gvp_service.dart';
import 'gvp_ui.dart';
import 'gvp_daily_confirmation.dart';
import 'gvp_form.dart';
import 'gvp_detail.dart';
import 'gvp_reference_images.dart';
import 'gvp_name_resolver.dart';

class GvpListPage extends StatefulWidget {
  const GvpListPage({super.key});

  @override
  State<GvpListPage> createState() => _GvpListPageState();
}

class _GvpListPageState extends State<GvpListPage> {
  final _service = GvpService.instance;
  final _resolver = GvpNameResolver.instance;
  final _searchController = TextEditingController();

  List<Gvp> _all = [];
  bool _loading = true;
  String? _error;

  // Filters
  String? _project;
  int? _zoneId;
  int? _wardId;
  String _nameQuery = '';

  // Filter option sources
  List<GvpZoneChoice> _zoneItems = [];
  List<GvpWardChoice> _wardItems = [];
  bool _wardLoading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('menu', 'gvp_list');
    await _loadZoneOptions();
    await _fetch();
  }

  Future<void> _loadZoneOptions() async {
    try {
      final opts = await _service.getGvpCreateOptions();
      _resolver.registerZoneChoices(opts.zonalChoices);
      if (!mounted) return;
      setState(() => _zoneItems = opts.zonalChoices);
    } on GvpApiException {
      // Non-fatal: the list still works without the zone filter populated.
    }
  }

  Future<void> _loadWards(int zoneId) async {
    final embedded = _zoneItems
        .firstWhere((z) => z.id == zoneId,
            orElse: () => const GvpZoneChoice(id: -1, code: ''))
        .wards;
    if (embedded.isNotEmpty) {
      setState(() => _wardItems = embedded);
      return;
    }
    setState(() {
      _wardLoading = true;
      _wardItems = [];
    });
    try {
      final counts = await _service.getGvpCountByWard(zoneId: zoneId);
      if (!mounted) return;
      setState(() => _wardItems = counts
          .map((c) => GvpWardChoice(id: c.wardId, code: c.wardCode))
          .toList());
    } on GvpApiException {
      // Ignore — ward filter simply stays empty.
    } finally {
      if (mounted) setState(() => _wardLoading = false);
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getGvpList(
        project: _project,
        zone: _zoneId?.toString(),
        ward: _wardId?.toString(),
      );
      if (!mounted) return;
      setState(() => _all = data);
      // Resolve zone/ward names for the zones present in this result set.
      await _resolver.ensureZones();
      await _resolver.ensureWardsForZones(
        data.map((g) => g.zone).whereType<int>(),
      );
      if (mounted) setState(() {});
    } on GvpApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Gvp> get _visible {
    final q = _nameQuery.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((g) => g.name.toLowerCase().contains(q)).toList();
  }

  bool get _hasActiveFilters =>
      _project != null ||
      _zoneId != null ||
      _wardId != null ||
      _nameQuery.trim().isNotEmpty;

  void _resetFilters() {
    setState(() {
      _project = null;
      _zoneId = null;
      _wardId = null;
      _nameQuery = '';
      _searchController.clear();
      _wardItems = [];
    });
    _fetch();
  }

  // ── Row actions ─────────────────────────────────────────────────────────────

  void _view(Gvp gvp) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GvpDetailPage(gvpId: gvp.id)),
    ).then((_) => _fetch());
  }

  Future<void> _edit(Gvp gvp) async {
    // The form only needs the scalar fields; build a detail without images.
    final detail = GvpDetail(
      id: gvp.id,
      name: gvp.name,
      project: gvp.project,
      zone: gvp.zone,
      ward: gvp.ward,
      latitude: gvp.latitude,
      longitude: gvp.longitude,
    );
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GvpFormPage(existing: detail)),
    );
    if (updated == true) _fetch();
  }

  Future<void> _manageImages(Gvp gvp) async {
    // Fetch the current image count so the cap can be enforced accurately.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final detail = await _service.getGvpDetails(gvp.id);
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => GvpReferenceImagesPage(
            gvpId: detail.id,
            existingCount: detail.referenceImages.length,
          ),
        ),
      );
      if (changed == true) _fetch();
    } on GvpApiException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      gvpErrorSnack(context, e.message);
    }
  }

  Future<void> _add() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GvpFormPage()),
    );
    if (created == true) _fetch();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GVP List',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.refresh),
          ),
          const NotificationBellWidget(),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New GVP',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _nameQuery = v),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search GVP name',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _nameQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() {
                        _nameQuery = '';
                        _searchController.clear();
                      }),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          // Filter dropdowns
          Row(
            children: [
              Expanded(
                child: _FilterDropdown<String>(
                  label: 'Project',
                  value: _project,
                  items: [
                    const DropdownMenuItem<String>(
                        value: null, child: Text('All projects')),
                    ...kGvpProjects.map((p) =>
                        DropdownMenuItem<String>(value: p, child: Text(p))),
                  ],
                  onChanged: (v) {
                    setState(() => _project = v);
                    _fetch();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown<int>(
                  label: 'Zone',
                  value: _zoneId,
                  items: [
                    const DropdownMenuItem<int>(
                        value: null, child: Text('All zones')),
                    ..._zoneItems.map((z) =>
                        DropdownMenuItem<int>(value: z.id, child: Text(z.code))),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _zoneId = v;
                      _wardId = null;
                      _wardItems = [];
                    });
                    if (v != null) _loadWards(v);
                    _fetch();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _wardLoading
                    ? const _FilterLoading(label: 'Ward')
                    : _FilterDropdown<int>(
                        label: 'Ward',
                        value: _wardId,
                        enabled: _zoneId != null && _wardItems.isNotEmpty,
                        items: [
                          const DropdownMenuItem<int>(
                              value: null, child: Text('All wards')),
                          ..._wardItems.map((w) => DropdownMenuItem<int>(
                              value: w.id, child: Text(w.code))),
                        ],
                        onChanged: (v) {
                          setState(() => _wardId = v);
                          _fetch();
                        },
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _hasActiveFilters ? _resetFilters : null,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const GvpLoading();
    if (_error != null) return GvpFullError(message: _error!, onRetry: _fetch);

    final visible = _visible;
    if (visible.isEmpty) {
      return GvpEmpty(
        message: _hasActiveFilters ? 'No matching GVPs' : 'No GVPs yet',
        hint: _hasActiveFilters
            ? 'Try adjusting or resetting your filters.'
            : 'Tap "New GVP" to create the first one.',
        icon: _hasActiveFilters
            ? Icons.search_off_rounded
            : Icons.inbox_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: visible.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 2),
                  child: Row(
                    children: [
                      Icon(Icons.list_alt_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${visible.length} ${visible.length == 1 ? 'GVP' : 'GVPs'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }
              final gvp = visible[index - 1];
              return GvpDailyCard(
                gvp: gvp,
                zoneName: _resolver.zoneName(gvp.zone),
                wardName: _resolver.wardName(gvp.ward),
                onChanged: _fetch,
                onView: () => _view(gvp),
                onEdit: () => _edit(gvp),
                onImages: () => _manageImages(gvp),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Filter widgets ────────────────────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      isDense: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items,
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _FilterLoading extends StatelessWidget {
  final String label;

  const _FilterLoading({required this.label});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const SizedBox(
        height: 20,
        child: Row(
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Loading…', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
