// ─── Bins — API service ────────────────────────────────────────────────────────
//
// One method per endpoint. Auth, logging, URI building and error mapping all come
// from DashApiClient, so nothing here is duplicated from the other dashboards.

import 'package:ourlandnew/services/dash_api.dart';

import 'package:ourlandnew/models/bin_record.dart';

import 'bin_models.dart';
import 'bin_query.dart';

class BinDashboardApi extends DashApiClient {
  BinDashboardApi._();
  static final BinDashboardApi instance = BinDashboardApi._();

  @override
  String get logTag => 'BIN API';

  /// A — Screen 1. Bin counts grouped by project and bin type.
  Future<List<BinGroupRow>> dashByProject(BinQuery q) {
    return fetchList(
      BinEndpoints.dashByProject,
      q.aggregateParams(BinLevel.project),
      (j) => BinGroupRow.fromJson(j, labelKey: 'project'),
    );
  }

  /// B — Screen 2. Requires `project`.
  Future<List<BinGroupRow>> dashByZone(BinQuery q) {
    assert(q.project != null, 'dashByZone requires a project on the query');
    return fetchList(
      BinEndpoints.dashByZone,
      q.aggregateParams(BinLevel.zone),
      (j) => BinGroupRow.fromJson(j, labelKey: 'zone', idKey: 'zone_id'),
    );
  }

  /// C — Screen 3. Takes `project`; `zone_id` is omitted when the user drilled
  /// into the unassigned-zone bucket, which is how this endpoint returns bins
  /// that have no zone.
  Future<List<BinGroupRow>> dashByWard(BinQuery q) {
    assert(q.project != null, 'dashByWard requires a project on the query');
    return fetchList(
      BinEndpoints.dashByWard,
      q.aggregateParams(BinLevel.ward),
      (j) => BinGroupRow.fromJson(j, labelKey: 'ward', idKey: 'ward_id'),
    );
  }

  /// D — Screen 4. The bin list for the accumulated scope and filters.
  Future<List<BinRecord>> listQueriedBins(BinQuery q) {
    return fetchList(
      BinEndpoints.listQueriedBins,
      q.binListParams(),
      (j) => BinRecord.fromJson(j),
    );
  }
}
