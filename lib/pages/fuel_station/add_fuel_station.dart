import "dart:convert";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:ourlandnew/components/buttons.dart";
import "package:ourlandnew/components/input_fields.dart";
import "package:ourlandnew/components/label.dart";
import "package:ourlandnew/config.dart";
import 'package:http/http.dart' as http;
import "package:ourlandnew/pages/login.dart";

class AddFuelStation extends StatefulWidget {
  const AddFuelStation({super.key});

  @override
  State<AddFuelStation> createState() => _AddFuelStationState();
}

class _AddFuelStationState extends State<AddFuelStation> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  String? coreZone = "TBM";
  TextEditingController nameController = TextEditingController();
  TextEditingController capacityController = TextEditingController();
  TextEditingController addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<http.Response> createFuelStation(String body) async {
    var uri = Uri.parse("$baseUrl/drf-add-fuel-station/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    var response = await http.post(uri, headers: headers, body: body);
    return response;
  }

  void addFuelStation() async {
    setState(() {
      isLoading = true;
    });

    String? name = nameController.text;
    String? capacity = capacityController.text;
    String? address = addressController.text;

    if (name.isEmpty) {
      errorMsg("Required * fields cannot be null");
    } else {
      var body = {
        "core_zone": coreZone.toString(),
        "name": name.toString(),
        "capacity": double.parse(capacity.toString()),
        "address": address.toString()
      };
      var response = await createFuelStation(jsonEncode(body));
      if (response.statusCode == 201) {
        Navigator.pop(context);
        Navigator.pushNamed(context, '/fuel_station_list');
      } else {
        print(response.body);
        errorMsg("Unable to create Fuel Station");
      }
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
        capacityController.text = "0.0";
      });
    }
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
                      title: const Text("Add Fuel Station"),
                    ),
                    body: Card(
                      margin: const EdgeInsets.all(15),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 10,
                        ),
                        children: [
                          // CORE ZONE
                          const LabelText(text: "Core Zone*"),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            value: coreZone,
                            items: [
                              ['TBM', 'Tambaram'],
                              ['MDU', 'Madurai']
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
                                coreZone = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),

                          // NAME
                          const LabelText(text: "Name*"),
                          const SizedBox(height: 5),
                          BasicInputField(
                            controller: nameController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          // CAPACITY
                          const LabelText(text: "Capacity*"),
                          const SizedBox(height: 5),
                          NumberField(
                            controller: capacityController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          // ADDRESS
                          const LabelText(text: "Capacity*"),
                          const SizedBox(height: 5),
                          TextAreaField(
                            controller: addressController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          const SizedBox(height: 20),
                          isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : PrimaryButton(
                                  text: "Submit", onPressed: addFuelStation)
                        ],
                      ),
                    ),
                  ),
                ),
              );
  }
}
