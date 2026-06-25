import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/buttons.dart';
import 'package:ourlandnew/components/input_fields.dart';
import 'package:ourlandnew/components/label.dart';
import "package:ourlandnew/config.dart";
import 'package:ourlandnew/pages/login.dart';

class EditFuelLog extends StatefulWidget {
  final Map fuelLog;
  const EditFuelLog({super.key, required this.fuelLog});

  @override
  State<EditFuelLog> createState() => _EditFuelLogState();
}

class _EditFuelLogState extends State<EditFuelLog> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List vehicles = [];
  List fuelStations = [];
  TextEditingController odoReadingController = TextEditingController();
  TextEditingController fuelQuantityController = TextEditingController();
  TextEditingController fuelUnitCostController = TextEditingController();
  TextEditingController remarkController = TextEditingController();
  int? vehicle;
  int? fuelStation;
  String? fuelType = "P";

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<http.Response> editFuelLogAPI(String body) async {
    var uri = Uri.parse("$baseUrl/drf-edit-fuel-log/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    var response = await http.post(uri, headers: headers, body: body);
    return response;
  }

  void editFuelLog() async {
    setState(() {
      isLoading = true;
    });
    String? odoReading = odoReadingController.text;
    String? fuelQuantity = fuelQuantityController.text;
    String? fuelUnitCost = fuelUnitCostController.text;
    String? remark = remarkController.text;

    if (vehicle == null ||
        fuelStation == null ||
        odoReading.isEmpty ||
        fuelQuantity.isEmpty ||
        fuelUnitCost.isEmpty) {
      errorMsg("Required * fields cannot be null");
    } else {
      var body = {
        "vehicle": vehicle,
        "fuel_station": fuelStation,
        "fuel_type": fuelType,
        "odo_reading": double.parse(odoReading),
        "fuel_quantity": double.parse(fuelQuantity),
        "fuel_unit_cost": double.parse(fuelUnitCost),
        "remark": remark
      };
      body['fuellog_id'] = widget.fuelLog['id'];
      try{
        var response = await editFuelLogAPI(jsonEncode(body));
        if (response.statusCode == 200 || response.statusCode == 201) {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/fuel_log_list');
        } else {

          // Error case - handle non-200/201 responses
          String errorMessage = 'Failed to edit fuel log';

          try {
            // Try to parse error response
            final errorResponse = jsonDecode(response.body);

            // Check if error response contains a message
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
            // If response is not valid JSON, use status text or default message
            errorMessage = 'Error ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
          }

          // Show error message in snackbar
          errorMsg(errorMessage);

          // Optional: Log the full error for debugging
          print('Error creating fuel log: $errorMessage');
        }
      }
      catch(e){
        errorMsg('Network error: ${e.toString()}');
        print('Exception in addFuelLog: $e');
      }
      finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> getDropDownValues() async {
    setState(() {
      vehicles = [];
      odoReadingController.text = widget.fuelLog['odo_reading'].toString();
      fuelQuantityController.text = widget.fuelLog['fuel_quantity'].toString();
      fuelUnitCostController.text = widget.fuelLog['fuel_unit_cost'].toString();
      remarkController.text = widget.fuelLog['remark'].toString();
      fuelType = widget.fuelLog['fuel_type'].toString();
      vehicle = widget.fuelLog['vehicle'];
    });
    var vehicleUri = Uri.parse("$baseUrl/drf-vehicles/");
    var fuelStationUri = Uri.parse("$baseUrl/drf-fuel-station-list/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    Map body = {'is_active': true};

    // VEHICLES
    try {
      var vehicleResponse = await http.post(
        vehicleUri,
        headers: headers,
        body: jsonEncode(body),
      );
      if (vehicleResponse.statusCode == 200) {
        setState(() {
          vehicles = jsonDecode(vehicleResponse.body);
        });
      }
    } catch (e) {
      print('Exception: $e');
    }

    // FUEL STATION
    try {
      var fuelStationResponse = await http.get(
        fuelStationUri,
        headers: headers,
      );
      if (fuelStationResponse.statusCode == 200) {
        setState(() {
          fuelStations = jsonDecode(fuelStationResponse.body);
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
                        DropdownButtonFormField<String>(
                          value: vehicle.toString(),
                          items: vehicles
                              .map<DropdownMenuItem<String>>((dynamic value) {
                            return DropdownMenuItem<String>(
                              value: value['id'].toString(),
                              child: Text(value['vehicle_number'].toString()),
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
                              vehicle = int.parse(value.toString());
                            });
                          },
                        ),
                        const SizedBox(height: 10),

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
                          ].map<DropdownMenuItem<String>>((List<String> value) {
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
                                text: "Submit", onPressed: editFuelLog)
                      ],
                    ),
                  ),
                )),
              );
  }
}
