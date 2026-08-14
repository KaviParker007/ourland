// ─── Vehicle Type Dashboard — API service ─────────────────────────────────────
//
// Single owner of all vehicle-dashboard HTTP traffic (one method per endpoint).
// Auth (HTTP Basic, from SharedPreferences) is attached centrally in
// [_authHeaders] — never per call — matching the rest of the app. Consumes the
// 6 (+ terminal) endpoints exactly as specified; no endpoints are invented.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ourlandnew/config.dart';
import 'vehicle_type_models.dart';
import 'vehicle_type_query.dart';

/// A recoverable project choice surfaced by the 400 responses of #2 / #5.
class VehicleChoice {
  final String value;
  final String label;
  const VehicleChoice({required this.value, required this.label});

  static VehicleChoice? fromDynamic(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      final s = raw.trim();
      return s.isEmpty ? null : VehicleChoice(value: s, label: s);
    }
    if (raw is List && raw.isNotEmpty) {
      final value = raw[0]?.toString() ?? '';
      final label = raw.length > 1 ? (raw[1]?.toString() ?? value) : value;
      return value.isEmpty ? null : VehicleChoice(value: value, label: label);
    }
    if (raw is Map) {
      final value = (raw['value'] ?? raw['code'] ?? raw['project'] ?? '')
          .toString();
      final label =
          (raw['display_name'] ?? raw['label'] ?? raw['name'] ?? value)
              .toString();
      return value.isEmpty ? null : VehicleChoice(value: value, label: label);
    }
    return null;
  }
}

/// Typed, user-friendly error. When [projectChoices] is present (a 400 from the
/// zone endpoints), the UI offers a recoverable project picker instead of a
/// generic error.
class VehicleDashException implements Exception {
  final String message;
  final int? statusCode;
  final List<VehicleChoice>? projectChoices;

  VehicleDashException(this.message, {this.statusCode, this.projectChoices});

  bool get hasProjectChoices =>
      projectChoices != null && projectChoices!.isNotEmpty;

  @override
  String toString() => message;
}

class VehicleDashboardApi {
  VehicleDashboardApi._();
  static final VehicleDashboardApi instance = VehicleDashboardApi._();

  static const Duration _timeout = Duration(seconds: 30);
  final String _baseUrl = AppConfig.apiUrl;

