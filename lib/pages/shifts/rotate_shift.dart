import 'dart:convert';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/input_fields.dart';
import "package:ourlandnew/config.dart";
import 'package:ourlandnew/pages/login.dart';

// ── Shared input decoration ───────────────────────────────────────────────────

InputDecoration _fieldDecor({String? hint}) => InputDecoration(
      hintText: hint,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withAlpha(80)),
      ),
    );

// ── Page ─────────────────────────────────────────────────────────────────────

class RotateShiftPage extends StatefulWidget {
  final int shiftId;
  const RotateShiftPage({super.key, required this.shiftId});

  @override
  State<RotateShiftPage> createState() => _RotateShiftPageState();
}

class _RotateShiftPageState extends State<RotateShiftPage> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List destination = [];
  int? destinationId;
  TextEditingController binCountController = TextEditingController();
  TextEditingController wetWasteController = TextEditingController();
  TextEditingController recycleWasteController = TextEditingController();
  TextEditingController dryWasteController = TextEditingController();
  TextEditingController inertsController = TextEditingController();
  TextEditingController houseHoldHazardController = TextEditingController();
  TextEditingController greenGarbageController = TextEditingController();
  TextEditingController otherWasteController = TextEditingController();
  TextEditingController tripRemarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  // ── API ──────────────────────────────────────────────────────────────────

  Future rotateShift(Map<String, dynamic> data) async {
    try {
      var uri = Uri.parse("$baseUrl/drf-rotate-trip-v2/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'authorization': auth},
        body: jsonEncode(data),
      );
      return response;
    } catch (e) {
      return errorMsg(e.toString());
    }
  }

  void swapShift() async {
    setState(() => isLoading = true);

    if (binCountController.text.isEmpty ||
        wetWasteController.text.isEmpty ||
        recycleWasteController.text.isEmpty ||
        dryWasteController.text.isEmpty ||
        inertsController.text.isEmpty ||
        houseHoldHazardController.text.isEmpty ||
        greenGarbageController.text.isEmpty ||
        otherWasteController.text.isEmpty ||
        destinationId == null) {
      errorMsg("Required * fields cannot be Empty");
    } else {
      final Map<String, dynamic> data = {
        "shift_id": widget.shiftId,
        "bin_count": int.parse(binCountController.text),
        "wet_waste": int.parse(wetWasteController.text),
        "recyclable_waste": int.parse(recycleWasteController.text),
        "dry_waste": int.parse(dryWasteController.text),
        "inerts": int.parse(inertsController.text),
        "household_hazard": int.parse(houseHoldHazardController.text),
        "green_garbages": int.parse(greenGarbageController.text),
        "other_waste": int.parse(otherWasteController.text),
        "destination": destinationId,
        "trip_remark": tripRemarkController.text,
      };

      var response = await rotateShift(data);
      if (response.statusCode == 200) {
        successMsg('Shift rotated successfully');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/shift_dashboard');
        }
      } else {
        print(response.body);
        errorMsg(response.body);
      }
    }

    setState(() => isLoading = false);
  }

  Future<void> getDropDownValues() async {
    setState(() {
      destination = [];
      binCountController.text = '0';
      wetWasteController.text = '0';
      recycleWasteController.text = '0';
      dryWasteController.text = '0';
      inertsController.text = '0';
      houseHoldHazardController.text = '0';
      greenGarbageController.text = '0';
      otherWasteController.text = '0';
    });
    var destinationUri = Uri.parse("$baseUrl/drf-destination-list/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var destinationResponse =
          await http.get(destinationUri, headers: headers);
      if (destinationResponse.statusCode == 200) {
        var shiftData = jsonDecode(destinationResponse.body);
        setState(() {
          destination = shiftData;
        });
      }
    } catch (e) {
      print('Exception: $e');
    }
  }

  void checkLoginStatus() async {
    setState(() => isStarting = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("menu", "shifts");
    String? user = prefs.getString('username');
    String? pass = prefs.getString('password');
    if (user != null && pass != null) {
      setState(() {
        isLoggedIn = true;
        username = user;
        password = pass;
      });
    }
    await getDropDownValues();
    setState(() => isStarting = false);
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

  void successMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) return const LoginPage();
    if (isStarting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Rotate Shift',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
            children: [
              // ── Section 1: Waste Collection ──────────────────────────
              _SectionCard(
                icon: Icons.delete_outline_rounded,
                title: 'Waste Collection',
                children: [
                  const _FieldLabel('Bin Count', required: true),
                  NumberField(controller: binCountController, padding: 14),
                  const SizedBox(height: 14),
                  const _FieldLabel('Wet Waste', required: true),
                  NumberField(controller: wetWasteController, padding: 14),
                  const SizedBox(height: 14),
                  const _FieldLabel('Recyclable Waste', required: true),
                  NumberField(controller: recycleWasteController, padding: 14),
                  const SizedBox(height: 14),
                  const _FieldLabel('Dry Waste', required: true),
                  NumberField(controller: dryWasteController, padding: 14),
                  const SizedBox(height: 14),
                  const _FieldLabel('Inerts', required: true),
                  NumberField(controller: inertsController, padding: 14),
                  const SizedBox(height: 14),
                  const _FieldLabel('Household Hazard', required: true),
                  NumberField(
                      controller: houseHoldHazardController, padding: 14),
                  const SizedBox(height: 14),
                  const _FieldLabel("Green Garbages", required: true),
                  NumberField(controller: greenGarbageController, padding: 14),
                  const SizedBox(height: 14),
                  const _FieldLabel('Other Waste', required: true),
                  NumberField(controller: otherWasteController, padding: 14),
                ],
              ),

              // ── Section 2: Trip Details ──────────────────────────────
              _SectionCard(
                icon: Icons.swap_horiz_rounded,
                title: 'Trip Details',
                children: [
                  const _FieldLabel('Destination', required: true),
                  DropdownSearch<String>(
                    decoratorProps: DropDownDecoratorProps(
                        decoration:
                            _fieldDecor(hint: '')),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration:
                            _fieldDecor(hint: 'Search destination'),
                      ),
                      itemBuilder:
                          (context, item, isSelected, isHighlighted) {
                        final d = destination.firstWhere(
                          (e) => e['id'].toString() == item,
                          orElse: () => {'name': 'Unknown'},
                        );
                        return ListTile(
                          title: Text(d['name'].toString()),
                          selected: isSelected,
                        );
                      },
                    ),
                    items: (filter, loadProps) => destination
                        .map<String>((d) => d['id'].toString())
                        .toList(),
                    filterFn: (item, filter) {
                      final d = destination.firstWhere(
                        (e) => e['id'].toString() == item,
                        orElse: () => {'name': ''},
                      );
                      return d['name']
                          .toString()
                          .toLowerCase()
                          .contains(filter.toLowerCase());
                    },
                    itemAsString: (item) {
                      final d = destination.firstWhere(
                        (e) => e['id'].toString() == item,
                        orElse: () => {'name': ''},
                      );
                      return d['name'].toString();
                    },
                    onSelected: (value) {
                      if (value != null) {
                        setState(() => destinationId = int.parse(value));
                      }
                    },
                    selectedItem: destinationId?.toString(),
                    dropdownBuilder: (context, selectedItem) => Text(
                      selectedItem == null
                          ? 'Select destination'
                          : destination
                              .firstWhere(
                                (e) =>
                                    e['id'].toString() == selectedItem,
                                orElse: () =>
                                    {'name': 'Select destination'},
                              )['name']
                              .toString(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Trip Remark'),
                  TextAreaField(
                    controller: tripRemarkController,
                    hintText: 'Optional trip remarks…',
                    padding: 14,
                  ),
                ],
              ),

              // ── Submit ───────────────────────────────────────────────
              const SizedBox(height: 4),
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: swapShift,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text(
                      'Rotate Shift',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: primary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 20, color: Colors.white.withAlpha(20)),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha(200),
            ),
          ),
          if (required)
            const Text(
              ' *',
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
