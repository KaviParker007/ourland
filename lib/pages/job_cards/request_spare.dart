import "dart:convert";
import "package:dropdown_search/dropdown_search.dart";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:ourlandnew/config.dart";
import 'package:ourlandnew/services/http_client.dart' as http;
import "package:ourlandnew/pages/login.dart";

import 'inventory_service.dart';

/// One spare row. The item is picked in three steps — type, then subtype, then
/// item — and each step is cleared when an earlier one changes.
class SelectedSpare {
  InventoryItemType? itemType;
  InventoryItemSubtype? itemSubtype;
  InventoryItem? item;
  int quantity;
  String remark;

  SelectedSpare({this.quantity = 1, this.remark = ''});
}

class RequestSpare extends StatefulWidget {
  final int jobCardId;
  const RequestSpare({super.key, required this.jobCardId});

  @override
  State<RequestSpare> createState() => _RequestSpareState();
}

class _RequestSpareState extends State<RequestSpare> {
  bool isLoggedIn = false;
  bool isStarting = false;
  bool isLoadingItems = false;
  bool isSubmitting = false;

  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;

  InventoryService? inventory;
  List<InventoryItemType> itemTypes = [];
  String? itemTypesError;
  List<SelectedSpare> selectedSpares = [];

  // Shared across rows so picking the same type/subtype twice does not refetch.
  final Map<int, Future<List<InventoryItemSubtype>>> _subtypeCache = {};
  final Map<String, Future<List<InventoryItem>>> _itemCache = {};

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    setState(() => isStarting = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("menu", "job_card");
    String? user = prefs.getString('username');
    String? pass = prefs.getString('password');
    if (user != null && pass != null) {
      setState(() {
        isLoggedIn = true;
        username = user;
        password = pass;
        inventory = InventoryService(username: user, password: pass);
      });
      await fetchItemTypes();
    }
    setState(() => isStarting = false);
  }

  Future<void> fetchItemTypes() async {
    setState(() {
      isLoadingItems = true;
      itemTypesError = null;
    });
    try {
      final types = await inventory!.fetchItemTypes();
      setState(() => itemTypes = types);
    } on InventoryApiException catch (e) {
      setState(() => itemTypesError = e.message);
    }
    setState(() => isLoadingItems = false);
  }

  /// Cached per item type; a failed request is dropped from the cache so the
  /// row's Retry fetches again.
  Future<List<InventoryItemSubtype>> subtypesFor(int itemTypeId) {
    return _subtypeCache.putIfAbsent(
      itemTypeId,
      () => inventory!.fetchItemSubtypes(itemTypeId)
        ..catchError((Object _) {
          _subtypeCache.remove(itemTypeId);
          return const <InventoryItemSubtype>[];
        }),
    );
  }

  Future<List<InventoryItem>> itemsFor(int itemTypeId, int itemSubtypeId) {
    final key = '$itemTypeId-$itemSubtypeId';
    return _itemCache.putIfAbsent(
      key,
      () => inventory!.fetchItems(itemTypeId, itemSubtypeId)
        ..catchError((Object _) {
          _itemCache.remove(key);
          return const <InventoryItem>[];
        }),
    );
  }

  void addSpareRow() {
    setState(() {
      selectedSpares.add(SelectedSpare());
    });
  }

  void removeSpareRow(int index) {
    setState(() {
      selectedSpares.removeAt(index);
    });
  }

