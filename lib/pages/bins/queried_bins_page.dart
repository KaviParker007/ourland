// ─── Bins — Screen 4: Bin list (leaf) ──────────────────────────────────────────
//
// Reached from any of the three aggregate screens. The incoming BinQuery carries
// the accumulated scope (project → +zone_id → +ward_id) plus the three filters.

import 'package:flutter/material.dart';

import 'package:ourlandnew/components/bin_record_card.dart';
import 'package:ourlandnew/models/bin_record.dart';
import 'package:ourlandnew/services/dash_api.dart';

import 'bin_query.dart';
import 'bin_service.dart';
import 'bin_ui.dart';

class QueriedBinsPage extends StatefulWidget {
  /// The deepest location the user tapped — used as the app-bar title.
  final String title;
  final List<DashCrumb> crumbs;

  /// Full accumulated scope + selected bin type + carried filters.
  final BinQuery query;

  const QueriedBinsPage({
    super.key,
    required this.title,
    required this.crumbs,
    required this.query,
  });

  @override
  State<QueriedBinsPage> createState() => _QueriedBinsPageState();
}

class _QueriedBinsPageState extends State<QueriedBinsPage> {
  final _api = BinDashboardApi.instance;

  List<BinRecord> _bins = [];
  bool _loading = true;
  String? _error;

  /// Local scope. The leaf screen owns its filter state so changing a filter
  /// here does not disturb the aggregate screens the user can still go back to.
  late BinQuery _query = widget.query;

  BinFilters get _filters => _query.filters;

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
      final data = await _api.listQueriedBins(_query);
      if (!mounted) return;
      setState(() => _bins = data);
    } on DashApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not read the server response.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Filters ──────────────────────────────────────────────────────────────────

  /// Types offered in the sheet come from what this list actually returned, so
  /// nothing is hardcoded.
  List<String> get _availableTypes {
    final present = _bins.map((b) => b.binType).toSet()
      ..removeWhere((t) => t.trim().isEmpty || t == '—');
    return present.toList()..sort();
  }

  Future<void> _openFilters() async {
    final updated =
        await showBinFilterSheet(context, _filters, _availableTypes);
    if (updated == null || updated == _filters) return;
    setState(() => _query = _query.withFilters(updated));
    _fetch();
  }

  void _clearFilter(BinFilters cleared) {
    setState(() => _query = _query.withFilters(cleared));
    _fetch();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

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
            icon: Icon(_filters.hasActive
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          DashBreadcrumb(crumbs: widget.crumbs),
          BinFilterBar(
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
    if (_loading) return const DashLoading();
    if (_error != null) return DashError(message: _error!, onRetry: _fetch);
    if (_bins.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetch,
        child: const DashEmptyScrollable(
          message: 'No bins match these filters',
          hint: 'Try a different bin type or status, or go back a level.',
          icon: Icons.search_off_rounded,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: DashContentWidth(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              sliver: SliverToBoxAdapter(child: _provenanceHeader()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              sliver: SliverList.builder(
                itemCount: _bins.length,
                itemBuilder: (context, index) => BinRecordCard(
                  record: _bins[index],
                  // A bin only carries collection detail once it has been
                  // collected; showing an empty block for the rest is noise.
                  showCollectionDetail: _bins[index].isCollected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// States where the list came from — project / zone / ward and bin type — and
  /// how many bins came back.
  Widget _provenanceHeader() {
    final count = _bins.length;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Semantics(
      label: '$count ${count == 1 ? 'bin' : 'bins'} in ${_query.describeScope}',
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
                Icon(Icons.delete_outline_rounded, size: 18, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count ${count == 1 ? 'bin' : 'bins'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _query.describeScope,
              style: TextStyle(fontSize: 12, color: onSurface.withAlpha(150)),
            ),
          ],
        ),
      ),
    );
  }
}
