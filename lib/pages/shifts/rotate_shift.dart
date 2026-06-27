import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/buttons.dart';
import 'package:ourlandnew/components/input_fields.dart';
import 'package:ourlandnew/components/label.dart';
import "package:ourlandnew/config.dart";
import 'package:ourlandnew/pages/login.dart';

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
  List<int> selectedRouteIds = [];
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

  rotateShift(Map<String, dynamic> data) async {
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
    setState(() {
      isLoading = true;
    });

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

    if (binCountController.text.isEmpty ||
        wetWasteController.text.isEmpty ||
        recycleWasteController.text.isEmpty ||
        dryWasteController.text.isEmpty ||
        inertsController.text.isEmpty ||
        houseHoldHazardController.text.isEmpty ||
        greenGarbageController.text.isEmpty ||
        otherWasteController.text.isEmpty ||
        (destinationId == null || destinationId.toString().isEmpty)) {
      errorMsg("Required * fields cannot be Empty");
    } else {
     var response = await rotateShift(data);
      if (response.statusCode == 200) {
        successMsg('shift swap successfully');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/shift_dashboard');
        }
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
      var destinationResponse = await http.get(
        destinationUri,
        headers: headers,
      );
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
                      title: const Text("Rotate Shift"),
                    ),
                    body: Card(
                      margin: const EdgeInsets.all(15),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 10,
                        ),
                        children: [
                          // BIN COUNT
                          const LabelText(text: "Bin Count*"),
                          const SizedBox(height: 5),
                          NumberField(
                            controller: binCountController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          // WET WASTE
                          const LabelText(text: "Wet Waste*"),
                          const SizedBox(height: 5),
                          NumberField(
                            controller: wetWasteController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          // RECYCLABLE WASTE
                          const LabelText(text: "Recyclable Waste*"),
                          const SizedBox(height: 5),
                          NumberField(
                            controller: recycleWasteController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          // DRY WASTE
                          const LabelText(text: "Dry Waste*"),
                          const SizedBox(height: 5),
                          NumberField(
                            controller: dryWasteController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          // INERTS
                          const LabelText(text: "Inerts*"),
                          const SizedBox(height: 5),
                          NumberField(
                            controller: inertsController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          //HOUSEHOLD HAZARD
                          const LabelText(text: "Household Hazard*"),
                          const SizedBox(height: 5),
                          NumberField(
                            controller: houseHoldHazardController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          //GREEN GARBAGE'S
                          const LabelText(text: "Green Garbage's*"),
                          const SizedBox(height: 5),
                          NumberField(
                            controller: greenGarbageController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          //OTHER WASTE
                          const LabelText(text: "Other Waste*"),
                          const SizedBox(height: 5),
                          NumberField(
                            controller: otherWasteController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          // DESTINATION
                          const LabelText(text: "Destination*"),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            items: destination.map<DropdownMenuItem<String>>((dynamic value) {
                              return DropdownMenuItem<String>(
                                value: value['id'].toString(),
                                child: Text(value['name'].toString(), overflow: TextOverflow.ellipsis,),
                              );
                            }).toList(),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            isExpanded: true,
                            onChanged: (String? value) {
                              setState(() {
                                destinationId = int.parse(value.toString());
                              });
                            },
                          ),
                          const SizedBox(height: 10),

                          //TRIP RE-MARK
                          const LabelText(text: "Trip Remark"),
                          const SizedBox(height: 5),
                          BasicInputField(
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            controller: tripRemarkController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          const SizedBox(height: 10),
                          isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : PrimaryButton(text: "Submit", onPressed: swapShift)
                        ],
                      ),
                    ),
                  ),
                ),
              );
  }
}