  Future<void> submitRequest() async {
    if (selectedSpares.isEmpty) {
      errorMsg("Please add at least one spare item.");
      return;
    }

    for (var i = 0; i < selectedSpares.length; i++) {
      if (selectedSpares[i].item == null) {
        errorMsg("Please select an item for spare ${i + 1}.");
        return;
      }
    }

    // Validate quantities
    for (var spare in selectedSpares) {
      if (spare.quantity <= 0) {
        errorMsg("Quantity must be at least 1 for all items.");
        return;
      }
    }

    setState(() => isSubmitting = true);

    try {
      var uri = Uri.parse("$baseUrl/drf_request_spare_v2/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      var headers = {
        'Content-Type': 'application/json',
        'authorization': auth,
      };

      var body = {
        "id": widget.jobCardId,
        "spares": selectedSpares
            .map((s) => {
          "item": s.item!.id,
          "quantity_requested": s.quantity,
          "request_remark": s.remark,
        })
            .toList(),
      };

      var response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      var decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        String message =
            decoded['message'] ?? 'Spare requested successfully';

        successMsg(message);

        Navigator.pop(context);
        Navigator.pushNamed(context, '/job_card_list');
      } else {
        // Handle all error cases
        if (decoded.containsKey('error')) {
          errorMsg(decoded['error']);
        } else if (decoded.containsKey('errors')) {
          var errors = decoded['errors'];

          if (errors is List) {
            errorMsg(errors.join('\n'));
          } else {
            errorMsg(errors.toString());
          }
        } else {
          errorMsg("Unable to request spare");
        }
      }
    } catch (e) {
      errorMsg("Error: $e");
    }

