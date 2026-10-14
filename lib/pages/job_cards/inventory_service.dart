// ─── Inventory lookups for the Request Spare screen ────────────────────────────
//
// Three dependent lists, each filtered by the previous selection:
//
//   item types     GET /inventory/drf_list_itemtypes/
//   item subtypes  GET /inventory/drf_list_itemsubtypes/?item_type_id=<id>
//   items          GET /inventory/drf_list_items/?item_type_id=<id>&item_subtype_id=<id>
//
// Only active records (`is_active: true`) are returned to the UI. Parsing is
// tolerant of missing/odd fields so one malformed row cannot break the screen.

import 'dart:convert';

import 'package:ourlandnew/config.dart';
import 'package:ourlandnew/models/json_parse.dart';
import 'package:ourlandnew/services/http_client.dart' as http;

class InventoryItemType {
  final int id;
  final String name;
  final String? code;

  const InventoryItemType({required this.id, required this.name, this.code});

  factory InventoryItemType.fromJson(Map<String, dynamic> json) {
    final code = asStringOrNull(json['item_type_code']);
    return InventoryItemType(
      id: asInt(json['id']),
      name: asStringOrNull(json['name']) ?? code ?? 'Item type ${json['id']}',
      code: code,
    );
  }

  /// Several types share a name (e.g. two "BS 4"), so the code is shown too
  /// when it adds information.
  String get label => code == null || code == name ? name : '$name ($code)';
}

class InventoryItemSubtype {
  final int id;
  final String name;

  const InventoryItemSubtype({required this.id, required this.name});

  factory InventoryItemSubtype.fromJson(Map<String, dynamic> json) {
    return InventoryItemSubtype(
      id: asInt(json['id']),
      name: asStringOrNull(json['name']) ??
          asStringOrNull(json['item_sub_type_name']) ??
          asStringOrNull(json['sub_type_name']) ??
          asStringOrNull(json['item_sub_type_code']) ??
          'Subtype ${json['id']}',
    );
  }
}

class InventoryItem {
  final int id;
  final String name;
  final String? itemCode;
  final String? brandName;
  final String? modelNumber;
  final String? unitOfMeasure;
  final String? description;
  final String? itemTypeCode;
  final String? itemSubTypeName;

  const InventoryItem({
    required this.id,
    required this.name,
    this.itemCode,
    this.brandName,
    this.modelNumber,
    this.unitOfMeasure,
    this.description,
    this.itemTypeCode,
    this.itemSubTypeName,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final code = asStringOrNull(json['item_code']);
    return InventoryItem(
      id: asInt(json['id']),
      name: asStringOrNull(json['name']) ?? code ?? 'Item ${json['id']}',
      itemCode: code,
      brandName: asStringOrNull(json['brand_name']),
      modelNumber: asStringOrNull(json['model_number']),
      unitOfMeasure: asStringOrNull(json['unit_of_measure']),
      description: asStringOrNull(json['description']),
      itemTypeCode: asStringOrNull(json['item_type_code']),
      itemSubTypeName: asStringOrNull(json['item_sub_type_name']),
    );
  }
}

class InventoryApiException implements Exception {
  final String message;
  InventoryApiException(this.message);

  @override
  String toString() => message;
}

class InventoryService {
  final String username;
  final String password;

  InventoryService({required this.username, required this.password});

  static const Duration _timeout = Duration(seconds: 30);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'authorization':
            'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      };

  Future<List<InventoryItemType>> fetchItemTypes() async {
    final rows = await _getActiveRows('drf_list_itemtypes/', const {});
    return rows.map(InventoryItemType.fromJson).toList();
  }

  Future<List<InventoryItemSubtype>> fetchItemSubtypes(int itemTypeId) async {
    final rows = await _getActiveRows(
        'drf_list_itemsubtypes/', {'item_type_id': '$itemTypeId'});
    return rows.map(InventoryItemSubtype.fromJson).toList();
  }

  Future<List<InventoryItem>> fetchItems(
      int itemTypeId, int itemSubtypeId) async {
    final rows = await _getActiveRows('drf_list_items/', {
      'item_type_id': '$itemTypeId',
      'item_subtype_id': '$itemSubtypeId',
    });
    return rows.map(InventoryItem.fromJson).toList();
  }

  /// GETs [path] and returns its active rows. Accepts a bare list or a
  /// `results` / `data` envelope.
  Future<List<Map<String, dynamic>>> _getActiveRows(
      String path, Map<String, String> params) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/inventory/$path')
        .replace(queryParameters: params.isEmpty ? null : params);
    final http.Response resp;
    try {
      resp = await http.get(uri, headers: _headers).timeout(_timeout);
    } catch (_) {
      throw InventoryApiException(
          'Network error. Please check your connection.');
    }
    if (resp.statusCode != 200) {
      throw InventoryApiException('Server error (${resp.statusCode})');
    }

    final Object? decoded;
    try {
      decoded = resp.body.isEmpty ? const [] : jsonDecode(resp.body);
    } on FormatException {
      throw InventoryApiException('Could not read the server response.');
    }
    final list = decoded is List
        ? decoded
        : decoded is Map
            ? (decoded['results'] ?? decoded['data'] ?? const []) as List
            : const [];

    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        // A row with no is_active flag is treated as active.
        .where((e) => !e.containsKey('is_active') || asBool(e['is_active']))
        .toList();
  }
}
