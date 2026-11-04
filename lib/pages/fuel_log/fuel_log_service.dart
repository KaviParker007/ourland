// ─── Fuel Log (FuelMaster) — API service ───────────────────────────────────────
//
// Owns the three calls behind the Add Fuel Log screen:
//
//   GET  /drf-add-fuel-log/                         vehicle + fuel station lists
//   GET  /drf_get_last_fueling_detail/?vehicle_id=   previous fueling, alert
//   POST /drf-add-fuel-log/  (multipart/form-data)   create the fuel log
//
// The vehicle and station lists come back already scoped to the user's role and
// zone, so they are shown exactly as returned — never filtered or padded here.
//
// Every failure surfaces as a [FuelLogApiException] whose message is safe to
// show in a snackbar; raw bodies and stack traces stay in the console log
// (services/http_client.dart logs every request).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ourlandnew/config.dart';
import 'package:ourlandnew/models/json_parse.dart';
import 'package:ourlandnew/services/http_client.dart' as http;

import 'last_fueling_detail.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class FuelVehicle {
  final int id;
  final String vehicleNumber;

  const FuelVehicle({required this.id, required this.vehicleNumber});

  factory FuelVehicle.fromJson(Map<String, dynamic> json) {
    final id = asInt(json['id']);
    return FuelVehicle(
      id: id,
      vehicleNumber: asStringOrNull(json['vehicle_number']) ??
          asStringOrNull(json['name']) ??
          'Vehicle $id',
    );
  }
}

class FuelStation {
  final int id;
  final String name;

  const FuelStation({required this.id, required this.name});

  factory FuelStation.fromJson(Map<String, dynamic> json) {
    final id = asInt(json['id']);
    return FuelStation(
      id: id,
      name: asStringOrNull(json['name']) ?? 'Fuel station $id',
    );
  }
}

class FuelLogFormOptions {
  final List<FuelVehicle> vehicles;
  final List<FuelStation> fuelStations;

  const FuelLogFormOptions({required this.vehicles, required this.fuelStations});

  factory FuelLogFormOptions.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(Object? raw) => raw is List
        ? raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const [];
    return FuelLogFormOptions(
      vehicles: rows(json['vehicle_list']).map(FuelVehicle.fromJson).toList(),
      fuelStations:
          rows(json['fuelstation_list']).map(FuelStation.fromJson).toList(),
    );
  }
}

/// What the form posts. Only user-entered fields live here — server-managed
/// ones (fuel_date, project, zone, ward, last_* values) are never sent.
class FuelLogSubmission {
  final int vehicle;
  final int fuelStation;

  /// `D` (Diesel), `P` (Petrol) or `G` (Gas).
  final String fuelType;
  final String odoReading;
  final String fuelQuantity;

  /// Optional: the backend overrides it when the station has a configured price.
  final String? fuelUnitCost;

  /// Sent only when the user entered or changed the tank tag.
  final int? tagNumber;
  final String? remark;

  /// Sent only when the user chose Proceed on the warning dialog — the exact
  /// text the detail endpoint returned.
  final String? alertMessage;

  final String? beforeImagePath;
  final String? indentImagePath;
  final String? afterImagePath;

  const FuelLogSubmission({
    required this.vehicle,
    required this.fuelStation,
    required this.fuelType,
    required this.odoReading,
    required this.fuelQuantity,
    this.fuelUnitCost,
    this.tagNumber,
    this.remark,
    this.alertMessage,
    this.beforeImagePath,
    this.indentImagePath,
    this.afterImagePath,
  });

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;

  /// Multipart text fields. Optional fields are omitted, not sent blank.
  Map<String, String> toFields() => {
        'vehicle': '$vehicle',
        'fuel_station': '$fuelStation',
        'fuel_type': fuelType,
        'odo_reading': odoReading.trim(),
        'fuel_quantity': fuelQuantity.trim(),
        if (_has(fuelUnitCost)) 'fuel_unit_cost': fuelUnitCost!.trim(),
        if (tagNumber != null) 'tag_number': '$tagNumber',
        if (_has(remark)) 'remark': remark!.trim(),
        'alert_message': ?alertMessage,
      };

  /// Multipart file fields, keyed by form field name.
  Map<String, String> toFiles() => {
        if (_has(beforeImagePath)) 'before_image': beforeImagePath!,
        if (_has(indentImagePath)) 'indent_image': indentImagePath!,
        if (_has(afterImagePath)) 'after_image': afterImagePath!,
      };
}