    setState(() => isSubmitting = false);
  }

  void successMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void errorMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) return const LoginPage();
    if (isStarting) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text("Request Spare"),
          ),
          body: isLoadingItems
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(15),
                  children: [
                    if (itemTypesError != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(Icons.error_outline,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.error),
                              const SizedBox(height: 10),
                              Text(
                                "Could not load item types.\n$itemTypesError",
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: fetchItemTypes,
                                icon: const Icon(Icons.refresh),
                                label: const Text("Retry"),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (selectedSpares.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.outline),
                              const SizedBox(height: 10),
                              Text(
                                itemTypes.isEmpty
                                    ? "No active item types available."
                                    : "No spares added yet.\nTap '+ Add Spare' to begin.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ...selectedSpares.asMap().entries.map((entry) {
                      int index = entry.key;
                      SelectedSpare spare = entry.value;
                      return _SpareRowCard(
                        key: ObjectKey(spare),
                        index: index,
                        spare: spare,
                        itemTypes: itemTypes,
                        loadSubtypes: subtypesFor,
                        loadItems: itemsFor,
                        selectedItemIds: selectedSpares
                            .where((s) => s != spare && s.item != null)
                            .map((s) => s.item!.id)
                            .toList(),
                        onItemTypeChanged: (InventoryItemType? type) {
                          setState(() {
                            spare.itemType = type;
                            spare.itemSubtype = null;
                            spare.item = null;
                          });
                        },
                        onSubtypeChanged: (InventoryItemSubtype? subtype) {
                          setState(() {
                            spare.itemSubtype = subtype;
                            spare.item = null;
                          });
                        },
                        onItemChanged: (InventoryItem? newItem) {
                          setState(() => spare.item = newItem);
                        },
                        onQuantityChanged: (int qty) {
                          setState(() => spare.quantity = qty);
                        },
                        onRemarkChanged: (String remark) {
                          setState(() => spare.remark = remark);
                        },
                        onRemove: () => removeSpareRow(index),
                      );
                    }),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: itemTypes.isEmpty ? null : addSpareRow,
                      icon: const Icon(Icons.add),
                      label: const Text("Add Spare"),
                    ),
                    const SizedBox(height: 80), // padding for FAB
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(15),
            child: isSubmitting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: submitRequest,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text("Submit Request"),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpareRowCard extends StatefulWidget {
  final int index;
  final SelectedSpare spare;
  final List<InventoryItemType> itemTypes;
  final Future<List<InventoryItemSubtype>> Function(int itemTypeId) loadSubtypes;
  final Future<List<InventoryItem>> Function(int itemTypeId, int itemSubtypeId)
      loadItems;
  final List<int> selectedItemIds;
  final ValueChanged<InventoryItemType?> onItemTypeChanged;
  final ValueChanged<InventoryItemSubtype?> onSubtypeChanged;
  final ValueChanged<InventoryItem?> onItemChanged;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<String> onRemarkChanged;
  final VoidCallback onRemove;

  const _SpareRowCard({
    super.key,
    required this.index,
    required this.spare,
    required this.itemTypes,
    required this.loadSubtypes,
    required this.loadItems,
    required this.selectedItemIds,
    required this.onItemTypeChanged,
    required this.onSubtypeChanged,
    required this.onItemChanged,
    required this.onQuantityChanged,
    required this.onRemarkChanged,
    required this.onRemove,
  });

  @override
  State<_SpareRowCard> createState() => _SpareRowCardState();
}

class _SpareRowCardState extends State<_SpareRowCard> {
  late TextEditingController _remarkController;
  late TextEditingController _quantityController;

  List<InventoryItemSubtype> _subtypes = [];
  bool _loadingSubtypes = false;
  String? _subtypeError;

  List<InventoryItem> _items = [];
  bool _loadingItems = false;
  String? _itemError;

  @override
  void initState() {
    super.initState();
    _remarkController = TextEditingController(text: widget.spare.remark);
    _quantityController =
        TextEditingController(text: widget.spare.quantity.toString());
  }

  @override
  void dispose() {
    _remarkController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadSubtypes() async {
    final type = widget.spare.itemType;
    if (type == null) return;
    setState(() {
      _loadingSubtypes = true;
      _subtypeError = null;
      _subtypes = [];
      _items = [];
      _itemError = null;
    });
    try {
      final subtypes = await widget.loadSubtypes(type.id);
      // Ignore a late response for a type the user has since changed.
      if (!mounted || widget.spare.itemType?.id != type.id) return;
      setState(() => _subtypes = subtypes);
    } on InventoryApiException catch (e) {
      if (!mounted || widget.spare.itemType?.id != type.id) return;
      setState(() => _subtypeError = e.message);
    }
    if (mounted) setState(() => _loadingSubtypes = false);
  }

  Future<void> _loadItems() async {
    final type = widget.spare.itemType;
    final subtype = widget.spare.itemSubtype;
    if (type == null || subtype == null) return;
    setState(() {
      _loadingItems = true;
      _itemError = null;
      _items = [];
    });
    try {
      final items = await widget.loadItems(type.id, subtype.id);
      if (!mounted || widget.spare.itemSubtype?.id != subtype.id) return;
      setState(() => _items = items);
    } on InventoryApiException catch (e) {
      if (!mounted || widget.spare.itemSubtype?.id != subtype.id) return;
      setState(() => _itemError = e.message);
    }
    if (mounted) setState(() => _loadingItems = false);
  }

  // Items available for this row: current item + items not picked elsewhere
  List<InventoryItem> get dropdownItems => _items
      .where((item) =>
  item.id == widget.spare.item?.id ||
      !widget.selectedItemIds.contains(item.id))
      .toList();

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  /// Dropdown with a search box in its popup, styled like the other fields.
  /// [idOf] identifies an option, so a selection survives list reloads.
  Widget _searchDropdown<T>({
    Key? key,
    required List<T> items,
    required T? selected,
    required String hint,
    required String searchHint,
    required String Function(T) label,
    required int Function(T) idOf,
    bool Function(T item, String filter)? filterFn,
    required bool enabled,
    required ValueChanged<T> onSelected,
  }) {
    return DropdownSearch<T>(
      key: key,
      items: (filter, loadProps) => items,
      selectedItem: selected,
      enabled: enabled,
      itemAsString: label,
      compareFn: (a, b) => idOf(a) == idOf(b),
      filterFn: filterFn,
      onSelected: (value) {
        if (value != null) onSelected(value);
      },
      decoratorProps: DropDownDecoratorProps(decoration: _decoration(hint)),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        fit: FlexFit.loose,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: searchHint,
            prefixIcon: const Icon(Icons.search),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        emptyBuilder: (context, filter) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            filter.isEmpty ? "No options" : 'No matches for "$filter"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      ),
    );
  }

  static bool _matches(String filter, List<String?> fields) {
    final q = filter.trim().toLowerCase();
    if (q.isEmpty) return true;
    return fields.any((f) => f != null && f.toLowerCase().contains(q));
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );

  /// Spinner, error with Retry, or an empty-list note under a dropdown.
  Widget _status({
    required bool loading,
    required String? error,
    required bool empty,
    required String emptyText,
    required VoidCallback onRetry,
  }) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(),
      );
    }
    if (error != null) {
      return Row(
        children: [
          Expanded(
            child: Text(error,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          TextButton(onPressed: onRetry, child: const Text("Retry")),
        ],
      );
    }
    if (empty) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(emptyText,
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _itemDetails(InventoryItem item) {
    final rows = <(String, String?)>[
      ("Item Code", item.itemCode),
      ("Brand", item.brandName),
      ("Model No.", item.modelNumber),
      ("Unit", item.unitOfMeasure),
      ("Description", item.description),
    ].where((r) => r.$2 != null).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 95,
                    child: Text(label,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline)),
                  ),
                  Expanded(child: Text(value!)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spare = widget.spare;
    final items = dropdownItems;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Spare Item ${widget.index + 1}",
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline,
                      color: Theme.of(context).colorScheme.error),
                  onPressed: widget.onRemove,
                  tooltip: 'Remove',
                ),
              ],
            ),

            // Step 1 — item type
            _label("Item Type"),
            _searchDropdown<InventoryItemType>(
              items: widget.itemTypes,
              selected: spare.itemType,
              hint: "Select item type",
              searchHint: "Search item type",
              label: (t) => t.label,
              idOf: (t) => t.id,
              filterFn: (t, f) => _matches(f, [t.name, t.code]),
              enabled: true,
              onSelected: (type) {
                if (type.id == spare.itemType?.id) return;
                widget.onItemTypeChanged(type);
                _loadSubtypes();
              },
            ),

            // Step 2 — subtype
            const SizedBox(height: 12),
            _label("Item Subtype"),
            _searchDropdown<InventoryItemSubtype>(
              // Rebuilt per type so the selection clears when the type changes.
              key: ValueKey('subtype-${spare.itemType?.id}'),
              items: _subtypes,
              selected: spare.itemSubtype,
              hint: spare.itemType == null
                  ? "Select an item type first"
                  : "Select item subtype",
              searchHint: "Search item subtype",
              label: (s) => s.name,
              idOf: (s) => s.id,
              enabled: spare.itemType != null && !_loadingSubtypes,
              onSelected: (subtype) {
                if (subtype.id == spare.itemSubtype?.id) return;
                widget.onSubtypeChanged(subtype);
                _loadItems();
              },
            ),
            if (spare.itemType != null)
              _status(
                loading: _loadingSubtypes,
                error: _subtypeError,
                empty: _subtypes.isEmpty,
                emptyText: "No active subtypes for this item type.",
                onRetry: _loadSubtypes,
              ),

            // Step 3 — item
            const SizedBox(height: 12),
            _label("Item"),
            _searchDropdown<InventoryItem>(
              key: ValueKey(
                  'item-${spare.itemType?.id}-${spare.itemSubtype?.id}'),
              items: items,
              selected: spare.item,
              hint: spare.itemSubtype == null
                  ? "Select a subtype first"
                  : "Select item",
              searchHint: "Search by name, code or brand",
              label: (i) => i.name,
              idOf: (i) => i.id,
              filterFn: (i, f) => _matches(
                  f, [i.name, i.itemCode, i.brandName, i.modelNumber]),
              enabled: spare.itemSubtype != null && !_loadingItems,
              onSelected: widget.onItemChanged,
            ),
            if (spare.itemSubtype != null)
              _status(
                loading: _loadingItems,
                error: _itemError,
                empty: items.isEmpty,
                emptyText: _items.isEmpty
                    ? "No active items for this subtype."
                    : "All items in this subtype are already added.",
                onRetry: _loadItems,
              ),
            if (spare.item != null) _itemDetails(spare.item!),

            const SizedBox(height: 12),
            Text("Quantity", style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (widget.spare.quantity > 1) {
                      int newQty = widget.spare.quantity - 1;
                      _quantityController.text = newQty.toString();
                      widget.onQuantityChanged(newQty);
                    }
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) {
                      int? parsed = int.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        widget.onQuantityChanged(parsed);
                      }
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    int newQty = widget.spare.quantity + 1;
                    _quantityController.text = newQty.toString();
                    widget.onQuantityChanged(newQty);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text("Remark (Optional)",
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            TextFormField(
              controller: _remarkController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Enter remark...",
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: widget.onRemarkChanged,
            ),
          ],
        ),
      ),
    );
  }
}
