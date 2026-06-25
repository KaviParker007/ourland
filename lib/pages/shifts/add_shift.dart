import 'dart:convert';
import 'dart:io';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/buttons.dart';
import 'package:ourlandnew/components/input_fields.dart';
import 'package:ourlandnew/components/label.dart';
import "package:ourlandnew/config.dart";
import 'package:ourlandnew/pages/login.dart';

import '../../components/image_picker.dart';

class AddShiftPage extends StatefulWidget {
  const AddShiftPage({super.key});

  @override
  State<AddShiftPage> createState() => _AddShiftPageState();
}

class _AddShiftPageState extends State<AddShiftPage> {
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
  TextEditingController actingDriverLicenseController = TextEditingController();

  List<Map<String, dynamic>> regularDrivers = [];
  List<Map<String, dynamic>> spareDrivers = [];

  bool? audioSystem = false;
  bool? barrel = false;
  bool? rack = false;
  bool? broom = false;
  bool? annakoodai = false;
  var shiftData;
  TextEditingController frontImageController = TextEditingController();
  TextEditingController rightImageController = TextEditingController();
  TextEditingController backImageController = TextEditingController();
  TextEditingController leftImageController = TextEditingController();
  TextEditingController odoMeterImageController = TextEditingController();
  TextEditingController? vehicleComplaintController = TextEditingController();
  TextEditingController complaintDetailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  addShift(Map<String, dynamic> data, Map<String, dynamic> images) async {
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
    setState(() {
      isLoading = true;
    });

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
        Navigator.pop(context);
        Navigator.pushNamed(context, '/shift_list');
      } else {
        print(response.body);
        errorMsg(response.body);
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> getDropDownValues() async {
    setState(() {
      vehicles = [];
      routes = [];
      outKMController.text = "0";
    });

    var startShiftUri = Uri.parse("$baseUrl/drf-start-shift-v3/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var startShiftResponse =
      await http.get(startShiftUri, headers: headers);
      if (startShiftResponse.statusCode == 200) {
        shiftData = jsonDecode(startShiftResponse.body);
        print('shiftData___');
        print(shiftData);
        setState(() {
          vehicles = shiftData['vehicles'];
          var routesList = List<Map<String, dynamic>>.from(
              shiftData['routes'] ?? []);
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
    setState(() {
      isStarting = true;
    });
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
    setState(() {
      isStarting = false;
    });
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

  @override
  Widget build(BuildContext context) {
    return !isLoggedIn
        ? const LoginPage()
        : isStarting
        ? const Center(child: CircularProgressIndicator())
        : GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text("Start Shift"),
          ),
          body: Card(
            margin: const EdgeInsets.all(15),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 10,
              ),
              children: [
                // SHIFT NAME
                const LabelText(text: "Shift Name*"),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  value: shiftName,
                  items: [
                    ['I', 'I'],
                    ['II', 'II'],
                    ['III', 'III'],
                    ['Others', 'Others']
                  ].map<DropdownMenuItem<String>>(
                          (List<String> value) {
                        return DropdownMenuItem<String>(
                          value: value[0],
                          child: Text(value[1]),
                        );
                      }).toList(),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (String? value) {
                    setState(() {
                      shiftName = value;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // VEHICLE
                const LabelText(text: "Vehicle*"),
                const SizedBox(height: 5),

                // ── Vehicle DropdownSearch v7 ───────────────────
                DropdownSearch<String>(
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: 'Search Vehicles',
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    // v7: 4th param isHighlighted added
                    itemBuilder:
                        (context, item, isSelected, isHighlighted) {
                      return ListTile(
                        title: Text(
                          vehicles
                              .firstWhere(
                                (dynamic element) =>
                            element['id'].toString() == item,
                            orElse: () =>
                            {'vehicle_number': 'Unknown'},
                          )['vehicle_number']
                              .toString(),
                        ),
                      );
                    },
                  ),
                  // v7: items is now a function
                  items: (filter, loadProps) => vehicles
                      .map<String>(
                          (dynamic value) => value['id'].toString())
                      .toList(),
                  itemAsString: (String item) {
                    return vehicles
                        .firstWhere(
                          (dynamic element) =>
                      element['id'].toString() == item,
                      orElse: () => {'vehicle_number': ''},
                    )['vehicle_number']
                        .toString();
                  },
                  // v7: onChanged → onSelected
                  onSelected: (String? value) {
                    if (value != null) {
                      var selectedVehicle = vehicles.firstWhere(
                              (v) => v['id'].toString() == value);
                      setState(() {
                        vehicle = int.parse(value);
                        double currentKm =
                        selectedVehicle['current_km'].toDouble();
                        outKMController.text =
                            currentKm.toStringAsFixed(0);
                      });
                    }
                  },
                  selectedItem: vehicle?.toString(),
                  dropdownBuilder: (context, selectedItem) {
                    return Text(
                      vehicles
                          .firstWhere(
                            (dynamic item) =>
                        item['id'].toString() == selectedItem,
                        orElse: () => {
                          'vehicle_number': 'Select a vehicle'
                        },
                      )['vehicle_number']
                          .toString(),
                    );
                  },
                ),
                // ───────────────────────────────────────────────

                const SizedBox(height: 10),

                // OUT KM
                const LabelText(text: "Out KM"),
                const SizedBox(height: 5),
                NumberField(
                  controller: outKMController,
                  padding: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp('[0-9]')),
                  ],
                ),
                const SizedBox(height: 10),

                // DRIVER TYPE
                const LabelText(text: "Driver Type*"),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  value: driverType,
                  items: ['Regular', 'Spare', 'Acting', 'Others']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (String? value) {
                    setState(() {
                      driverType = value;
                      driverId = null;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Conditional fields based on driver type
                if (driverType == 'Regular' ||
                    driverType == 'Spare')
                  Column(
                    children: [
                      const LabelText(text: "Driver ID*"),
                      const SizedBox(height: 5),

                      // ── Driver DropdownSearch v7 ──────────────
                      DropdownSearch<String>(
                        decoratorProps: DropDownDecoratorProps(
                          decoration: InputDecoration(
                            contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 10),
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              hintText: 'Search by Name or ID',
                              contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 10),
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          // v7: 4th param isHighlighted added
                          itemBuilder: (context, item, isSelected,
                              isHighlighted) {
                            final driversList =
                            driverType == 'Regular'
                                ? regularDrivers
                                : spareDrivers;
                            final driver = driversList.firstWhere(
                                  (driver) =>
                              driver['employee_id'].toString() ==
                                  item,
                              orElse: () => {
                                'employee_name': 'Unknown',
                                'employee_id': ''
                              },
                            );
                            return ListTile(
                              title: Text(driver['employee_name']),
                              subtitle: Text(
                                  'ID: ${driver['employee_id']}'),
                              selected: isSelected,
                            );
                          },
                        ),
                        // v7: items is now a function
                        items: (filter, loadProps) =>
                            (driverType == 'Regular'
                                ? regularDrivers
                                : spareDrivers)
                                .map<String>((driver) =>
                                driver['employee_id'].toString())
                                .toList(),
                        filterFn: (item, filter) {
                          final driversList = driverType == 'Regular'
                              ? regularDrivers
                              : spareDrivers;
                          final driver = driversList.firstWhere(
                                (driver) =>
                            driver['employee_id'].toString() ==
                                item,
                            orElse: () => {
                              'employee_name': '',
                              'employee_id': ''
                            },
                          );
                          return driver['employee_name']
                              .toLowerCase()
                              .contains(filter.toLowerCase()) ||
                              driver['employee_id']
                                  .toString()
                                  .toLowerCase()
                                  .contains(filter.toLowerCase());
                        },
                        compareFn: (item1, item2) {
                          final driversList =
                          driverType == 'Regular'
                              ? regularDrivers
                              : spareDrivers;
                          final driver1 = driversList.firstWhere(
                                (driver) =>
                            driver['employee_id'].toString() ==
                                item1,
                            orElse: () => {'employee_name': ''},
                          );
                          final driver2 = driversList.firstWhere(
                                (driver) =>
                            driver['employee_id'].toString() ==
                                item2,
                            orElse: () => {'employee_name': ''},
                          );
                          return driver1['employee_name']
                              .compareTo(driver2['employee_name']);
                        },
                        itemAsString: (String item) {
                          final driversList =
                          driverType == 'Regular'
                              ? regularDrivers
                              : spareDrivers;
                          final driver = driversList.firstWhere(
                                (driver) =>
                            driver['employee_id'].toString() ==
                                item,
                            orElse: () => {
                              'employee_name': '',
                              'employee_id': ''
                            },
                          );
                          return '${driver['employee_name']} (${driver['employee_id']})';
                        },
                        // v7: onChanged → onSelected
                        onSelected: (String? value) {
                          setState(() {
                            driverId = value;
                            print(driverId);
                          });
                        },
                        selectedItem: driverId,
                        dropdownBuilder: (context, selectedItem) {
                          if (selectedItem == null) {
                            return const Text('Select Driver');
                          }
                          final driversList =
                          driverType == 'Regular'
                              ? regularDrivers
                              : spareDrivers;
                          final driver = driversList.firstWhere(
                                (driver) =>
                            driver['employee_id'].toString() ==
                                selectedItem,
                            orElse: () => {
                              'employee_name': 'Select Driver',
                              'employee_id': ''
                            },
                          );
                          return Text(
                              '${driver['employee_name']} (${driver['employee_id']})');
                        },
                      ),
                      // ─────────────────────────────────────────

                      const SizedBox(height: 10),
                    ],
                  ),

                if (driverType == 'Acting')
                  Column(
                    children: [
                      const LabelText(text: "Driver Name*"),
                      const SizedBox(height: 5),
                      BasicInputField(
                        controller: driverNameController,
                        padding: 10,
                      ),
                      const SizedBox(height: 10),
                      const LabelText(
                          text: "Acting Driver License*"),
                      const SizedBox(height: 5),
                      BasicInputField(
                        controller: actingDriverLicenseController,
                        padding: 10,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),

                if (driverType == 'Others')
                  Column(
                    children: [
                      const LabelText(text: "Driver Name*"),
                      const SizedBox(height: 5),
                      BasicInputField(
                        controller: driverNameController,
                        padding: 10,
                      ),
                      const SizedBox(height: 10),
                      const LabelText(text: "Other Driver Remark"),
                      const SizedBox(height: 5),
                      TextAreaField(
                        controller: otherDriverRemarkController,
                        padding: 10,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),

                const LabelText(text: "Engine Oil Level"),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  value: engineOilLevel,
                  items: [
                    ['Not Checked', 'Not Checked'],
                    ['Normal', 'Normal'],
                    ['Low', 'Low'],
                    ['Very Low', 'Very Low']
                  ].map<DropdownMenuItem<String>>(
                          (List<String> value) {
                        return DropdownMenuItem<String>(
                          value: value[0],
                          child: Text(value[1]),
                        );
                      }).toList(),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (String? value) {
                    setState(() {
                      engineOilLevel = value;
                    });
                  },
                ),
                const SizedBox(height: 10),

                const LabelText(text: "Coolant Oil Level"),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  value: coolantOilLevel,
                  items: [
                    ['Not Checked', 'Not Checked'],
                    ['Normal', 'Normal'],
                    ['Low', 'Low'],
                    ['Very Low', 'Very Low']
                  ].map<DropdownMenuItem<String>>(
                          (List<String> value) {
                        return DropdownMenuItem<String>(
                          value: value[0],
                          child: Text(value[1]),
                        );
                      }).toList(),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (String? value) {
                    setState(() {
                      coolantOilLevel = value;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // AUDIO SYSTEM
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: audioSystem,
                      activeColor:
                      Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          audioSystem = val;
                        });
                      },
                    ),
                    const LabelText(text: "Audio System"),
                  ],
                ),

                // BARREL
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: barrel,
                      activeColor:
                      Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          barrel = val;
                        });
                      },
                    ),
                    const LabelText(text: "Barrel"),
                  ],
                ),

                // RACK
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: rack,
                      activeColor:
                      Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          rack = val;
                        });
                      },
                    ),
                    const LabelText(text: "Rack"),
                  ],
                ),

                // BROOM
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: broom,
                      activeColor:
                      Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          broom = val;
                        });
                      },
                    ),
                    const LabelText(text: "Broom"),
                  ],
                ),

                // ANNAKOODAI
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: annakoodai,
                      activeColor:
                      Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          annakoodai = val;
                        });
                      },
                    ),
                    const LabelText(text: "Annakoodai"),
                  ],
                ),

                // START FRONT
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start Front*',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge),
                        const SizedBox(height: 10),
                        _buildImagePreview(
                            frontImageController.text,
                            'Front Image'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            CameraImagePicker(
                              onImagePicked: (value) {
                                setState(() {
                                  frontImageController.text =
                                      value.path;
                                });
                              },
                              text: 'Upload Front Image',
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                // START BACK
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start Back*',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge),
                        const SizedBox(height: 10),
                        _buildImagePreview(
                            backImageController.text, 'Back Image'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            CameraImagePicker(
                              onImagePicked: (value) {
                                setState(() {
                                  backImageController.text =
                                      value.path;
                                });
                              },
                              text: 'Upload Back Image',
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                // START ODOMETER
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start Odo-meter*',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge),
                        const SizedBox(height: 10),
                        _buildImagePreview(
                            odoMeterImageController.text,
                            'Odo-meter Image'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            CameraImagePicker(
                              onImagePicked: (value) {
                                setState(() {
                                  odoMeterImageController.text =
                                      value.path;
                                });
                              },
                              text: 'Upload Odo-meter Image',
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                // START LEFT (Coolant oil)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Coolant oil*',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge),
                        const SizedBox(height: 10),
                        _buildImagePreview(leftImageController.text,
                            'Coolant oil Image'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            CameraImagePicker(
                              onImagePicked: (value) {
                                setState(() {
                                  leftImageController.text =
                                      value.path;
                                });
                              },
                              text: 'Upload Coolant oil Image',
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                // START RIGHT (Engine oil)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Engine oil*',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge),
                        const SizedBox(height: 10),
                        _buildImagePreview(rightImageController.text,
                            'Engine oil Image'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            CameraImagePicker(
                              onImagePicked: (value) {
                                setState(() {
                                  rightImageController.text =
                                      value.path;
                                });
                              },
                              text: 'Upload Engine oil Image',
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                // VEHICLE COMPLAINT
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vehicle Complaint',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge),
                        const SizedBox(height: 10),
                        _buildImagePreview(
                            vehicleComplaintController!.text,
                            'Vehicle Complaint Image'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            CameraImagePicker(
                              onImagePicked: (value) {
                                setState(() {
                                  vehicleComplaintController!.text =
                                      value.path;
                                });
                              },
                              text: 'Upload Vehicle Complaint Image',
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                const LabelText(text: "Remark"),
                const SizedBox(height: 5),
                TextAreaField(
                  controller: complaintDetailsController,
                  padding: 10,
                ),
                const SizedBox(height: 10),
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : PrimaryButton(
                    text: "Submit", onPressed: startShift),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(String imagePath, String placeholderText) {
    if (imagePath.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '$placeholderText Not Uploaded',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    try {
      File imageFile = File(imagePath);
      if (imageFile.existsSync()) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              imageFile,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext context, Object error,
                  StackTrace? stackTrace) {
                return _buildErrorWidget('Failed to load image');
              },
            ),
          ),
        );
      } else {
        return _buildErrorWidget('Image file not found');
      }
    } catch (e) {
      return _buildErrorWidget('Error loading image: $e');
    }
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}