// ── Errors ────────────────────────────────────────────────────────────────────

class FuelLogApiException implements Exception {
  final String message;
  final int? statusCode;

  FuelLogApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

const String kFuelLogNetworkError =
    'Network error. Please check your connection and try again.';
const String kFuelLogSessionExpired =
    'Your session has expired. Please log in again.';

/// `odo_reading` → `Odo reading`.
String _fieldLabel(String key) {
  final words = key.replaceAll('_', ' ').trim();
  if (words.isEmpty) return key;
  return words[0].toUpperCase() + words.substring(1);
}

/// Flattens a message that may be a string, a list of strings, or a map.
String? _flatten(Object? v) {
  if (v == null) return null;
  if (v is String) return v.trim().isEmpty ? null : v.trim();
  if (v is List) {
    final parts = v.map(_flatten).whereType<String>().toList();
    return parts.isEmpty ? null : parts.join('\n');
  }
  if (v is Map) return _serializerErrors(v);
  return v.toString();
}

/// `{"odo_reading": ["Enter a number."]}` → `Odo reading: Enter a number.`
String? _serializerErrors(Map errors) {
  final lines = <String>[];
  errors.forEach((key, value) {
    final text = _flatten(value);
    if (text == null) return;
    lines.add(key == 'non_field_errors' ? text : '${_fieldLabel('$key')}: $text');
  });
  return lines.isEmpty ? null : lines.join('\n');
}

/// Turns a non-success response into a message fit for a snackbar.
///
/// The backend's own validation text (vehicle required, odometer lower than the
/// last reading, quantity / unit cost out of range, serializer errors) is shown
/// as-is because it already reads as a sentence; anything unreadable — an HTML
/// error page, an empty body — becomes a generic message instead.
String fuelLogErrorMessage(int statusCode, String body,
    {String fallback = 'Could not save the fuel log.'}) {
  if (statusCode == 401) return kFuelLogSessionExpired;
  if (statusCode == 403) {
    return 'You do not have permission to perform this action.';
  }
  if (statusCode >= 500) {
    return 'Server error ($statusCode). Please try again later.';
  }

  Object? decoded;
  try {
    decoded = body.trim().isEmpty ? null : jsonDecode(body);
  } on FormatException {
    decoded = null;
  }

  String? message;
  if (decoded is Map) {
    for (final key in const ['error', 'errors', 'message', 'detail']) {
      if (decoded.containsKey(key)) {
        message = _flatten(decoded[key]);
        if (message != null) break;
      }
    }
    message ??= _serializerErrors(decoded);
  } else if (decoded is List || decoded is String) {
    message = _flatten(decoded);
  }

  return message ?? '$fallback Please check the details and try again.';
}

// ── Client-side validation ────────────────────────────────────────────────────

/// Checks the form before anything is sent, mirroring the backend's rules so
/// the user gets the message without a round trip. Returns the first problem,
/// or null when the form is ready. The backend still validates everything.
String? validateFuelLogInput({
  required int? vehicle,
  required int? fuelStation,
  required String? fuelType,
  required String odoReading,
  required String fuelQuantity,
  required String fuelUnitCost,
  required String tagNumber,
  required String beforeImagePath,
  LastFuelingDetail? lastDetail,
}) {
  if (vehicle == null) return 'Please select a vehicle.';
  if (fuelStation == null) return 'Please select a fuel station.';
  if (fuelType == null || !const ['D', 'P', 'G'].contains(fuelType)) {
    return 'Please select a fuel type.';
  }

  if (odoReading.trim().isEmpty) return 'Please enter the odometer reading.';
  final odo = double.tryParse(odoReading.trim());
  if (odo == null || odo < 0) return 'Please enter a valid odometer reading.';
  final lastOdo = lastDetail?.lastOdoReading;
  if (lastDetail != null &&
      !lastDetail.isFirstFueling &&
      lastOdo != null &&
      odo < lastOdo) {
    return 'Odometer reading cannot be less than the last reading '
        '(${lastDetail.odoReadingDisplay}).';
  }

  if (fuelQuantity.trim().isEmpty) return 'Please enter the fuel quantity.';
  final qty = double.tryParse(fuelQuantity.trim());
  if (qty == null || qty < 1 || qty > 250) {
    return 'Fuel quantity must be between 1 and 250.';
  }

  if (fuelUnitCost.trim().isNotEmpty) {
    final cost = double.tryParse(fuelUnitCost.trim());
    if (cost == null || cost < 70 || cost > 120) {
      return 'Fuel unit cost must be between 70 and 120.';
    }
  }

  if (tagNumber.trim().isNotEmpty) {
    final tag = int.tryParse(tagNumber.trim());
    if (tag == null || tag <= 0) {
      return 'Tag number must be a whole number.';
    }
  }

  if (beforeImagePath.trim().isEmpty) return 'Please capture the before image.';
  return null;
}

/// The tag number to post: the entered value when it is new or changed, and
/// null when the field is empty or still holds the previous fueling's tag — so
/// the old tag is never silently re-submitted.
int? tagNumberToSubmit(String entered, int? previousTag) {
  final tag = int.tryParse(entered.trim());
  if (tag == null) return null;
  return tag == previousTag ? null : tag;
}

// ── Service ───────────────────────────────────────────────────────────────────

class FuelLogService {
  final String username;
  final String password;

