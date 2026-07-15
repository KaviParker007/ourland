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
      print('response__check');
      print(resp.body);
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

  // ── 1. GVP list ─────────────────────────────────────────────────────────────

  Future<List<Gvp>> getGvpList({
    String? zone,
    String? ward,
    String? project,
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$_baseUrl/drf_gvp_list').replace(
        queryParameters: _clean({
          'zone': zone,
          'ward': ward,
          'project': project,
        }),
      );
      final resp = await http.get(uri, headers: headers).timeout(_timeout);
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

  // ── 2. Create-form options ──────────────────────────────────────────────────

  Future<GvpCreateOptions> getGvpCreateOptions() async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$_baseUrl/drf_gvp_create');
      final resp = await http.get(uri, headers: headers).timeout(_timeout);
      if (resp.statusCode != 200) throw _fromResponse(resp);
      final data = _decode(resp);
      return GvpCreateOptions.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      _mapError(e);
    }
  }

  // ── 3. Create GVP ────────────────────────────────────────────────────────────

  Future<void> createGvp(GvpCreateRequest payload) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$_baseUrl/drf_gvp_create');
      final resp = await http
          .post(uri, headers: headers, body: jsonEncode(payload.toJson()))
          .timeout(_timeout);
      print('codeedd');
      print(resp.statusCode);
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
      final uri = Uri.parse('$_baseUrl/drf_gvp_detail/$id');
      print('drf_gvp_detail_check');
      print(uri);
      final resp = await http.get(uri, headers: headers).timeout(_timeout);
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
      final uri = Uri.parse('$_baseUrl/drf_gvp_update/$id');
      final resp = await http
          .patch(uri, headers: headers, body: jsonEncode(changedFields))
          .timeout(_timeout);
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
      final uri = Uri.parse('$_baseUrl/drf_gvp_by_project');
      final resp = await http.get(uri, headers: headers).timeout(_timeout);
      if (resp.statusCode != 200) throw _fromResponse(resp);
      final data = _decode(resp);
      final map = Map<String, dynamic>.from(data as Map);
      final list = map.entries
          .map((e) => GvpProjectCount(
                project: e.key,
                count: (e.value is num)
                    ? (e.value as num).toInt()
                    : int.tryParse(e.value.toString()) ?? 0,
              ))
          .toList();
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
      final uri = Uri.parse('$_baseUrl/drf_gvp_by_zone')
          .replace(queryParameters: _clean({'project': project}));
      final resp = await http.get(uri, headers: headers).timeout(_timeout);
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
      final uri = Uri.parse('$_baseUrl/drf_gvp_by_ward')
          .replace(queryParameters: _clean({'zone': zoneId?.toString()}));

      // ── Debug: log the outgoing Ward API request (fired on zone select) ──
      _logWardApi(
        title: 'WARD API — REQUEST',
        lines: [
          'Method       : GET',
          'Zone (param) : ${zoneId ?? '(none)'}',
          'URL          : $uri',
          'Headers      : ${_maskHeaders(headers)}',
          'Request Body : None (GET request has no body)',
        ],
      );

      final resp = await http.get(uri, headers: headers).timeout(_timeout);

      // ── Debug: log the Ward API response ──
      _logWardApi(
        title: 'WARD API — RESPONSE',
        lines: [
          'URL          : $uri',
          'Status Code  : ${resp.statusCode}',
          'Response Body: ${resp.body.isEmpty ? '(empty)' : resp.body}',
        ],
      );

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

  // ── Ward API debug logging helpers ────────────────────────────────────────────
  // Clear, boxed console output for verifying the Ward API integration. The
  // Authorization credential is masked so logs never leak the Basic-auth token.

  void _logWardApi({required String title, required List<String> lines}) {
    final buffer = StringBuffer()
      ..writeln('\n╔══════════════════════════════════════════════════════════')
      ..writeln('║ $title')
      ..writeln('╟──────────────────────────────────────────────────────────');
    for (final line in lines) {
      buffer.writeln('║ $line');
    }
    buffer.write('╚══════════════════════════════════════════════════════════');
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

  // ── 9. Queried GVP list (final drill-down) ───────────────────────────────────
  // Send ONLY the most specific selected filter (ward_id > zone_id > project).

  Future<List<Gvp>> getQueriedGvpList({
    int? wardId,
    int? zoneId,
    String? project,
  }) async {
    final params = <String, String>{};
    if (wardId != null) {
      params['ward_id'] = wardId.toString();
    } else if (zoneId != null) {
      params['zone_id'] = zoneId.toString();
    } else if (project != null && project.isNotEmpty) {
      params['project'] = project;
    }
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$_baseUrl/drf_list_queried_gvp')
          .replace(queryParameters: params);
      final resp = await http.get(uri, headers: headers).timeout(_timeout);
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
      final uri = Uri.parse('$_baseUrl/drf_gvp_add_reference_image/$gvpId');
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

      final streamed = await request.send().timeout(_timeout);
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw _fromResponse(resp);
      }
    } catch (e) {
      _mapError(e);
    }
  }

  // ── 11. Delete reference image (204, no body) ────────────────────────────────

  Future<void> deleteReferenceImage(int imageId) async {
    try {
      final headers = await _authHeaders();
      final uri =
          Uri.parse('$_baseUrl/drf_gvp_delete_reference_image/$imageId');
      final resp = await http.delete(uri, headers: headers).timeout(_timeout);
      // 204 No Content is success — do NOT try to parse a JSON body.
      if (resp.statusCode == 204 || resp.statusCode == 200) return;
      throw _fromResponse(resp);
    } catch (e) {
      _mapError(e);
    }
  }
}
