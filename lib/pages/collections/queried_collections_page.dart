// ─── Collections — Screen 4: Collection list (leaf) ────────────────────────────
//
// Reached from any of the three aggregate screens. Renders the full collection
// detail per record — bin number and type, zone, ward, vehicle, device,
// collected/left timestamps, collector, coordinates, and the before/after photos
// with a zoomable preview — via the shared BinRecordCard.

import 'package:flutter/material.dart';

import 'package:ourlandnew/components/bin_record_card.dart';
import 'package:ourlandnew/models/bin_record.dart';
import 'package:ourlandnew/services/dash_api.dart';

import 'collection_query.dart';
import 'collection_service.dart';
import 'collection_ui.dart';

class QueriedCollectionsPage extends StatefulWidget {
  /// The deepest location the user tapped — used as the app-bar title.
  final String title;
  final List<DashCrumb> crumbs;

  /// Full accumulated scope + selected bin type + the date range.
  final CollectionQuery query;

  const QueriedCollectionsPage({
    super.key,
    required this.title,
    required this.crumbs,
    required this.query,
  });

  @override
  State<QueriedCollectionsPage> createState() => _QueriedCollectionsPageState();
}

class _QueriedCollectionsPageState extends State<QueriedCollectionsPage> {
  final _api = CollectionDashboardApi.instance;

  List<BinRecord> _records = [];
  bool _loading = true;
  String? _error;

  /// Local scope. The leaf screen owns its own date/type state so changing them
  /// here does not disturb the aggregate screens behind it.
  late CollectionQuery _query = widget.query;

  CollectionDateRange get _range => _query.range;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final rangeError = _range.error;
    if (rangeError != null) {
      setState(() {
        _loading = false;
        _error = rangeError;
        _records = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.listQueriedCollections(_query);
      if (!mounted) return;
      setState(() => _records = data);
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

  void _onRangeChanged(CollectionDateRange next) {
    if (next == _range) return;
    setState(() => _query = _query.withRange(next));
    _fetch();
  }

  /// Types offered in the sheet come from what this list actually returned.
  List<String> get _availableTypes {
    final present = _records.map((r) => r.binType).toSet()
      ..removeWhere((t) => t.trim().isEmpty || t == '—');
    return present.toList()..sort();
  }

  Future<void> _openTypeFilter() async {
    final picked = await showCollectionTypeSheet(
      context,
      _query.binType,
      _availableTypes,
    );
    if (picked == null || picked == _query.binType) return;
    setState(() => _query = _query.withType(picked));
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
            onPressed: _openTypeFilter,
            icon: Icon(_query.hasType
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          DashBreadcrumb(crumbs: widget.crumbs),
          CollectionDateBar(
            range: _range,
            onChanged: _onRangeChanged,
            typeSummary: _query.hasType ? _query.binType : null,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const DashLoading();
    if (_error != null) return DashError(message: _error!, onRetry: _fetch);
    if (_records.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetch,
        child: const DashEmptyScrollable(
          message: 'No collections match these filters',
          hint: 'Try a wider date range or a different bin type.',
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
                itemCount: _records.length,
                itemBuilder: (context, index) =>
                    BinRecordCard(record: _records[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// States where the list came from — project / zone / ward, bin type and date
  /// range — and how many collections came back.
  Widget _provenanceHeader() {
    final count = _records.length;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Semantics(
      label: '$count ${count == 1 ? 'collection' : 'collections'} '
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
                Icon(Icons.recycling_rounded, size: 18, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count ${count == 1 ? 'collection' : 'collections'}',
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
