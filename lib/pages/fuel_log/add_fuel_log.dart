import "dart:convert";
import "dart:io";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:ourlandnew/components/buttons.dart";
import "package:ourlandnew/components/input_fields.dart";
import "package:ourlandnew/components/label.dart";
import "package:ourlandnew/config.dart";
import 'package:http/http.dart' as http;
import "package:ourlandnew/pages/login.dart";
import 'package:dropdown_search/dropdown_search.dart';

import "../../components/image_picker.dart";

class AddFuelLog extends StatefulWidget {
  const AddFuelLog({super.key});

  @override
  State<AddFuelLog> createState() => _AddFuelLogState();
}

class _AddFuelLogState extends State<AddFuelLog> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  bool isLoadingLastFuel = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List vehicles = [];
  List fuelStations = [];
  Map vehicleAndFuelStations = {};

  // Controllers
  TextEditingController odoReadingController = TextEditingController();
  TextEditingController fuelQuantityController = TextEditingController();
  TextEditingController fuelUnitCostController = TextEditingController();
  TextEditingController remarkController = TextEditingController();
  TextEditingController beforeImageController = TextEditingController();
  TextEditingController indentImageController = TextEditingController();

  // Read-only controllers for last fuel details
  TextEditingController lastOdoReadingController = TextEditingController();
  TextEditingController lastFuelDateController = TextEditingController();
  TextEditingController lastFuelQuantityController = TextEditingController();
  TextEditingController lastMileageController = TextEditingController();

  int? vehicle;
  int? fuelStation;
  String? fuelType = "P";

  Map<String, dynamic> lastFuelDetails = {};

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> getLastFuelingDetails(int vehicleId) async {
    setState(() {
      isLoadingLastFuel = true;
    });

    try {
      var uri = Uri.parse(
          "$baseUrl/drf_get_last_fueling_detail/?vehicle_id=$vehicleId");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      var headers = {
        'Content-Type': 'application/json',
        'authorization': auth
      };

      var response = await http.get(uri, headers: headers);
      print('Last Fuel Details Response: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          lastFuelDetails = jsonDecode(response.body);
          lastOdoReadingController.text =
              lastFuelDetails['last_odo_reading']?.toString() ?? 'N/A';
          lastFuelDateController.text =
              lastFuelDetails['last_fuel_date'] ?? 'N/A';
          lastFuelQuantityController.text =
              lastFuelDetails['last_fuel_quantity']?.toString() ?? 'N/A';
          lastMileageController.text =
              lastFuelDetails['mileage']?.toString() ?? 'N/A';
        });
      } else {
        setState(() {
          lastFuelDetails = {};
          lastOdoReadingController.text = 'N/A';
          lastFuelDateController.text = 'N/A';
          lastFuelQuantityController.text = 'N/A';
          lastMileageController.text = 'N/A';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Could not fetch last fueling details'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error fetching last fuel details: $e');
      setState(() {
        lastFuelDetails = {};
        lastOdoReadingController.text = 'N/A';
        lastFuelDateController.text = 'N/A';
        lastFuelQuantityController.text = 'N/A';
        lastMileageController.text = 'N/A';
      });
    } finally {
      setState(() {
        isLoadingLastFuel = false;
      });
    }
  }

  Future<http.Response> createFuelLogMultipart(
      Map<String, dynamic> data,
      Map<String, dynamic> images,
      ) async {
    try {
      var uri = Uri.parse("$baseUrl/drf-add-fuel-log/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      var request = http.MultipartRequest('POST', uri)
        ..headers['authorization'] = auth;

      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      for (var entry in images.entries) {
        if (entry.value != null && entry.value.toString().isNotEmpty) {
          print("Adding file: ${entry.key} -> ${entry.value}");
          request.files.add(
            await http.MultipartFile.fromPath(entry.key, entry.value),
          );
        }
      }

      print("=========== REQUEST DEBUG ===========");
      print("URL: $uri");
      print("Fields: ${request.fields}");
      for (var file in request.files) {
        print("  File: ${file.field} -> ${file.filename} (${file.length} bytes)");
      }
      print("======================================");

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      return response;
    } catch (e) {
      print("ERROR: $e");
      errorMsg(e.toString());
      return http.Response("Error", 500);
    }
  }

  void addFuelLog() async {
    setState(() {
      isLoading = true;
    });

    String odoReading = odoReadingController.text;
    String fuelQuantity = fuelQuantityController.text;
    String fuelUnitCost = fuelUnitCostController.text;
    String remark = remarkController.text;

    if (vehicle == null ||
        fuelStation == null ||
        odoReading.isEmpty ||
        fuelQuantity.isEmpty ||
        fuelUnitCost.isEmpty ||
        beforeImageController.text.isEmpty) {
      errorMsg("Required * fields cannot be empty");
      setState(() {
        isLoading = false;
      });
    } else {
      final Map<String, dynamic> data = {
        "vehicle": vehicle,
        "fuel_station": fuelStation,
        "fuel_type": fuelType,
        "odo_reading": odoReading,
        "fuel_quantity": fuelQuantity,
        "fuel_unit_cost": fuelUnitCost,
        "remark": remark,
      };

      final Map<String, dynamic> images = {
        "before_image": beforeImageController.text,
        "indent_image": indentImageController.text,
      };

      try {
        var response = await createFuelLogMultipart(data, images);

        if (response.statusCode == 200 || response.statusCode == 201) {
          successMsg('Fuel Log created successfully');
          Navigator.pop(context);
          Navigator.pushNamed(context, '/fuel_log_list');
        } else {
          String errorMessage = 'Failed to create fuel log';
          try {
            final errorResponse = jsonDecode(response.body);
            if (errorResponse is Map) {
              if (errorResponse.containsKey('error')) {
                errorMessage = errorResponse['error'].toString();
              } else if (errorResponse.containsKey('message')) {
                errorMessage = errorResponse['message'].toString();
              } else if (errorResponse.containsKey('detail')) {
                errorMessage = errorResponse['detail'].toString();
              }
            } else if (errorResponse is String) {
              errorMessage = errorResponse;
            }
          } catch (e) {
            errorMessage =
            'Error ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
          }

          errorMsg(errorMessage);
        }
      } catch (e) {
        errorMsg('Network error: ${e.toString()}');
        print('Exception in addFuelLog: $e');
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> getDropDownValues() async {
    setState(() {
      vehicles = [];
      odoReadingController.text = "0.0";
      fuelQuantityController.text = "1";
      fuelUnitCostController.text = "92.5";
    });

    var vehicleFuelUri = Uri.parse("$baseUrl/drf-add-fuel-log/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var fuelStationResponse = await http.get(vehicleFuelUri, headers: headers);
      print('fuelStationResponse.body');
      print(fuelStationResponse.body);

      if (fuelStationResponse.statusCode == 200) {
        setState(() {
          vehicleAndFuelStations = jsonDecode(fuelStationResponse.body);
          vehicles = vehicleAndFuelStations['vehicle_list'];
          fuelStations = vehicleAndFuelStations['fuelstation_list'];
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
    await prefs.setString("menu", "vehicles");
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
            title: const Text("Add Fuel Log"),
          ),
          body: Card(
            margin: const EdgeInsets.all(15),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 10,
              ),
              children: [
                // VEHICLE
                const LabelText(text: "Vehicle*"),
                const SizedBox(height: 5),

                // ── v7 DropdownSearch ──────────────────────────────
                DropdownSearch<String>(
                  // v7: decoratorProps replaces dropdownDecoratorProps
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10),
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    // v7: itemBuilder has 4 params (added isHighlighted)
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
                  // v7: items is now a function, not a plain List
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
                  // v7: onChanged renamed to onSelected
                  onSelected: (String? value) {
                    if (value == null) return;
                    setState(() {
                      vehicle = int.parse(value);
                    });
                    getLastFuelingDetails(vehicle!);
                  },
                  selectedItem: vehicle?.toString(),
                  dropdownBuilder: (context, selectedItem) {
                    return Text(
                      vehicles
                          .firstWhere(
                            (dynamic item) =>
                        item['id'].toString() == selectedItem,
                        orElse: () =>
                        {'vehicle_number': 'Select a vehicle'},
                      )['vehicle_number']
                          .toString(),
                    );
                  },
                ),
                // ──────────────────────────────────────────────────

                const SizedBox(height: 10),

                // LAST FUEL DETAILS SECTION
                if (vehicle != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history,
                                size: 20,
                                color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Last Fueling Details',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            if (isLoadingLastFuel) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text('Last ODO Reading',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey)),
                                  TextFormField(
                                    controller:
                                    lastOdoReadingController,
                                    enabled: false,
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(
                                              8)),
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text('Last Fuel Date',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey)),
                                  TextFormField(
                                    controller: lastFuelDateController,
                                    enabled: false,
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(
                                              8)),
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Last Fuel Qty',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey)),
                                  TextFormField(
                                    controller: lastFuelQuantityController,
                                    enabled: false,
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(8)),
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Mileage',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey)),
                                  TextFormField(
                                    controller: lastMileageController,
                                    enabled: false,
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(8)),
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // FUEL STATION
                const LabelText(text: "Fuel Station*"),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  items: fuelStations
                      .map<DropdownMenuItem<String>>((dynamic value) {
                    return DropdownMenuItem<String>(
                      value: value['id'].toString(),
                      child: Text(value['name'].toString()),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (String? value) {
                    setState(() {
                      fuelStation = int.parse(value.toString());
                    });
                  },
                ),
                const SizedBox(height: 10),

                // FUEL TYPE
                const LabelText(text: "Fuel Type*"),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  value: fuelType,
                  items: [
                    ['P', 'Petrol'],
                    ['D', 'Diesel'],
                    ['G', 'Gas'],
                  ].map<DropdownMenuItem<String>>(
                          (List<String> value) {
                        return DropdownMenuItem<String>(
                          value: value[0],
                          child: Text(value[1]),
                        );
                      }).toList(),
                  decoration: InputDecoration(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (String? value) {
                    setState(() {
                      fuelType = value;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // ODO READING
                const LabelText(text: "Odo Reading*"),
                const SizedBox(height: 5),
                NumberField(
                  controller: odoReadingController,
                  padding: 10,
                ),
                const SizedBox(height: 10),

                // FUEL QUANTITY
                const LabelText(text: "Fuel Quantity*"),
                const SizedBox(height: 5),
                NumberField(
                  controller: fuelQuantityController,
                  padding: 10,
                ),
                const SizedBox(height: 10),

                // FUEL UNIT COST
                const LabelText(text: "Fuel Unit Cost*"),
                const SizedBox(height: 5),
                NumberField(
                  controller: fuelUnitCostController,
                  padding: 10,
                ),
                const SizedBox(height: 10),

                // BEFORE IMAGE
                const LabelText(text: "Before Image*"),
                const SizedBox(height: 5),
                _buildImagePreview(
                    beforeImageController.text, 'Before Image'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Spacer(),
                    CameraImagePicker(
                      text: 'Upload Before Image',
                      onImagePicked: (file) {
                        setState(() {
                          beforeImageController.text = file.path;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // INDENT IMAGE
                const LabelText(text: "Indent Image"),
                const SizedBox(height: 5),
                _buildImagePreview(
                    indentImageController.text, 'Indent Image'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Spacer(),
                    CameraImagePicker(
                      text: 'Upload Indent Image',
                      onImagePicked: (file) {
                        setState(() {
                          indentImageController.text = file.path;
                        });
                      },
                    ),
                  ],
                ),

                // REMARK
                const LabelText(text: "Remark"),
                const SizedBox(height: 5),
                TextAreaField(
                  controller: remarkController,
                  padding: 10,
                ),

                const SizedBox(height: 20),
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : PrimaryButton(
                    text: "Submit", onPressed: addFuelLog),
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
            child: Image.file(imageFile, fit: BoxFit.cover),
          ),
        );
      } else {
        return _buildErrorWidget('Image file not found');
      }
    } catch (e) {
      return _buildErrorWidget('Error loading image');
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
        child: Text(message, style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}