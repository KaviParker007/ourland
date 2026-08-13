// ─── GVP Module — Reusable API service ────────────────────────────────────────
//
// Single place that owns all `/gvp` HTTP traffic. Every screen goes through
// this service so no HTTP logic is duplicated across widgets. Uses the app's
// existing Basic-auth scheme (username/password in SharedPreferences) and the
// shared AppConfig base URL.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ourlandnew/config.dart';
import 'gvp_models.dart';

/// User-friendly, typed error surfaced to the UI. When [fieldErrors] is
/// present it carries backend field-level validation messages so the form can
/// render them beneath the matching field.
class GvpApiException implements Exception {
  final String message;
  final Map<String, List<String>>? fieldErrors;
  final int? statusCode;

  GvpApiException(this.message, {this.fieldErrors, this.statusCode});

  bool get hasFieldErrors => fieldErrors != null && fieldErrors!.isNotEmpty;

  @override
  String toString() => message;
}

class GvpService {
  GvpService._();
  static final GvpService instance = GvpService._();

  static const Duration _timeout = Duration(seconds: 30);
  final String _baseUrl = '${AppConfig.apiUrl}/gvp';

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final password = prefs.getString('password');
    if (username == null || password == null) {
      throw GvpApiException('Your session has expired. Please log in again.',
          statusCode: 401);
    }
    final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    return {
      if (json) 'Content-Type': 'application/json',
      'authorization': auth,
    };
  }

  // ── Query param sanitising ─────────────────────────────────────────────────
  // Drops null / empty values so we never send `?zone=` or `?zone=null`.

  Map<String, String> _clean(Map<String, String?> params) {
    final out = <String, String>{};
    params.forEach((k, v) {
      if (v != null && v.trim().isNotEmpty) out[k] = v.trim();
    });
    return out;
  }

  // ── Error translation ───────────────────────────────────────────────────────

  Never _mapError(Object e) {
    if (e is GvpApiException) throw e;
    if (e is SocketException) {
      throw GvpApiException('No internet connection. Please check your network.');
    }
    if (e is TimeoutException) {
      throw GvpApiException('The request timed out. Please try again.');
    }
    throw GvpApiException('Something went wrong. Please try again.');
  }

  /// Converts a non-2xx response into a [GvpApiException] with the clearest
  /// message we can derive, preserving field errors for forms.
  GvpApiException _fromResponse(http.Response resp) {
    final code = resp.statusCode;
    Map<String, dynamic>? body;
    try {
      if (resp.body.isNotEmpty) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      }
    } catch (_) {
      body = null;
    }

    // Explicit backend error string, e.g. {"error": "GVP not found"}
    final errorText = body?['error']?.toString();

    switch (code) {
      case 400:
        // Field-level validation errors: {"name": ["This field is required."]}
        if (body != null) {
          final fieldErrors = <String, List<String>>{};
          body.forEach((key, value) {
            if (key == 'error') return;
            if (value is List) {
              fieldErrors[key] = value.map((e) => e.toString()).toList();
            } else if (value is String) {
              fieldErrors[key] = [value];
            }
          });
          if (fieldErrors.isNotEmpty) {
            return GvpApiException('Please correct the highlighted fields.',
                fieldErrors: fieldErrors, statusCode: 400);
          }
        }
        return GvpApiException(errorText ?? 'Invalid request.',
            statusCode: 400);
      case 401:
        return GvpApiException(
            'Your session has expired. Please log in again.',
            statusCode: 401);
      case 403:
        return GvpApiException(
            "You don't have permission to perform this action.",
            statusCode: 403);
      case 404:
        return GvpApiException(errorText ?? 'The requested item was not found.',
            statusCode: 404);
      default:
        if (code >= 500) {
          return GvpApiException('Server error. Please try again later.',
              statusCode: code);
        }
        return GvpApiException(errorText ?? 'Request failed ($code).',
            statusCode: code);
    }
  }

  dynamic _decode(http.Response resp) {
    if (resp.body.isEmpty) {
      throw GvpApiException('The server returned an empty response.',
          statusCode: resp.statusCode);
    }
    try {
      return jsonDecode(resp.body);
    } catch (_) {
      throw GvpApiException('The server returned an unreadable response.',
          statusCode: resp.statusCode);
    }
  }

  // ── 1. Create-form options ──────────────────────────────────────────────────

  Future<GvpCreateOptions> getGvpCreateOptions() async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$_baseUrl/drf_gvp_create/');
      final resp = await _send('GET', uri, headers: headers);
      if (resp.statusCode != 200) throw _fromResponse(resp);
      final data = _decode(resp);
      return GvpCreateOptions.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      _mapError(e);
    }
  }

  // ── 2b. Dependent dropdown choices (Add GVP form) ─────────────────────────────
  // These live at the API root (NOT under /gvp) and power the dependent
  // Project → Zone → Ward hierarchy on the Add/Edit GVP form.

  /// Projects the user may pick from. Parses `project_choices`: `[["MDU","Madurai"], …]`.
  Future<List<GvpChoice>> getProjectChoices() async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('${AppConfig.apiUrl}/drf_getmy_project_choices/');
      final resp = await _send('GET', uri, headers: headers);
      if (resp.statusCode != 200) throw _fromResponse(resp);
      final data = _decode(resp);
      final raw = (data is Map) ? data['project_choices'] : null;
      return (raw is List)
          ? raw.map(GvpChoice.fromDynamic).whereType<GvpChoice>().toList()
          : <GvpChoice>[];
    } catch (e) {
      _mapError(e);
    }
  }

  /// Zones for [projectCode]. Parses `user_project_zone_choices`: `[[7,"MDU-Z1"], …]`.
  Future<List<GvpZoneChoice>> getProjectZoneChoices(String projectCode) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('${AppConfig.apiUrl}/drf_getmy_project_zone_choices/')
          .replace(queryParameters: _clean({'project': projectCode}));
      final resp = await _send('GET', uri, headers: headers);
      if (resp.statusCode != 200) throw _fromResponse(resp);
      final data = _decode(resp);
      final raw = (data is Map) ? data['user_project_zone_choices'] : null;
      return (raw is List)
          ? raw.map(GvpZoneChoice.fromDynamic).whereType<GvpZoneChoice>().toList()
          : <GvpZoneChoice>[];
    } catch (e) {
      _mapError(e);
    }
  }

  /// Wards for [zoneId]. Parses `zonal_ward_choices`: `[[94,"MDU-Z1-W39"], …]`.
  Future<List<GvpWardChoice>> getZonalWardChoices(int zoneId) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('${AppConfig.apiUrl}/drf_zonal_ward_choices/')
          .replace(queryParameters: _clean({'zone_id': zoneId.toString()}));
      final resp = await _send('GET', uri, headers: headers);
      if (resp.statusCode != 200) throw _fromResponse(resp);
      final data = _decode(resp);
      final raw = (data is Map) ? data['zonal_ward_choices'] : null;
      return (raw is List)
          ? raw.map(GvpWardChoice.fromDynamic).whereType<GvpWardChoice>().toList()
          : <GvpWardChoice>[];
    } catch (e) {
      _mapError(e);
    }
  }

  // ── 3. Create GVP ────────────────────────────────────────────────────────────

  Future<void> createGvp(GvpCreateRequest payload) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$_baseUrl/drf_gvp_create/');
      final resp = await _send('POST', uri,
          headers: headers, body: jsonEncode(payload.toJson()));
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw _fromResponse(resp);
      }
    } catch (e) {
      _mapError(e);
    }
  }

  // ── 4. GVP detail ────────────────────────────────────────────────────────────

  Future<GvpDetail> getGvpDetails(int id) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$_baseUrl/drf_gvp_detail/$id/');
      final resp = await _send('GET', uri, headers: headers);
      if (resp.statusCode != 200) throw _fromResponse(resp);
      final data = _decode(resp);
      return GvpDetail.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      _mapError(e);
    }
  }

  // ── 5. Update GVP (PATCH — only changed fields) ──────────────────────────────

  Future<GvpDetail> updateGvp(int id, Map<String, dynamic> changedFields) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$_baseUrl/drf_gvp_update/$id/');
      final resp = await _send('PATCH', uri,
          headers: headers, body: jsonEncode(changedFields));
      if (resp.statusCode != 200) throw _fromResponse(resp);
      final data = _decode(resp);
      return GvpDetail.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      _mapError(e);
    }
  }

  // ── 6. Count by project ──────────────────────────────────────────────────────

  Future<List<GvpProjectCount>> getGvpCountByProject() async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$_baseUrl/drf_gvp_by_project/');
      final resp = await _send('GET', uri, headers: headers);
      if (resp.statusCode != 200) throw _fromResponse(resp);
      final data = _decode(resp);
      // New format: an array of { project, NC, WIP, C } objects.
      final list = (data is List)
          ? data
              .whereType<Map>()
              .map((e) => GvpProjectCount.fromJson(Map<String, dynamic>.from(e)))
              .where((p) => p.project.isNotEmpty)
              .toList()
          : <GvpProjectCount>[];
      // Preserve a stable order following the canonical project list.
      list.sort((a, b) {
        final ia = kGvpProjects.indexOf(a.project);
        final ib = kGvpProjects.indexOf(b.project);
        return (ia == -1 ? 999 : ia).compareTo(ib == -1 ? 999 : ib);
      });
      return list;
    } catch (e) {
      _mapError(e);
    }
  }

  // ── 7. Count by zone ─────────────────────────────────────────────────────────

  Future<List<GvpZoneCount>> getGvpCountByZone({String? project}) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$_baseUrl/drf_gvp_by_zone/')
          .replace(queryParameters: _clean({'project': project}));
      final resp = await _send('GET', uri, headers: headers);
      if (resp.statusCode != 200) throw _fromResponse(resp);
      final data = _decode(resp);
      return (data as List)
          .whereType<Map>()
          .map((e) => GvpZoneCount.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _mapError(e);
    }
  }

  // ── 8. Count by ward ─────────────────────────────────────────────────────────

  Future<List<GvpWardCount>> getGvpCountByWard({int? zoneId}) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$_baseUrl/drf_gvp_by_ward/')
          .replace(queryParameters: _clean({'zone': zoneId?.toString()}));
      final resp = await _send('GET', uri, headers: headers);
      if (resp.statusCode != 200) throw _fromResponse(resp);
      final data = _decode(resp);
      return (data as List)
          .whereType<Map>()
          .map((e) => GvpWardCount.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _mapError(e);
    }
  }

  // ── API debug logging ─────────────────────────────────────────────────────────
  // Every GVP request goes through _send / _sendMultipart, which log a boxed
  // REQUEST block (method, API URL, query params, headers, body params) and a
  // RESPONSE block (status code, execution time, response/error body). Network
  // failures (timeouts, no connectivity) are logged as a REQUEST FAILED block.
  // The Authorization credential is always masked so logs never leak the
  // Basic-auth token. Logging never alters the returned response.

  void _logApi({required String title, required List<String> lines}) {
    const bar = '══════════════════════════════════════════════════════════';
    final buffer = StringBuffer()
      ..writeln('\n╔$bar')
      ..writeln('║ $title')
      ..writeln('╟$bar');
    for (final line in lines) {
      // Split embedded newlines (pretty-printed JSON) so every physical line
      // keeps the box prefix and stays aligned.
      for (final sub in line.split('\n')) {
        buffer.writeln('║ $sub');
      }
    }
    buffer.write('╚$bar');
    // ignore: avoid_print
    print(buffer.toString());
  }

  /// Returns a copy of [headers] with the Authorization value masked.
  Map<String, String> _maskHeaders(Map<String, String> headers) {
    final masked = Map<String, String>.from(headers);
    if (masked.containsKey('authorization')) {
      masked['authorization'] = 'Basic ****** (masked)';
    }
    return masked;
  }

  /// The URL without its query string (query params are logged separately).
  String _baseUrlOf(Uri uri) => '${uri.scheme}://${uri.authority}${uri.path}';

  /// Pretty-prints a JSON string/body for readable console output; falls back
  /// to the raw text when it is not valid JSON.
  String _prettyBody(Object? body) {
    if (body == null) return '(none)';
    final raw = body is String ? body : body.toString();
    if (raw.isEmpty) return '(empty)';
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }

  void _logRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Object? body,
    Map<String, String>? multipartFields,
    List<String>? multipartFiles,
  }) {
    final qp = uri.queryParameters;
    final lines = <String>[
      'HTTP Method   : $method',
      'API URL       : ${_baseUrlOf(uri)}',
      'Query Params  : ${qp.isEmpty ? '(none)' : qp}',
      'Headers       : ${_maskHeaders(headers)}',
    ];
    if (multipartFields != null) {
      lines
        ..add('Content-Type  : multipart/form-data')
        ..add('Body Params   : '
            '${multipartFields.isEmpty ? '(none)' : multipartFields}')
        ..add('Files         : '
            '${(multipartFiles == null || multipartFiles.isEmpty) ? '(none)' : multipartFiles.join(', ')}');
    } else {
      lines.add('Body Params   : ${_prettyBody(body)}');
    }
    _logApi(title: 'GVP API ▶ REQUEST', lines: lines);
  }

  void _logResponse({
    required String method,
    required Uri uri,
    required int statusCode,
    required String body,
    required Duration elapsed,
  }) {
    final isError = statusCode < 200 || statusCode >= 300;
    final lines = <String>[
      'HTTP Method   : $method',
      'API URL       : ${_baseUrlOf(uri)}',
      'Status Code   : $statusCode',
      'Execution Time: ${elapsed.inMilliseconds} ms',
      isError
          ? 'Error Response: ${_prettyBody(body)}'
          : 'Response Body : ${_prettyBody(body)}',
    ];
    _logApi(
      title: isError
          ? 'GVP API ✖ RESPONSE ($statusCode)'
          : 'GVP API ✔ RESPONSE ($statusCode)',
      lines: lines,
    );
  }

  void _logError({
    required String method,
    required Uri uri,
    required Object error,
    required Duration elapsed,
  }) {
    _logApi(title: 'GVP API ✖ REQUEST FAILED', lines: [
      'HTTP Method   : $method',
      'API URL       : ${_baseUrlOf(uri)}',
      'Execution Time: ${elapsed.inMilliseconds} ms',
      'Error         : $error',
    ]);
  }

  /// Sends a GET/POST/PATCH/DELETE request with consistent request/response
  /// logging, returning the raw [http.Response] for the caller to handle.
  Future<http.Response> _send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    Object? body,
  }) async {
    _logRequest(method: method, uri: uri, headers: headers, body: body);
    final sw = Stopwatch()..start();
    try {
      final http.Response resp;
      switch (method) {
        case 'GET':
          resp = await http.get(uri, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          resp = await http
              .post(uri, headers: headers, body: body)
              .timeout(_timeout);
          break;
        case 'PATCH':
          resp = await http
              .patch(uri, headers: headers, body: body)
              .timeout(_timeout);
          break;
        case 'DELETE':
          resp = await http.delete(uri, headers: headers).timeout(_timeout);
          break;
        default:
          throw GvpApiException('Unsupported HTTP method: $method');
      }
      sw.stop();
      _logResponse(
        method: method,
        uri: uri,
        statusCode: resp.statusCode,
        body: resp.body,
        elapsed: sw.elapsed,
      );
      return resp;
    } catch (e) {
      sw.stop();
      _logError(method: method, uri: uri, error: e, elapsed: sw.elapsed);
      rethrow;
    }
  }

  /// Sends a multipart request (image uploads) with the same logging shape,
  /// listing the text fields and attached file field names/sizes.
  Future<http.Response> _sendMultipart(http.MultipartRequest request) async {
    _logRequest(
      method: request.method,
      uri: request.url,
      headers: request.headers,
      multipartFields: request.fields,
      multipartFiles: request.files
          .map((f) => '${f.field}="${f.filename}" (${f.length} bytes)')
          .toList(),
    );
    final sw = Stopwatch()..start();
    try {
      final streamed = await request.send().timeout(_timeout);
      final resp = await http.Response.fromStream(streamed);
      sw.stop();
      _logResponse(
        method: request.method,
        uri: request.url,
        statusCode: resp.statusCode,
        body: resp.body,
        elapsed: sw.elapsed,
      );
      return resp;
    } catch (e) {
      sw.stop();
      _logError(
        method: request.method,
        uri: request.url,
        error: e,
        elapsed: sw.elapsed,
      );
      rethrow;
    }
  }

  // ── 9. Queried GVP list (final drill-down) ───────────────────────────────────
  // Sends the full selected hierarchy (project / zone_id / ward_id) plus the
  // optional today_status filter, e.g.:
  //   /gvp/drf_list_queried_gvp/?project=MDU&zone_id=7&ward_id=75&today_status=C

  Future<List<Gvp>> getQueriedGvpList({
    int? wardId,
    int? zoneId,
    String? project,
    String? todayStatus,
  }) async {
    final params = _clean({
      'project': project,
      'zone_id': zoneId?.toString(),
      'ward_id': wardId?.toString(),
      'today_status': todayStatus,
    });
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$_baseUrl/drf_list_queried_gvp/')
          .replace(queryParameters: params);
      final resp = await _send('GET', uri, headers: headers);
      if (resp.statusCode != 200) throw _fromResponse(resp);
      final data = _decode(resp);
      final list = data is List ? data : (data['results'] ?? data['data'] ?? []);
      return (list as List)
          .whereType<Map>()
          .map((e) => Gvp.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _mapError(e);
    }
  }

  // ── 10. Add reference image (multipart, one image per call) ──────────────────

  Future<void> addReferenceImage(
    int gvpId,
    File image, {
    String? caption,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      // Never manually set the multipart boundary — MultipartRequest does it.
      final headers = await _authHeaders(json: false);
      final uri = Uri.parse('$_baseUrl/drf_gvp_add_reference_image/$gvpId/');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers);

      if (!await image.exists()) {
        throw GvpApiException('The selected image file could not be found.');
      }
      request.files
          .add(await http.MultipartFile.fromPath('image', image.path));
      final trimmedCaption = caption?.trim();
      if (trimmedCaption != null && trimmedCaption.isNotEmpty) {
        request.fields['caption'] = trimmedCaption;
      }

      final resp = await _sendMultipart(request);
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw _fromResponse(resp);
      }
    } catch (e) {
      _mapError(e);
    }
  }

  // ── 12. Create daily confirmation — "Before" (multipart POST) ─────────────────
  // Called only when today_status == "NT". Camera capture only — the caller is
  // responsible for passing a fresh camera image (gallery is not permitted).
  // The backend sets before_image_by/on, confirmed_date and moves the GVP to WIP.

  Future<DailyConfirmation> createDailyConfirmation({
    required int gvpId,
    required File beforeImage,
    double? latitude,
    double? longitude,
    String? remark,
  }) async {
    try {
      final headers = await _authHeaders(json: false);
      final uri = Uri.parse('$_baseUrl/drf_daily_confirmation_create/');
      if (!await beforeImage.exists()) {
        throw GvpApiException('The captured image could not be found.');
      }
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers)
        ..fields['gvp'] = gvpId.toString();
      request.files.add(
          await http.MultipartFile.fromPath('before_image', beforeImage.path));
      if (latitude != null) {
        request.fields['before_image_latitude'] = latitude.toString();
      }
      if (longitude != null) {
        request.fields['before_image_longitude'] = longitude.toString();
      }
      final trimmed = remark?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        request.fields['before_image_remark'] = trimmed;
      }

      final resp = await _sendMultipart(request);
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw _fromResponse(resp);
      }
      final data = _decode(resp);
      return DailyConfirmation.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      _mapError(e);
    }
  }

  // ── 13. Close daily confirmation — "After" (multipart PATCH) ──────────────────
  // Called only when today_status == "WIP". [confirmationId] is the
  // GVPDailyConfirmation id (NOT the GVP id). The backend sets after_image_by/on,
  // last_cleaned and moves the GVP to C (cleared).

  Future<DailyConfirmation> closeDailyConfirmation({
    required int confirmationId,
    required File afterImage,
    double? latitude,
    double? longitude,
    String? remark,
  }) async {
    try {
      final headers = await _authHeaders(json: false);
      final uri =
          Uri.parse('$_baseUrl/drf_daily_confirmation_close/$confirmationId/');
      if (!await afterImage.exists()) {
        throw GvpApiException('The captured image could not be found.');
      }
      final request = http.MultipartRequest('PATCH', uri)
        ..headers.addAll(headers);
      request.files.add(
          await http.MultipartFile.fromPath('after_image', afterImage.path));
      if (latitude != null) {
        request.fields['after_image_latitude'] = latitude.toString();
      }
      if (longitude != null) {
        request.fields['after_image_longitude'] = longitude.toString();
      }
      final trimmed = remark?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        request.fields['after_image_remark'] = trimmed;
      }

      final resp = await _sendMultipart(request);
      if (resp.statusCode != 200) {
        throw _fromResponse(resp);
      }
      final data = _decode(resp);
      return DailyConfirmation.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      _mapError(e);
    }
  }

  // ── 14. Delete reference image (204, no body) ────────────────────────────────

  Future<void> deleteReferenceImage(int imageId) async {
    try {
      final headers = await _authHeaders();
      final uri =
          Uri.parse('$_baseUrl/drf_gvp_delete_reference_image/$imageId/');
      final resp = await _send('DELETE', uri, headers: headers);
      // 204 No Content is success — do NOT try to parse a JSON body.
      if (resp.statusCode == 204 || resp.statusCode == 200) return;
      throw _fromResponse(resp);
    } catch (e) {
      _mapError(e);
    }
  }
}
