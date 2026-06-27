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

class AddShiftPage extends StatefulWidget {
  const AddShiftPage({super.key});

  @override
  State<AddShiftPage> createState() => _AddShiftPageState();
}

class _AddShiftPageState extends State<AddShiftPage> {
  // ── State (unchanged) ────────────────────────────────────────────────────
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List vehicles = [];
  List routes = [];
  List<int> selectedRouteIds = [];
  Map<String, String> routeMapId = {};
  String? shiftName = "I";
  String? engineOilLevel = "Not Checked";
  String? coolantOilLevel = "Not Checked";
  String? outKm = "";
  int? vehicle;
  TextEditingController outKMController = TextEditingController();
  TextEditingController driverController = TextEditingController();

  String? driverType;
  String? driverId;
  TextEditingController otherDriverRemarkController = TextEditingController();
  TextEditingController driverNameController = TextEditingController();
  TextEditingController actingDriverLicenseController =
      TextEditingController();

  List<Map<String, dynamic>> regularDrivers = [];
  List<Map<String, dynamic>> spareDrivers = [];

  bool? audioSystem = false;
  bool? barrel = false;
  bool? rack = false;
  bool? broom = false;
  bool? annakoodai = false;
  dynamic shiftData;
  TextEditingController frontImageController = TextEditingController();
  TextEditingController rightImageController = TextEditingController();
  TextEditingController backImageController = TextEditingController();
  TextEditingController leftImageController = TextEditingController();
  TextEditingController odoMeterImageController = TextEditingController();
  TextEditingController? vehicleComplaintController =
      TextEditingController();
  TextEditingController complaintDetailsController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  // ── API (unchanged) ──────────────────────────────────────────────────────