  FuelLogService({required this.username, required this.password});

  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _uploadTimeout = Duration(seconds: 90);

  String get _auth =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  Map<String, String> get _jsonHeaders =>
      {'Content-Type': 'application/json', 'authorization': _auth};

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.apiUrl}/$path').replace(queryParameters: query);

  Future<http.Response> _get(Uri uri) async {
    try {
      return await http.get(uri, headers: _jsonHeaders).timeout(_timeout);
    } on TimeoutException {
      throw FuelLogApiException('The request timed out. Please try again.');
    } catch (_) {
      throw FuelLogApiException(kFuelLogNetworkError);
    }
  }

  Map<String, dynamic> _decodeObject(http.Response resp) {
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Fall through to the error below.
    }
    throw FuelLogApiException('Could not read the server response.');
  }

  /// Vehicle and fuel station lists for the form, scoped by the backend to the
  /// user's role and zone.
  Future<FuelLogFormOptions> fetchFormOptions() async {
    final resp = await _get(_uri('drf-add-fuel-log/'));
    if (resp.statusCode != 200) {
      throw FuelLogApiException(
        fuelLogErrorMessage(resp.statusCode, resp.body,
            fallback: 'Could not load vehicles and fuel stations.'),
        statusCode: resp.statusCode,
      );
    }
    return FuelLogFormOptions.fromJson(_decodeObject(resp));
  }

  /// Previous fueling for [vehicleId]. A vehicle that has never been fueled
  /// comes back as a zeroed record, which is a valid result, not an error.
  Future<LastFuelingDetail> fetchLastFuelingDetail(int vehicleId) async {
    final resp = await _get(
        _uri('drf_get_last_fueling_detail/', {'vehicle_id': '$vehicleId'}));
    if (resp.statusCode != 200) {
      throw FuelLogApiException(
        fuelLogErrorMessage(resp.statusCode, resp.body,
            fallback: 'Could not load the last fueling details.'),
        statusCode: resp.statusCode,
      );
    }
    return LastFuelingDetail.fromJson(_decodeObject(resp));
  }

  /// Creates the fuel log as multipart/form-data. Returns the backend's success
  /// message when it sends one.
  Future<String?> submitFuelLog(FuelLogSubmission submission) async {
    final request = http.MultipartRequest('POST', _uri('drf-add-fuel-log/'))
      ..headers['authorization'] = _auth
      ..fields.addAll(submission.toFields());

    try {
      for (final entry in submission.toFiles().entries) {
        request.files
            .add(await http.MultipartFile.fromPath(entry.key, entry.value));
      }
    } on FileSystemException {
      throw FuelLogApiException(
          'Could not read a selected image. Please capture it again.');
    }

    final http.Response resp;
    try {
      final streamed = await request.send().timeout(_uploadTimeout);
      resp = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw FuelLogApiException(
          'The upload timed out. Please check your connection and try again.');
    } catch (_) {
      throw FuelLogApiException(kFuelLogNetworkError);
    }

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw FuelLogApiException(
        fuelLogErrorMessage(resp.statusCode, resp.body),
        statusCode: resp.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) return _flatten(decoded['message']);
    } on FormatException {
      // A success with a non-JSON body is still a success.
    }
    return null;
  }
}
