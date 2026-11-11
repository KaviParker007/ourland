// ─── Shift Dashboard — API service ─────────────────────────────────────────────
//
// One method per endpoint. Auth, logging, URI building and error mapping come
// from DashApiClient, shared with the Bins and Collections dashboards.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ourlandnew/services/dash_api.dart';
import 'package:ourlandnew/services/http_client.dart' as http;

import 'shift_dash_models.dart';

class ShiftEndpoints {
  static const byProject = 'drf_shift_dash_by_project_v2/';
  static const byZone = 'drf_shift_dash_by_zone_v2/';
  static const byCreator = 'drf_shift_dash_by_creator_v2/';
  static const byWard = 'drf_shift_dash_by_ward_v2/';
  static const queriedShifts = 'drf_list_queried_shifts_v2/';
  static const uploadActivityImage = 'drf-upload-shiftactivity-image/';
}

class ShiftDashboardApi extends DashApiClient {
  ShiftDashboardApi._();
  static final ShiftDashboardApi instance = ShiftDashboardApi._();

  @override
  String get logTag => 'SHIFT API';

  static const Duration _uploadTimeout = Duration(seconds: 90);

  Future<List<ShiftDashRow>> _dash(String path, ShiftDashQuery q,
      Map<String, String?> extra, String labelKey) async {
    try {
      final headers = await authHeaders();
      final uri = buildApiUri(
          baseUrl, path, cleanParams({...q.baseParams(), ...extra}));
      final resp = await loggedGet(uri, headers);
      if (resp.statusCode != 200) throw fromResponse(resp);
      final decoded = resp.body.isEmpty ? null : jsonDecode(resp.body);
      return parseShiftDash(decoded, q.status, labelKey);
    } catch (e) {
      mapError(e);
    }
  }

  /// Entry point: counts per project.
  Future<List<ShiftDashRow>> byProject(ShiftDashQuery q) =>
      _dash(ShiftEndpoints.byProject, q, const {}, 'project');

  /// Zones, optionally scoped to [project]. Row label is the zone code.
  Future<List<ShiftDashRow>> byZone(ShiftDashQuery q, {String? project}) =>
      _dash(ShiftEndpoints.byZone, q, {'project': project}, 'zone');

  /// Wards, optionally scoped to [zoneCode]. Counts are distinct per ward
  /// (a vehicle can serve several wards) and are shown as returned.
  Future<List<ShiftDashRow>> byWard(ShiftDashQuery q, {String? zoneCode}) =>
      _dash(ShiftEndpoints.byWard, q, {'zone_code': zoneCode}, 'ward');

  /// Shifts grouped by the employee who started them, optionally in [zoneCode].
  Future<List<ShiftDashRow>> byCreator(ShiftDashQuery q, {String? zoneCode}) =>
      _dash(ShiftEndpoints.byCreator, q, {'zone_code': zoneCode}, 'name');

  /// The shift records behind a dashboard cell. A flat array.
  Future<List<Map<String, dynamic>>> queriedShifts(ShiftListFilter f) async {
    try {
      final headers = await authHeaders();
      final uri =
          buildApiUri(baseUrl, ShiftEndpoints.queriedShifts, cleanParams(f.toParams()));
      final resp = await loggedGet(uri, headers);
      if (resp.statusCode != 200) throw fromResponse(resp);
      return decodeList(resp)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      mapError(e);
    }
  }

  /// Uploads a shift activity photo. The backend attaches it to the shift's
  /// current trip, so no trip is chosen here. Returns the success message.
  Future<String> uploadActivityImage({
    required int shiftId,
    required String imagePath,
    String? remark,
  }) async {
    final headers = await authHeaders();
    final request = http.MultipartRequest(
        'POST', buildApiUri(baseUrl, ShiftEndpoints.uploadActivityImage, const {}))
      ..headers['authorization'] = headers['authorization']!
      ..fields['shift_id'] = '$shiftId';
    final note = remark?.trim() ?? '';
    if (note.isNotEmpty) request.fields['remark'] = note;

    try {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    } on FileSystemException {
      throw DashApiException(
          'Could not read the selected image. Please choose it again.');
    }

    final http.Response resp;
    try {
      final streamed = await request.send().timeout(_uploadTimeout);
      resp = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw DashApiException(
          'The upload timed out. Please check your connection and try again.');
    } catch (_) {
      throw DashApiException('Network error. Please check your connection.');
    }

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return _message(resp.body) ?? 'Image uploaded successfully.';
    }
    throw activityUploadError(resp.statusCode, resp.body);
  }

  static String? _message(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final m = decoded['message'] ?? decoded['error'] ?? decoded['detail'];
        final s = m?.toString().trim();
        return s == null || s.isEmpty ? null : s;
      }
    } on FormatException {
      // Not JSON.
    }
    return null;
  }

  /// Maps an upload failure to a message. 403 means the user lacks the
  /// `vms_app.add_shiftactivity` permission — an access problem, not a login
  /// one — so it gets its own wording.
  static DashApiException activityUploadError(int code, String body) {
    final serverText = _message(body);
    final message = switch (code) {
      401 => 'Your session has expired. Please log in again.',
      403 => "You don't have permission to upload shift activity images. "
          'Please contact your administrator.',
      404 => 'This shift could not be found. It may have been removed.',
      400 when serverText == 'Shift has no current trip.' =>
        'This shift has no current trip to attach the image to.',
      400 => serverText ?? 'Could not upload the image. Please try again.',
      >= 500 => 'Server error. Please try again later.',
      _ => serverText ?? 'Could not upload the image ($code).',
    };
    return DashApiException(message, statusCode: code);
  }
}
