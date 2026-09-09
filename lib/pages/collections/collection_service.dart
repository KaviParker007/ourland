// ─── Collections — API service ─────────────────────────────────────────────────
//
// One method per endpoint. Auth, logging, URI building and error mapping come
// from DashApiClient.
//
// Every method refuses to call out with an invalid date range, so the 7-day rule
// is enforced before a request is made rather than being discovered as a 400.

import 'package:ourlandnew/models/bin_record.dart';
import 'package:ourlandnew/services/dash_api.dart';

import 'collection_models.dart';
import 'collection_query.dart';

class CollectionDashboardApi extends DashApiClient {
  CollectionDashboardApi._();
  static final CollectionDashboardApi instance = CollectionDashboardApi._();

  @override
  String get logTag => 'COLLECTION API';

  /// Guards the documented range rules. Throws a [DashApiException] carrying the
  /// same message the filter bar shows, so callers need no special case.
  void _assertRange(CollectionQuery q) {
    final error = q.range.error;
    if (error != null) throw DashApiException(error);
  }

  /// A — Screen 1. Collections grouped by project and bin type.
  Future<List<CollectionGroupRow>> byProject(CollectionQuery q) {
    _assertRange(q);
    return fetchList(
      CollectionEndpoints.byProject,
      q.aggregateParams(CollectionLevel.project),
      (j) => CollectionGroupRow.fromJson(j, labelKey: 'project'),
    );
  }

  /// B — Screen 2. Requires `project`.
  Future<List<CollectionGroupRow>> byZone(CollectionQuery q) {
    assert(q.project != null, 'byZone requires a project on the query');
    _assertRange(q);
    return fetchList(
      CollectionEndpoints.byZone,
      q.aggregateParams(CollectionLevel.zone),
      // The documented response carries `zone` only; `zone_id` is read when
      // present so a drill-down can pass it on.
      (j) => CollectionGroupRow.fromJson(j, labelKey: 'zone', idKey: 'zone_id'),
    );
  }

  /// C — Screen 3.
  ///
  /// ⚠️ This endpoint filters by `zone_id` alone and takes **no** `project` —
  /// see CollectionQuery.aggregateParams. Omitting `zone_id` returns collections
  /// that have no zone.
  Future<List<CollectionGroupRow>> byWard(CollectionQuery q) {
    _assertRange(q);
    return fetchList(
      CollectionEndpoints.byWard,
      q.aggregateParams(CollectionLevel.ward),
      (j) => CollectionGroupRow.fromJson(j, labelKey: 'ward', idKey: 'ward_id'),
    );
  }

  /// D — Screen 4. The collection list for the accumulated scope and dates.
  Future<List<BinRecord>> listQueriedCollections(CollectionQuery q) {
    _assertRange(q);
    return fetchList(
      CollectionEndpoints.listQueried,
      q.collectionListParams(),
      (j) => BinRecord.fromJson(j),
    );
  }
}
