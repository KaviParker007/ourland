import 'dart:convert';
import 'dart:io';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/input_fields.dart';
import "package:ourlandnew/config.dart";
import 'package:ourlandnew/pages/login.dart';
import '../../components/image_picker.dart';

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

class EndShiftPage extends StatefulWidget {
  final int shiftId;
  const EndShiftPage({super.key, required this.shiftId});

  @override
  State<EndShiftPage> createState() => _EndShiftPageState();
}

class _EndShiftPageState extends State<EndShiftPage> {
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
  TextEditingController shiftRemarkController = TextEditingController();
  TextEditingController inKmController = TextEditingController();
  TextEditingController imageController = TextEditingController();
  TextEditingController odoMeterImageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  // ── API ──────────────────────────────────────────────────────────────────

  Future endShift(
      Map<String, dynamic> data, Map<String, String> images) async {
    try {
      var uri = Uri.parse("$baseUrl/drf-end-shift-v2/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      var request = http.MultipartRequest('POST', uri)
        ..headers['authorization'] = auth;

      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      for (var entry in images.entries) {
        if (entry.value.isNotEmpty) {
          request.files.add(
            await http.MultipartFile.fromPath(entry.key, entry.value),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      return response;
    } catch (e) {
      return errorMsg(e.toString());
    }
  }

  void startShift() async {
    setState(() => isLoading = true);

    if (binCountController.text.isEmpty ||
        wetWasteController.text.isEmpty ||
        recycleWasteController.text.isEmpty ||
        dryWasteController.text.isEmpty ||
        inertsController.text.isEmpty ||
        houseHoldHazardController.text.isEmpty ||
        greenGarbageController.text.isEmpty ||
        otherWasteController.text.isEmpty ||
        destinationId == null ||
        inKmController.text.isEmpty ||
        imageController.text.isEmpty ||
        odoMeterImageController.text.isEmpty) {
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
        "shift_remark": shiftRemarkController.text,
        "in_km": int.parse(inKmController.text),
      };

      final Map<String, String> images = {
        "end_image": imageController.text,
        "end_odometer": odoMeterImageController.text,
      };

      var response = await endShift(data, images);
      if (response.statusCode == 200) {
        successMsg('Shift ended successfully');
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
              'End Shift',
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
                icon: Icons.local_shipping_rounded,
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

              // ── Section 3: Shift Summary ─────────────────────────────
              _SectionCard(
                icon: Icons.summarize_rounded,
                title: 'Shift Summary',
                children: [
                  const _FieldLabel('Shift Remark'),
                  TextAreaField(
                    controller: shiftRemarkController,
                    hintText: 'Optional shift remarks…',
                    padding: 14,
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('In KM', required: true),
                  NumberField(
                    controller: inKmController,
                    padding: 14,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                    ],
                  ),
                ],
              ),

              // ── Section 4: End Photos ────────────────────────────────
              _SectionCard(
                icon: Icons.camera_alt_rounded,
                title: 'End Photos',
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ImageUploadCard(
                          title: 'End Image',
                          required: true,
                          imagePath: imageController.text,
                          onImagePicked: (f) =>
                              setState(() => imageController.text = f.path),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ImageUploadCard(
                          title: 'Odometer',
                          required: true,
                          imagePath: odoMeterImageController.text,
                          onImagePicked: (f) => setState(
                              () => odoMeterImageController.text = f.path),
                        ),
                      ),
                    ],
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
                    onPressed: startShift,
                    icon: const Icon(Icons.flag_rounded),
                    label: const Text(
                      'End Shift',
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

// ── Image upload card ─────────────────────────────────────────────────────────

class _ImageUploadCard extends StatelessWidget {
  final String title;
  final bool required;
  final String imagePath;
  final void Function(File) onImagePicked;

  const _ImageUploadCard({
    required this.title,
    required this.required,
    required this.imagePath,
    required this.onImagePicked,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (required)
                const Text(
                  ' *',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
            ],
          ),
        ),
        // Preview container
        Container(
          height: 118,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasImage
                  ? Colors.green.withAlpha(110)
                  : Colors.grey.withAlpha(60),
              width: 1.5,
            ),
            color: Colors.white.withAlpha(4),
          ),
          child: hasImage
              ? _ImagePreview(imagePath: imagePath)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 30,
                      color: Colors.grey.withAlpha(110),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'No photo yet',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.withAlpha(130),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 6),
        // Camera button
        CameraImagePicker(
          onImagePicked: onImagePicked,
          text: hasImage ? 'Retake' : 'Capture',
        ),
      ],
    );
  }
}

// ── Image preview ─────────────────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  final String imagePath;

  const _ImagePreview({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => _errorState(),
        );
      }
      return _errorState();
    } catch (_) {
      return _errorState();
    }
  }

  Widget _errorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.broken_image_outlined, color: Colors.red, size: 26),
        SizedBox(height: 4),
        Text('Failed to load',
            style: TextStyle(color: Colors.red, fontSize: 10)),
      ],
    );
  }
}