  Future addShift(
      Map<String, dynamic> data, Map<String, dynamic> images) async {
    try {
      var uri = Uri.parse("$baseUrl/drf-start-shift-v3/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      var request = http.MultipartRequest('POST', uri)
        ..headers['authorization'] = auth;

      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      for (var entry in images.entries) {
        if (entry.value.isNotEmpty) {
          File imageFile = File(entry.value);
          if (await imageFile.exists()) {
            request.files.add(
              await http.MultipartFile.fromPath(entry.key, entry.value),
            );
          } else {
            print('File does not exist: ${entry.value}');
          }
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      return response;
    } catch (e) {
      print('Error in addShift: $e');
      return errorMsg(e.toString());
    }
  }

  void startShift() async {
    setState(() => isLoading = true);

    if ((shiftName == null || shiftName!.isEmpty) ||
        (vehicle == null || vehicle.toString().isEmpty) ||
        (routes == [] || routes.toString().isEmpty) ||
        (driverType == null || driverType!.isEmpty) ||
        frontImageController.text.isEmpty ||
        leftImageController.text.isEmpty ||
        backImageController.text.isEmpty ||
        rightImageController.text.isEmpty ||
        odoMeterImageController.text.isEmpty) {
      errorMsg("Required * fields cannot be Empty");
    } else {
      String driverName = '';
      String driverEmployeeId = '';
      String actingLicense = '';
      String otherRemark = '';

      switch (driverType) {
        case 'Regular':
        case 'Spare':
          var driversList =
              driverType == 'Regular' ? regularDrivers : spareDrivers;
          var selectedDriver = driversList.firstWhere(
            (driver) => driver['employee_id'].toString() == driverId,
            orElse: () => {'employee_name': ''},
          );
          driverName = selectedDriver['employee_name'];
          driverEmployeeId = driverId ?? '';
          print('driverEmployeeId_____ddskjdn');
          print(driverEmployeeId);
          break;
        case 'Acting':
          driverName = driverNameController.text;
          actingLicense = actingDriverLicenseController.text;
          break;
        case 'Others':
          driverName = driverNameController.text;
          otherRemark = otherDriverRemarkController.text;
          break;
      }

      final Map<String, dynamic> data = {
        "vehicle": vehicle,
        "shift_name": shiftName,
        "out_km": outKMController.text,
        "driver_type": driverType,
        "driver_id": driverEmployeeId,
        "driver_name": driverName,
        "acting_driver_license": actingLicense,
        "other_driver_remark": otherRemark,
        "engine_oil_level": engineOilLevel,
        "coolant_oil_level": coolantOilLevel,
        "audio_system": audioSystem,
        "barrel": barrel,
        "rack": rack,
        "broom": broom,
        "annakoodai": annakoodai,
        "complaint_details": complaintDetailsController.text.isEmpty
            ? "-"
            : complaintDetailsController.text,
      };

      final Map<String, dynamic> images = {
        "start_front": frontImageController.text,
        "start_right": rightImageController.text,
        "start_back": backImageController.text,
        "start_left": leftImageController.text,
        "start_odometer": odoMeterImageController.text,
        "vehicle_complaint": vehicleComplaintController?.text ?? "",
      };
      print('data____requestbody');
      print(data);
      print(images);

      var response = await addShift(data, images);

      if (response.statusCode == 200) {
        successMsg('Shift created successfully');
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
      vehicles = [];
      routes = [];
      outKMController.text = "0";
    });

    var startShiftUri = Uri.parse("$baseUrl/drf-start-shift-v3/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {
      'Content-Type': 'application/json',
      'authorization': auth,
    };

    try {
      var startShiftResponse =
          await http.get(startShiftUri, headers: headers);
      if (startShiftResponse.statusCode == 200) {
        shiftData = jsonDecode(startShiftResponse.body);
        print('shiftData___');
        print(shiftData);
        setState(() {
          vehicles = shiftData['vehicles'];
          var routesList =
              List<Map<String, dynamic>>.from(shiftData['routes'] ?? []);
          routes = List<String>.from(
              routesList.map((route) => route['route']));
          routeMapId = {
            for (var route in routesList)
              route['route']: route['id'].toString()
          };
          regularDrivers = List<Map<String, dynamic>>.from(
              shiftData['regular_drivers'] ?? []);
          spareDrivers = List<Map<String, dynamic>>.from(
              shiftData['spare_drivers'] ?? []);
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
              'Start Shift',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
            children: [
              // ── Section 1: Shift Details ─────────────────────────────
              _SectionCard(
                icon: Icons.schedule_rounded,
                title: 'Shift Details',
                children: [
                  const _FieldLabel('Shift Name', required: true),
                  DropdownButtonFormField<String>(
                    value: shiftName,
                    decoration: _fieldDecor(),
                    items: ['I', 'II', 'III', 'Others']
                        .map((v) => DropdownMenuItem(
                            value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(() => shiftName = v),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Vehicle', required: true),
                  DropdownSearch<String>(
                    decoratorProps: DropDownDecoratorProps(
                        decoration: _fieldDecor(hint: '')),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration:
                            _fieldDecor(hint: 'Search vehicles'),
                      ),
                      itemBuilder:
                          (context, item, isSelected, isHighlighted) {
                        return ListTile(
                          title: Text(
                            vehicles
                                .firstWhere(
                                  (e) => e['id'].toString() == item,
                                  orElse: () =>
                                      {'vehicle_number': 'Unknown'},
                                )['vehicle_number']
                                .toString(),
                          ),
                        );
                      },
                    ),
                    items: (filter, loadProps) => vehicles
                        .map<String>((v) => v['id'].toString())
                        .toList(),
                    itemAsString: (item) => vehicles
                        .firstWhere(
                          (e) => e['id'].toString() == item,
                          orElse: () => {'vehicle_number': ''},
                        )['vehicle_number']
                        .toString(),
                    onSelected: (value) {
                      if (value != null) {
                        final sel = vehicles.firstWhere(
                            (v) => v['id'].toString() == value);
                        setState(() {
                          vehicle = int.parse(value);
                          outKMController.text =
                              sel['current_km'].toDouble().toStringAsFixed(0);
                        });
                      }
                    },
                    selectedItem: vehicle?.toString(),
                    dropdownBuilder: (context, selectedItem) => Text(
                      vehicles
                          .firstWhere(
                            (e) => e['id'].toString() == selectedItem,
                            orElse: () =>
                                {'vehicle_number': 'Select a vehicle'},
                          )['vehicle_number']
                          .toString(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Out KM'),
                  NumberField(
                    controller: outKMController,
                    padding: 14,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                    ],
                  ),
                ],
              ),

              // ── Section 2: Driver Information ────────────────────────
              _SectionCard(
                icon: Icons.person_rounded,
                title: 'Driver Information',
                children: [
                  const _FieldLabel('Driver Type', required: true),
                  DropdownButtonFormField<String>(
                    value: driverType,
                    decoration: _fieldDecor(hint: 'Select driver type'),
                    items: ['Regular', 'Spare', 'Acting', 'Others']
                        .map((v) => DropdownMenuItem(
                            value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() {
                          driverType = v;
                          driverId = null;
                        }),
                  ),

                  // Regular / Spare — searchable driver list
                  if (driverType == 'Regular' ||
                      driverType == 'Spare') ...[
                    const SizedBox(height: 14),
                    const _FieldLabel('Driver', required: true),
                    DropdownSearch<String>(
                      decoratorProps: DropDownDecoratorProps(
                          decoration: _fieldDecor(hint: '')),
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          decoration: _fieldDecor(
                              hint: 'Search by name or ID'),
                        ),
                        itemBuilder: (context, item, isSelected,
                            isHighlighted) {
                          final list = driverType == 'Regular'
                              ? regularDrivers
                              : spareDrivers;
                          final driver = list.firstWhere(
                            (d) =>
                                d['employee_id'].toString() == item,
                            orElse: () => {
                              'employee_name': 'Unknown',
                              'employee_id': ''
                            },
                          );
                          return ListTile(
                            title: Text(driver['employee_name']),
                            subtitle:
                                Text('ID: ${driver['employee_id']}'),
                            selected: isSelected,
                          );
                        },
                      ),
                      items: (filter, loadProps) =>
                          (driverType == 'Regular'
                                  ? regularDrivers
                                  : spareDrivers)
                              .map<String>(
                                  (d) => d['employee_id'].toString())
                              .toList(),
                      filterFn: (item, filter) {
                        final list = driverType == 'Regular'
                            ? regularDrivers
                            : spareDrivers;
                        final d = list.firstWhere(
                          (d) => d['employee_id'].toString() == item,
                          orElse: () =>
                              {'employee_name': '', 'employee_id': ''},
                        );
                        return d['employee_name']
                                .toLowerCase()
                                .contains(filter.toLowerCase()) ||
                            d['employee_id']
                                .toString()
                                .toLowerCase()
                                .contains(filter.toLowerCase());
                      },
                      compareFn: (a, b) {
                        final list = driverType == 'Regular'
                            ? regularDrivers
                            : spareDrivers;
                        final da = list.firstWhere(
                            (d) => d['employee_id'].toString() == a,
                            orElse: () => {'employee_name': ''});
                        final db = list.firstWhere(
                            (d) => d['employee_id'].toString() == b,
                            orElse: () => {'employee_name': ''});
                        return da['employee_name']
                            .compareTo(db['employee_name']);
                      },
                      itemAsString: (item) {
                        final list = driverType == 'Regular'
                            ? regularDrivers
                            : spareDrivers;
                        final d = list.firstWhere(
                          (d) => d['employee_id'].toString() == item,
                          orElse: () =>
                              {'employee_name': '', 'employee_id': ''},
                        );
                        return '${d['employee_name']} (${d['employee_id']})';
                      },
                      onSelected: (value) =>
                          setState(() {
                            driverId = value;
                            print(driverId);
                          }),
                      selectedItem: driverId,
                      dropdownBuilder: (context, selectedItem) {
                        if (selectedItem == null) {
                          return const Text('Select Driver');
                        }
                        final list = driverType == 'Regular'
                            ? regularDrivers
                            : spareDrivers;
                        final d = list.firstWhere(
                          (d) =>
                              d['employee_id'].toString() ==
                              selectedItem,
                          orElse: () => {
                            'employee_name': 'Select Driver',
                            'employee_id': ''
                          },
                        );
                        return Text(
                            '${d['employee_name']} (${d['employee_id']})');
                      },
                    ),
                  ],

                  // Acting
                  if (driverType == 'Acting') ...[
                    const SizedBox(height: 14),
                    const _FieldLabel('Driver Name', required: true),
                    BasicInputField(
                        controller: driverNameController, padding: 14),
                    const SizedBox(height: 14),
                    const _FieldLabel('Acting Driver License',
                        required: true),
                    BasicInputField(
                        controller: actingDriverLicenseController,
                        padding: 14),
                  ],

                  // Others
                  if (driverType == 'Others') ...[
                    const SizedBox(height: 14),
                    const _FieldLabel('Driver Name', required: true),
                    BasicInputField(
                        controller: driverNameController, padding: 14),
                    const SizedBox(height: 14),
                    const _FieldLabel('Other Driver Remark'),
                    TextAreaField(
                        controller: otherDriverRemarkController,
                        padding: 14),
                  ],
                ],
              ),

              // ── Section 3: Vehicle Condition ─────────────────────────
              _SectionCard(
                icon: Icons.oil_barrel_rounded,
                title: 'Vehicle Condition',
                children: [
                  const _FieldLabel('Engine Oil Level'),
                  DropdownButtonFormField<String>(
                    value: engineOilLevel,
                    decoration: _fieldDecor(),
                    items: ['Not Checked', 'Normal', 'Low', 'Very Low']
                        .map((v) => DropdownMenuItem(
                            value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => engineOilLevel = v),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Coolant Oil Level'),
                  DropdownButtonFormField<String>(
                    value: coolantOilLevel,
                    decoration: _fieldDecor(),
                    items: ['Not Checked', 'Normal', 'Low', 'Very Low']
                        .map((v) => DropdownMenuItem(
                            value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => coolantOilLevel = v),
                  ),
                ],
              ),

              // ── Section 4: Equipment Check ───────────────────────────
              _SectionCard(
                icon: Icons.checklist_rounded,
                title: 'Equipment Check',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _EquipChip(
                        label: 'Audio System',
                        icon: Icons.speaker_rounded,
                        selected: audioSystem!,
                        onChanged: (v) =>
                            setState(() => audioSystem = v),
                      ),
                      _EquipChip(
                        label: 'Barrel',
                        icon: Icons.water_drop_outlined,
                        selected: barrel!,
                        onChanged: (v) => setState(() => barrel = v),
                      ),
                      _EquipChip(
                        label: 'Rack',
                        icon: Icons.grid_view_rounded,
                        selected: rack!,
                        onChanged: (v) => setState(() => rack = v),
                      ),
                      _EquipChip(
                        label: 'Broom',
                        icon: Icons.cleaning_services_rounded,
                        selected: broom!,
                        onChanged: (v) => setState(() => broom = v),
                      ),
                      _EquipChip(
                        label: 'Annakoodai',
                        icon: Icons.shopping_basket_rounded,
                        selected: annakoodai!,
                        onChanged: (v) =>
                            setState(() => annakoodai = v),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Section 5: Vehicle Photos ────────────────────────────
              _SectionCard(
                icon: Icons.camera_alt_rounded,
                title: 'Vehicle Photos',
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ImageUploadCard(
                          title: 'Front View',
                          required: true,
                          imagePath: frontImageController.text,
                          onImagePicked: (f) => setState(
                              () => frontImageController.text = f.path),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ImageUploadCard(
                          title: 'Back View',
                          required: true,
                          imagePath: backImageController.text,
                          onImagePicked: (f) => setState(
                              () => backImageController.text = f.path),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ImageUploadCard(
                          title: 'Odometer',
                          required: true,
                          imagePath: odoMeterImageController.text,
                          onImagePicked: (f) => setState(() =>
                              odoMeterImageController.text = f.path),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ImageUploadCard(
                          title: 'Coolant Oil',
                          required: true,
                          imagePath: leftImageController.text,
                          onImagePicked: (f) => setState(
                              () => leftImageController.text = f.path),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ImageUploadCard(
                          title: 'Engine Oil',
                          required: true,
                          imagePath: rightImageController.text,
                          onImagePicked: (f) => setState(
                              () => rightImageController.text = f.path),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ImageUploadCard(
                          title: 'Complaint',
                          required: false,
                          imagePath:
                              vehicleComplaintController!.text,
                          onImagePicked: (f) => setState(() =>
                              vehicleComplaintController!.text =
                                  f.path),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Section 6: Remarks ───────────────────────────────────
              _SectionCard(
                icon: Icons.comment_rounded,
                title: 'Remarks',
                children: [
                  TextAreaField(
                    controller: complaintDetailsController,
                    hintText: 'Optional remarks or complaint details…',
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
                    onPressed: startShift,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Start Shift',
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
            child: Divider(
                height: 20, color: Colors.white.withAlpha(20)),
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

// ── Equipment toggle chip ─────────────────────────────────────────────────────

class _EquipChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final void Function(bool) onChanged;

  const _EquipChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? primary.withAlpha(28) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? primary.withAlpha(160)
                : Colors.grey.withAlpha(80),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: selected ? primary : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? primary : Colors.grey,
                fontWeight: selected
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 5),
              Icon(Icons.check_circle_rounded,
                  size: 13, color: primary),
            ],
          ],
        ),
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

// ── Image preview (handles file not found gracefully) ─────────────────────────

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