  // ── Auth (attached centrally) ───────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final password = prefs.getString('password');
    if (username == null || password == null) {
      throw VehicleDashException(
        'Your session has expired. Please log in again.',
        statusCode: 401,
      );
    }
    final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    return {'Content-Type': 'application/json', 'authorization': auth};
  }

  // ── Error handling ──────────────────────────────────────────────────────────

  Never _mapError(Object e) {
    if (e is VehicleDashException) throw e;
    if (e is TimeoutException) {
      throw VehicleDashException('The request timed out. Please try again.');
    }
    throw VehicleDashException('Network error. Please check your connection.');
  }

  VehicleDashException _fromResponse(http.Response resp) {
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

    if (code == 400 && body != null && body['project_choices'] is List) {
      final choices = (body['project_choices'] as List)
          .map(VehicleChoice.fromDynamic)
          .whereType<VehicleChoice>()
          .toList();
      return VehicleDashException(
        body['detail']?.toString() ?? 'Please choose a project.',
        statusCode: 400,
        projectChoices: choices,
      );
    }
    if (code == 401) {
      return VehicleDashException(
        'Your session has expired. Please log in again.',
        statusCode: 401,
      );
    }
    if (code == 403) {
      return VehicleDashException(
        "You don't have permission to view this data.",
        statusCode: 403,
      );
    }
    if (code >= 500) {
      return VehicleDashException('Server error. Please try again later.',
          statusCode: code);
    }
    final detail = body?['detail']?.toString();
    return VehicleDashException(detail ?? 'Request failed ($code).',
        statusCode: code);
  }

  List _decodeList(http.Response resp) {
    if (resp.body.isEmpty) return const [];
    final data = jsonDecode(resp.body);
    if (data is List) return data;
    if (data is Map) return (data['results'] ?? data['data'] ?? const []) as List;
    return const [];
  }

  // ── Logged GET ──────────────────────────────────────────────────────────────

  void _logApi({required String title, required List<String> lines}) {
    const bar = '══════════════════════════════════════════════════════════';
    final buffer = StringBuffer()
      ..writeln('\n╔$bar')
      ..writeln('║ $title')
      ..writeln('╟$bar');
    for (final line in lines) {
      for (final sub in line.split('\n')) {
        buffer.writeln('║ $sub');
      }
    }
    buffer.write('╚$bar');
    // ignore: avoid_print
    print(buffer.toString());
  }

  Map<String, String> _maskHeaders(Map<String, String> headers) {
    final masked = Map<String, String>.from(headers);
    if (masked.containsKey('authorization')) {
      masked['authorization'] = 'Basic ****** (masked)';
    }
    return masked;
  }

  Future<http.Response> _get(Uri uri, Map<String, String> headers) async {
    _logApi(title: 'VEHICLE API ▶ REQUEST', lines: [
      'Method        : GET',
      'API URL       : ${uri.scheme}://${uri.authority}${uri.path}',
      'Query Params  : '
          '${uri.queryParameters.isEmpty ? '(none)' : uri.queryParameters}',
      'Headers       : ${_maskHeaders(headers)}',
    ]);
    final sw = Stopwatch()..start();
    try {
      final resp = await http.get(uri, headers: headers).timeout(_timeout);
      sw.stop();
      final isError = resp.statusCode < 200 || resp.statusCode >= 300;
      _logApi(
        title: isError
            ? 'VEHICLE API ✖ RESPONSE (${resp.statusCode})'
            : 'VEHICLE API ✔ RESPONSE (${resp.statusCode})',
        lines: [
          'API URL       : ${uri.scheme}://${uri.authority}${uri.path}',
          'Status Code   : ${resp.statusCode}',
          'Execution Time: ${sw.elapsed.inMilliseconds} ms',
          '${isError ? 'Error Response' : 'Response Body '}: '
              '${resp.body.isEmpty ? '(empty)' : resp.body}',
        ],
      );
      return resp;
    } catch (e) {
      sw.stop();
      _logApi(title: 'VEHICLE API ✖ REQUEST FAILED', lines: [
        'API URL       : ${uri.scheme}://${uri.authority}${uri.path}',
        'Execution Time: ${sw.elapsed.inMilliseconds} ms',
        'Error         : $e',
      ]);
      rethrow;
    }
  }

  Future<List<T>> _fetchList<T>(
    String path,
    Map<String, String> params,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final headers = await _authHeaders();
      final uri = buildVehicleUri(_baseUrl, path, params);
      final resp = await _get(uri, headers);
      if (resp.statusCode != 200) throw _fromResponse(resp);
      return _decodeList(resp)
          .whereType<Map>()
          .map((e) => parse(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _mapError(e);
    }
  }

  // ─── Chain A — By Location (vehicle_type pivot) ────────────────────────────────

  /// Screen 1 (#1) — Project pivot. Rows = project, columns = vehicle_type. The
  /// project level has no id, so [VehiclePivotRow.id] stays null and drilling
  /// keys off the label.
  Future<List<VehiclePivotRow>> dashByProject(VehicleQuery q) {
    return _fetchList(
      VehicleEndpoints.dashByProject,
      q.aggregateParams(chain: VehicleChain.location, level: VehicleLevel.project),
      (j) => VehiclePivotRow.fromJson(j, labelKey: 'project'),
    );
  }

  /// Screen 2 (#2) — Zone pivot. [q] must carry `project`.
  Future<List<VehiclePivotRow>> dashByZone(VehicleQuery q) {
    assert(q.project != null, 'dashByZone requires a project on the query');
    return _fetchList(
      VehicleEndpoints.dashByZone,
      q.aggregateParams(chain: VehicleChain.location, level: VehicleLevel.zone),
      (j) => VehiclePivotRow.fromJson(j, labelKey: 'zone', idKey: 'zone_id'),
    );
  }

  /// Screen 3 (#3) — Ward pivot. [q] must carry `zone_id`; `project` rides along
  /// so the request matches the documented
  /// `?zone_id={zone_id}&project={project}` shape.
  Future<List<VehiclePivotRow>> dashByWard(VehicleQuery q) {
    assert(q.zoneId != null, 'dashByWard requires a zoneId on the query');
    return _fetchList(
      VehicleEndpoints.dashByWard,
      q.aggregateParams(chain: VehicleChain.location, level: VehicleLevel.ward),
      (j) => VehiclePivotRow.fromJson(j, labelKey: 'ward', idKey: 'ward_id'),
    );
  }

  // ─── Chain B — By Status ───────────────────────────────────────────────────────

  /// #4 — Project status buckets.
  Future<List<VehicleStatusRow>> statusByProject(VehicleQuery q) {
    return _fetchList(
      VehicleEndpoints.statusByProject,
      q.aggregateParams(chain: VehicleChain.status, level: VehicleLevel.project),
      (j) => VehicleStatusRow.fromJson(j, labelKey: 'project', idKey: 'project'),
    );
  }

  /// #5 — Zone status buckets. Includes a trailing `zone_id == "Total"` summary
  /// row (parsed as [VehicleStatusRow.isTotalRow]).
  Future<List<VehicleStatusRow>> statusByZone(VehicleQuery q) {
    assert(q.project != null, 'statusByZone requires a project on the query');
    return _fetchList(
      VehicleEndpoints.statusByZone,
      q.aggregateParams(chain: VehicleChain.status, level: VehicleLevel.zone),
      (j) => VehicleStatusRow.fromJson(j, labelKey: 'zone', idKey: 'zone_id'),
    );
  }

  /// #6 — Ward status buckets.
  Future<List<VehicleStatusRow>> statusByWard(VehicleQuery q) {
    assert(q.zoneId != null, 'statusByWard requires a zoneId on the query');
    return _fetchList(
      VehicleEndpoints.statusByWard,
      q.aggregateParams(chain: VehicleChain.status, level: VehicleLevel.ward),
      (j) => VehicleStatusRow.fromJson(j, labelKey: 'ward', idKey: 'ward_id'),
    );
  }

  // ─── Screen 4 (#3b) — Terminal vehicle list (both chains) ──────────────────────

  /// Terminal list. [q] carries the full accumulated location scope plus the
  /// selected vehicle type; [statusOverride] lets Chain B forward the tapped
  /// status bucket in place of the carried `vehicle_status` filter.
  Future<List<VehicleRecord>> queriedVehicles(
    VehicleQuery q, {
    String? statusOverride,
  }) {
    return _fetchList(
      VehicleEndpoints.queriedVehicles,
      q.vehicleListParams(statusOverride: statusOverride),
      (j) => VehicleRecord.fromJson(j),
    );
  }

  // ─── Idle reason (mirrors the classic vehicle list swipe action) ───────────────

  /// Logs an idle reason for [vehicleId] on [idleDate] (yyyy-MM-dd). Returns true
  /// when the backend responds `{"message": "success"}`.
  Future<bool> submitIdleReason({
    required int vehicleId,
    required String reason,
    required String idleDate,
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = buildVehicleUri(_baseUrl, VehicleEndpoints.idleReason, const {});
      final body = jsonEncode({
        'id': vehicleId,
        'reason': reason,
        'idle_date': idleDate,
      });
      _logApi(title: 'VEHICLE API ▶ REQUEST', lines: [
        'Method        : POST',
        'API URL       : $uri',
        'Headers       : ${_maskHeaders(headers)}',
        'Body/Payload  : $body',
      ]);
      final resp =
          await http.post(uri, headers: headers, body: body).timeout(_timeout);
      _logApi(title: 'VEHICLE API ◀ RESPONSE (${resp.statusCode})', lines: [
        'API URL       : $uri',
        'Status Code   : ${resp.statusCode}',
        'Response Body : ${resp.body.isEmpty ? '(empty)' : resp.body}',
      ]);
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw _fromResponse(resp);
      }
      final decoded = resp.body.isEmpty ? null : jsonDecode(resp.body);
      return decoded is Map && decoded['message'] == 'success';
    } catch (e) {
      _mapError(e);
    }
  }
}
