// ─── Bin / collection record ───────────────────────────────────────────────────
//
// `bins/drf_list_queried_bins/` and `bins/drf_list_queried_bin_collection/`
// return the same object shape, so both the Bins and Collections modules parse
// and render it through this one model. On a bin that has never been collected
// the collection fields are simply null.

import 'package:flutter/foundation.dart';

import 'json_parse.dart';

@immutable
class BinRecord {
  final int id;

  /// `lock_card` — true when the record is locked. A locked card is badged and
  /// de-emphasised, and must not offer the actions an unlocked one does.
  final bool lockCard;

  final int? binId;
  final String binNumber;
  final String binType;
  final String? zone;
  final String? ward;

  final String? collectedVehicleNumber;
  final String? deviceId;
  final String? beforeImage;
  final String? afterImage;
  final String? collectedOn;
  final String? leftOn;
  final String? latitude;
  final String? longitude;

  final int? bin;
  final int? collectedVehicle;
  final int? collectedBy;

  const BinRecord({
    required this.id,
    this.lockCard = false,
    this.binId,
    this.binNumber = '—',
    this.binType = '—',
    this.zone,
    this.ward,
    this.collectedVehicleNumber,
    this.deviceId,
    this.beforeImage,
    this.afterImage,
    this.collectedOn,
    this.leftOn,
    this.latitude,
    this.longitude,
    this.bin,
    this.collectedVehicle,
    this.collectedBy,
  });

  /// Only absolute http(s) URLs count as displayable, so a blank string, a null,
  /// or a stray relative path degrades to the placeholder instead of rendering a
  /// broken image.
  static String? normaliseImageUrl(Object? raw) {
    final s = asStringOrNull(raw);
    if (s == null) return null;
    final lower = s.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return null;
    }
    return s;
  }

  String? get before => normaliseImageUrl(beforeImage);
  String? get after => normaliseImageUrl(afterImage);
  bool get hasAnyImage => before != null || after != null;

  double? get lat => asDoubleOrNull(latitude);
  double? get lng => asDoubleOrNull(longitude);
  bool get hasLocation => lat != null && lng != null;

  /// `13.048070, 80.240141`, or null when either coordinate is missing.
  String? get coordinates {
    final a = lat;
    final b = lng;
    if (a == null || b == null) return null;
    return '${a.toStringAsFixed(6)}, ${b.toStringAsFixed(6)}';
  }

  /// True once the record has a collection timestamp.
  bool get isCollected => collectedOn != null;

  factory BinRecord.fromJson(Map<String, dynamic> json) {
    return BinRecord(
      id: asInt(json['id']),
      lockCard: asBool(json['lock_card']),
      binId: asIntOrNull(json['bin_id']),
      binNumber: asStringOrNull(json['bin_number']) ?? '—',
      binType: asStringOrNull(json['bin_type']) ?? '—',
      zone: asStringOrNull(json['zone']),
      ward: asStringOrNull(json['ward']),
      collectedVehicleNumber: asStringOrNull(json['collected_vehicle_number']),
      deviceId: asStringOrNull(json['device_id']),
      beforeImage: asStringOrNull(json['before']),
      afterImage: asStringOrNull(json['after']),
      collectedOn: asStringOrNull(json['collected_on']),
      leftOn: asStringOrNull(json['left_on']),
      latitude: asStringOrNull(json['latitude']),
      longitude: asStringOrNull(json['longitude']),
      bin: asIntOrNull(json['bin']),
      collectedVehicle: asIntOrNull(json['collected_vehicle']),
      collectedBy: asIntOrNull(json['collected_by']),
    );
  }
}
