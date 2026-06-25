import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/buttons.dart';
import 'package:ourlandnew/components/input_fields.dart';
import 'package:ourlandnew/components/label.dart';
import "package:ourlandnew/config.dart";
import 'package:ourlandnew/pages/login.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class VehicleType {
  final String value;
  final String lable;

  VehicleType(this.value, this.lable);
}

class _AddVehiclePageState extends State<AddVehiclePage> {
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

  Future<http.Response> createVehicle(String body) async {
    var uri = Uri.parse("$baseUrl/drf-add-vehicle/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    var response = await http.post(uri, headers: headers, body: body);
    return response;
  }

  void addVehicle() async {
    setState(() {
      isLoading = true;
    });
    String? vehicleNumber = vehicleNumberController.text;
    String? currentKM = currentKMController.text;
    String? loadEstimation = loadEstimationController.text;

    var body = {
      "vehicle_number": vehicleNumber.toString(),
      "vehicle_type": vehicleType.toString(),
      "possession": possession.toString(),
      "current_km": double.parse(currentKM),
      "is_active": isActive,
      "is_spare": isSpare,
      "is_under_maintenance": isUnderMaintenance,
      "load_estimation": double.parse(loadEstimation),
      "remark": remarkController.text.toString(),
      "zone": zone,
      "workshop": workshop,
      "supervisor": []
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
      var response = await createVehicle(jsonEncode(body));
      if (response.statusCode == 201) {
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
                      title: const Text("Add Vehicle Page"),
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
                            controller: vehicleNumberController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          // VEHICLE TYPE
                          const LabelText(text: "Vehicle Type*"),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
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
                            items: [
                              ['OL', 'OURLAND'],
                              ['GOVT', 'GOVERNMENT'],
                              ['RENT', 'PRIVATE'],
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

                          // IS ACTIVE
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: isActive,
                                activeColor:
                                    Theme.of(context).colorScheme.primary,
                                onChanged: (val) {
                                  setState(() {
                                    isActive = val;
                                  });
                                },
                              ),
                              const LabelText(text: "Is Active"),
                            ],
                          ),

                          // IS SPARE
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: isSpare,
                                activeColor:
                                    Theme.of(context).colorScheme.primary,
                                onChanged: (val) {
                                  setState(() {
                                    isSpare = val;
                                  });
                                },
                              ),
                              const LabelText(text: "Is Spare"),
                            ],
                          ),

                          // IS UNDER MAINTENANCE
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: isUnderMaintenance,
                                activeColor:
                                    Theme.of(context).colorScheme.primary,
                                onChanged: (val) {
                                  setState(() {
                                    isUnderMaintenance = val;
                                  });
                                },
                              ),
                              const LabelText(text: "Is Under Maintenance"),
                            ],
                          ),

                          // CURRENT KM
                          const LabelText(text: "Load estimation*"),
                          const SizedBox(height: 5),
                          NumberField(
                            controller: loadEstimationController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          // SUPERVISOR
                          const LabelText(text: "Supervisor"),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            items: staffs
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
                                supervisor = int.parse(value.toString());
                              });
                            },
                          ),
                          const SizedBox(height: 10),

                          // ZONES
                          const LabelText(text: "Zone"),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            items: zones
                                .map<DropdownMenuItem<String>>((dynamic value) {
                              return DropdownMenuItem<String>(
                                value: value['id'].toString(),
                                child: Text(value['zone_code'].toString()),
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
                                zone = int.parse(value.toString());
                              });
                            },
                          ),
                          const SizedBox(height: 10),

                          // WORKSHOP
                          const LabelText(text: "Workshop"),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            items: workshops
                                .map<DropdownMenuItem<String>>((dynamic value) {
                              return DropdownMenuItem<String>(
                                value: value['id'].toString(),
                                child: Text(value['workshop_name'].toString()),
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
                                workshop = int.parse(value.toString());
                              });
                            },
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
                                  text: "Submit", onPressed: addVehicle)
                        ],
                      ),
                    ),
                  ),
                ),
              );
  }
}
