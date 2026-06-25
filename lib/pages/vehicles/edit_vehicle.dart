import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/buttons.dart';
import 'package:ourlandnew/components/input_fields.dart';
import 'package:ourlandnew/components/label.dart';
import "package:ourlandnew/config.dart";
import 'package:ourlandnew/pages/login.dart';

class EditVehicle extends StatefulWidget {
  final int vehicleId;
  final bool vehicleViewRedirect;
  const EditVehicle({
    super.key,
    required this.vehicleId,
    this.vehicleViewRedirect = false,
  });

  @override
  State<EditVehicle> createState() => _EditVehicleState();
}

class _EditVehicleState extends State<EditVehicle> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  TextEditingController vehicleNumberController = TextEditingController();
  TextEditingController currentKMController = TextEditingController();
  TextEditingController loadEstimationController = TextEditingController();
  String? vehicleType;
  String? possession;
  bool? isActive = true;
  bool? isSpare = false;
  bool? isUnderMaintenance = false;
  TextEditingController remarkController = TextEditingController();
  int? supervisor;
  int? zone;
  int? workshop;
  List staffs = [];
  List zones = [];
  List workshops = [];
  Map vehicle = {};

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
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

  Future<http.Response> editCurrentVehicle(String body) async {
    var uri = Uri.parse("$baseUrl/drf-edit-vehicle/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    var response = await http.post(uri, headers: headers, body: body);
    return response;
  }

  void editVehicle() async {
    setState(() {
      isLoading = true;
    });
    String? vehicleNumber = vehicleNumberController.text;
    String? currentKM = currentKMController.text;
    String? loadEstimation = loadEstimationController.text;

    var body = {
      "vehicle_id": widget.vehicleId,
      "vehicle_number": vehicleNumber.toString(),
      "vehicle_type": vehicleType.toString(),
      "possession": possession.toString(),
      "current_km": double.parse(currentKM),
      "load_estimation": double.parse(loadEstimation),
      "remark": remarkController.text.toString(),
    };

    if (supervisor != null) {
      (body['supervisor'] as List).add(supervisor);
    }

    if (vehicleNumber.isEmpty ||
        currentKM.isEmpty ||
        loadEstimation.isEmpty ||
        vehicleType!.isEmpty ||
        possession!.isEmpty) {
      errorMsg("Required * fields cannot be null");
    } else {
      var response = await editCurrentVehicle(jsonEncode(body));
      if (response.statusCode == 200) {
        successMsg('Vehicle Edited & Saved Successfully');
        Navigator.pop(context);
        Navigator.pushNamed(context, '/vehicles_list');
      } else {
        print(response.body);
        errorMsg("Unable to create Vehicle");
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> getDropDownValues() async {
    setState(() {
      staffs = [];
      zones = [];
      workshops = [];
    });
    var staffUri = Uri.parse("$baseUrl/drf-staff-list/");
    var zoneUri = Uri.parse("$baseUrl/test/zone/");
    var workshopUri = Uri.parse("$baseUrl/test/workshop/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    // STAFFS
    try {
      var staffResponse = await http.post(
        staffUri,
        headers: headers,
        body: jsonEncode({'filter': 'active'}),
      );
      if (staffResponse.statusCode == 200) {
        setState(() {
          staffs = jsonDecode(staffResponse.body);
        });
      }
    } catch (e) {
      print('Exception: $e');
    }

    // ZONES
    try {
      var zoneResponse = await http.get(zoneUri, headers: headers);
      if (zoneResponse.statusCode == 200) {
        setState(() {
          zones = jsonDecode(zoneResponse.body);
        });
      }
    } catch (e) {
      print('Exception: $e');
    }

    // WORKSHOP
    try {
      var workshopResponse = await http.get(workshopUri, headers: headers);
      if (workshopResponse.statusCode == 200) {
        setState(() {
          workshops = jsonDecode(workshopResponse.body);
        });
      }
    } catch (e) {
      print('Exception: $e');
    }
  }

  void getVehicle(int id) async {
    setState(() {
      isLoading = true;
    });
    var uri = Uri.parse("$baseUrl/drf-vehicle-detail/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    var body = jsonEncode({"vehicle_id": id});
    var response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200) {
      setState(() {
        vehicle = jsonDecode(response.body);
        vehicleNumberController.text = vehicle['vehicle_number'].toString();
        vehicleType = vehicle['vehicle_type'].toString();
        possession = vehicle['possession'].toString();
        currentKMController.text = vehicle['current_km'].toString();
        isActive = vehicle['is_active'];
        isSpare = vehicle['is_spare'];
        isUnderMaintenance = vehicle['is_under_maintenance'];
        loadEstimationController.text = vehicle['load_estimation'].toString();
        remarkController.text = vehicle['remark'].toString();
      });
    } else {
      errorMsg("Unable to find Vehicle");
      Navigator.pop(context);
      Navigator.pushNamed(context, "/vehicles_list");
    }

    setState(() {
      isLoading = false;
    });
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
    getVehicle(widget.vehicleId);
    setState(() {
      isStarting = false;
    });
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
                      title: const Text("Edit Vehicle Page"),
                    ),
                    body: Card(
                      margin: const EdgeInsets.all(15),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 10,
                        ),
                        children: [
                          // VEHICLE NUMBER
                          const LabelText(text: "Vehicle Number*"),
                          const SizedBox(height: 5),
                          BasicInputField(
                            enabled: false,
                            controller: vehicleNumberController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          // VEHICLE TYPE
                          const LabelText(text: "Vehicle Type*"),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            value: vehicleType,
                            items: [
                              ['Push Cart', 'Push Cart'],
                              ['Tricycle', 'Tricycle'],
                              ['BOV', 'Battery Operated Vehicle (BOV)'],
                              ['LCV', 'Light Commercial Vehicle (LCV)'],
                              ['HCV', 'High Commercial Vehicle (HCV)'],
                              ['Compactor', 'Compactor'],
                              ['Hook Loader', 'Hook Loader'],
                              ['Dumper Placer', 'Dumper Placer'],
                              ['Tipper', 'Tipper'],
                              ['SSSM', 'Small Street Sweeping Machine (SSSM)'],
                              ['LSSM', 'Large Street Sweeping Machine (LSSM)'],
                              ['EMV', 'Earth Moving Vehicle (EMV)'],
                              ['Tractor', 'Tractor'],
                              ['Others', 'Others'],
                              ['nan', 'Others'],
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
                                vehicleType = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),

                          // POSSESSION
                          const LabelText(text: "Possession*"),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            value: possession,
                            items: [
                              ['OL', 'OURLAND'],
                              ['GOVT', 'GOVERNMENT'],
                              ['RENT', 'PRIVATE'],
                              ['nan', 'OURLAND'],
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
                                possession = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),

                          // CURRENT KM
                          const LabelText(text: "Current KM*"),
                          const SizedBox(height: 5),
                          NumberField(
                            controller: currentKMController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          // CURRENT KM
                          const LabelText(text: "Load estimation*"),
                          const SizedBox(height: 5),
                          NumberField(
                            controller: loadEstimationController,
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
                                  text: "Submit", onPressed: editVehicle)
                        ],
                      ),
                    ),
                  ),
                ),
              );
  }
}
