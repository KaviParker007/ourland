// Parsing of the inventory lookup rows used by the Request Spare screen.

import 'package:flutter_test/flutter_test.dart';

import 'package:ourlandnew/pages/job_cards/inventory_service.dart';

void main() {
  group('InventoryItemType', () {
    test('parses the documented row', () {
      final t = InventoryItemType.fromJson({
        'id': 6,
        'is_active': true,
        'item_type_code': 'OLST00001',
        'name': 'BS 4',
        'description': null,
      });
      expect(t.id, 6);
      expect(t.name, 'BS 4');
      // Two types are both named "BS 4", so the label carries the code.
      expect(t.label, 'BS 4 (OLST00001)');
    });

    test('label omits the code when it equals the name', () {
      final t = InventoryItemType.fromJson(
          {'id': 1, 'item_type_code': 'ItemType01', 'name': 'ItemType01'});
      expect(t.label, 'ItemType01');
    });

    test('falls back to the code when the name is blank', () {
      final t = InventoryItemType.fromJson(
          {'id': 4, 'item_type_code': 'Tyre', 'name': ''});
      expect(t.name, 'Tyre');
    });
  });

  group('InventoryItemSubtype', () {
    test('reads name, or a subtype-specific name field', () {
      expect(InventoryItemSubtype.fromJson({'id': 1, 'name': 'Sub A'}).name,
          'Sub A');
      expect(
          InventoryItemSubtype.fromJson(
              {'id': 2, 'item_sub_type_name': 'subtype_name 01'}).name,
          'subtype_name 01');
    });
  });

  group('InventoryItem', () {
    test('parses the documented row', () {
      final i = InventoryItem.fromJson({
        'id': 1,
        'item_type_code': 'ItemType01',
        'item_sub_type_name': 'subtype_name 01',
        'brand_name': 'TEST',
        'is_active': true,
        'item_code': 'TEST-ITE-SUB01-TESITE01',
        'name': 'test item 01',
        'model_number': '123',
        'description': 'testing',
        'unit_of_measure': 'n',
        'item_type': 1,
        'item_sub_type': 1,
        'brand': 1,
      });
      expect(i.id, 1);
      expect(i.name, 'test item 01');
      expect(i.itemCode, 'TEST-ITE-SUB01-TESITE01');
      expect(i.brandName, 'TEST');
      expect(i.modelNumber, '123');
      expect(i.unitOfMeasure, 'n');
      expect(i.description, 'testing');
    });

    test('blank optional fields become null', () {
      final i = InventoryItem.fromJson(
          {'id': 2, 'name': 'x', 'description': '', 'brand_name': null});
      expect(i.description, isNull);
      expect(i.brandName, isNull);
    });
  });
}
