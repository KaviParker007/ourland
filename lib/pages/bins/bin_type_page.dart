// ─── Bins — Step 2: Bin types ──────────────────────────────────────────────────
//
//   Bins → MDU → [Compactor | Dumper] → Bin status → Bin list
//
// No request is made here. The dashboard endpoint already returns each type's
// counts nested under the group (`{"Compactor": {"12hr": 789}}`), so the calling
// screen hands the row over. That keeps the step instant and guarantees these
// figures match the dashboard exactly.

import 'package:flutter/material.dart';

import 'bin_models.dart';
import 'bin_query.dart';
import 'bin_status_page.dart';
import 'bin_ui.dart';

class BinTypePage extends StatelessWidget {
  /// The location these types belong to (project / zone / ward code).
  final String title;

  /// Scope accumulated so far.
  final BinQuery query;

  /// The group row the caller already fetched, holding every type's counts.
  final BinGroupRow row;

  final List<DashCrumb> crumbs;

  const BinTypePage({
    super.key,
    required this.title,
    required this.query,
    required this.row,
    required this.crumbs,
  });

  /// Types the API actually returned for this group, in canonical order then
  /// any extras — never a hardcoded list.
  List<String> get _types => unionBinTypes([row], kBinTypes);

  void _openStatuses(BuildContext context, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kBinStatusRoute),
        builder: (_) => BinStatusPage(
          title: title,
          query: query.withType(type),
          counts: row.statusCountsFor(type),
          crumbs: [
            ...crumbs.map((c) => c.routeName == null
                ? DashCrumb(c.label, routeName: kBinTypeRoute)
                : c),
            DashCrumb(type),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final types = _types;

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
            child: types.isEmpty
                ? const DashEmpty(
                    message: 'No bin types found',
                    hint: 'This location has no bins recorded yet.',
                    icon: Icons.inbox_outlined,
                  )
                : DashContentWidth(
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
                          sliver: SliverList.builder(
                            itemCount: types.length,
                            itemBuilder: (context, index) {
                              final type = types[index];
                              return BinDrillCard(
                                title: type,
                                count: row.count(type),
                                accent: binTypeColor(type),
                                showDot: true,
                                targetNoun: 'bin statuses',
                                onTap: () => _openStatuses(context, type),
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
