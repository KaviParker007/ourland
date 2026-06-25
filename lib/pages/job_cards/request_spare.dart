import "dart:convert";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:ourlandnew/components/buttons.dart";
import "package:ourlandnew/config.dart";
import 'package:http/http.dart' as http;
import "package:ourlandnew/pages/login.dart";

class SpareItem {
  final int id;
  final String name;

  SpareItem({required this.id, required this.name});

  factory SpareItem.fromJson(Map<String, dynamic> json) {
    return SpareItem(id: json['id'], name: json['name']);
  }
}

class SelectedSpare {
  SpareItem item;
  int quantity;
  String remark;

  SelectedSpare({required this.item, this.quantity = 1, this.remark = ''});
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

  List<SpareItem> availableItems = [];
  List<SelectedSpare> selectedSpares = [];

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
      });
      await fetchSpareItems();
    }
    setState(() => isStarting = false);
  }

  Future<void> fetchSpareItems() async {
    setState(() => isLoadingItems = true);
    try {
      var uri = Uri.parse("$baseUrl/drf_request_spare_v2/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      var headers = {'Content-Type': 'application/json', 'authorization': auth};
      var response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        List<dynamic> items = decoded['items'] ?? [];
        setState(() {
          availableItems = items.map((e) => SpareItem.fromJson(e)).toList();
        });
      } else {
        errorMsg("Failed to load spare items");
      }
    } catch (e) {
      errorMsg("Error loading items: $e");
    }
    setState(() => isLoadingItems = false);
  }

  void addSpareRow() {
    if (availableItems.isEmpty) return;

    // Pick the first item not already selected, or default to first
    SpareItem defaultItem = availableItems.firstWhere(
          (item) => !selectedSpares.any((s) => s.item.id == item.id),
      orElse: () => availableItems.first,
    );

    setState(() {
      selectedSpares.add(SelectedSpare(item: defaultItem));
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
          "item": s.item.id,
          "quantity_requested": s.quantity,
          "request_remark": s.remark,
        })
            .toList(),
      };

      // PRINT REQUEST DATA
      print("========== API REQUEST ==========");
      print("URL: $uri");
      print("Headers: $headers");
      print("Body: ${jsonEncode(body)}");

      var response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      // PRINT RESPONSE DATA
      print("========== API RESPONSE ==========");
      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

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
      print("========== API ERROR ==========");
      print("Error: $e");

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
                    if (selectedSpares.isEmpty)
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
                                "No spares added yet.\nTap '+ Add Spare' to begin.",
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
                        key: ValueKey(index),
                        spare: spare,
                        availableItems: availableItems,
                        selectedItemIds: selectedSpares
                            .where((s) => s != spare)
                            .map((s) => s.item.id)
                            .toList(),
                        onItemChanged: (SpareItem? newItem) {
                          if (newItem != null) {
                            setState(() => spare.item = newItem);
                          }
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
                      onPressed: availableItems.isEmpty ? null : addSpareRow,
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
  final SelectedSpare spare;
  final List<SpareItem> availableItems;
  final List<int> selectedItemIds;
  final ValueChanged<SpareItem?> onItemChanged;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<String> onRemarkChanged;
  final VoidCallback onRemove;

  const _SpareRowCard({
    super.key,
    required this.spare,
    required this.availableItems,
    required this.selectedItemIds,
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

  // Items available for this row: current item + unselected items
  List<SpareItem> get dropdownItems => widget.availableItems
      .where((item) =>
  item.id == widget.spare.item.id ||
      !widget.selectedItemIds.contains(item.id))
      .toList();

  @override
  Widget build(BuildContext context) {
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
                    "Spare Item",
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
            const SizedBox(height: 6),
            DropdownButtonFormField<SpareItem>(
              value: dropdownItems.any((i) => i.id == widget.spare.item.id)
                  ? dropdownItems.firstWhere((i) => i.id == widget.spare.item.id)
                  : dropdownItems.isNotEmpty
                  ? dropdownItems.first
                  : null,
              decoration: InputDecoration(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              items: dropdownItems
                  .map((item) => DropdownMenuItem<SpareItem>(
                value: item,
                child: Text(item.name),
              ))
                  .toList(),
              onChanged: widget.onItemChanged,
            ),
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