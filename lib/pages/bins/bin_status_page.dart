// ─── Bins — Step 3: Bin statuses ───────────────────────────────────────────────
//
//   Bins → MDU → Compactor → [Collected in 12hr | …] → Bin list
//
// Like the type screen, this makes no request: the counts are the nested buckets
// the dashboard endpoint already returned, handed over by the calling screen.
//
// Tapping a status opens the bin list with the canonical `bin_status` value —
// e.g. `?project=MDU&bin_type=Compactor&bin_status=Collected%20in%2012hr`.

import 'package:flutter/material.dart';

import 'bin_query.dart';
import 'bin_status.dart';
import 'bin_ui.dart';
import 'queried_bins_page.dart';

class BinStatusPage extends StatelessWidget {
  /// The location these statuses belong to (project / zone / ward code).
  final String title;

  /// Scope accumulated so far, already narrowed to the chosen bin type.
  final BinQuery query;

  /// Canonical status → count, taken from the dashboard response.
  final Map<String, int> counts;

  final List<DashCrumb> crumbs;

  const BinStatusPage({
    super.key,
    required this.title,
    required this.query,
    required this.counts,
    required this.crumbs,
  });

  /// The five documented statuses, plus any unrecognised bucket the API sent so
  /// nothing is hidden. A status with no bins still shows, as an inert zero.
  List<String> get _statuses =>
      orderBinStatuses({...kBinStatuses, ...counts.keys});

  void _openBins(BuildContext context, String status) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kBinListRoute),
        builder: (_) => QueriedBinsPage(
          title: title,
          // The status goes on the wire verbatim — see kBinStatuses.
          query: query.withStatus(status),
          crumbs: [
            ...crumbs.map((c) => c.routeName == null
                ? DashCrumb(c.label, routeName: kBinStatusRoute)
                : c),
            DashCrumb(binStatusShortLabel(status)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _statuses;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          DashBreadcrumb(crumbs: crumbs),
          Expanded(
            child: DashContentWidth(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
                    sliver: SliverList.builder(
                      itemCount: statuses.length,
                      itemBuilder: (context, index) {
                        final status = statuses[index];
                        return buildBinStatusCard(
                          status: status,
                          count: counts[status] ?? 0,
                          onTap: () => _openBins(context, status),
                        );
                      },
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
}
