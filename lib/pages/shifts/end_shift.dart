import 'dart:convert';
import 'dart:io';
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
  TextEditingController shiftRemarkController = TextEditingController();
  TextEditingController inKmController = TextEditingController();
  TextEditingController imageController = TextEditingController();
  TextEditingController odoMeterImageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  endShift(Map<String, dynamic> data, Map<String, String> images) async {
    try {
      var uri = Uri.parse("$baseUrl/drf-end-shift-v2/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      var request = http.MultipartRequest('POST', uri)..headers['authorization'] = auth;

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
    setState(() {
      isLoading = true;
    });

    if (binCountController.text.isEmpty ||
        wetWasteController.text.isEmpty ||
        recycleWasteController.text.isEmpty ||
        dryWasteController.text.isEmpty ||
        inertsController.text.isEmpty ||
        houseHoldHazardController.text.isEmpty ||
        greenGarbageController.text.isEmpty ||
        otherWasteController.text.isEmpty ||
        (destinationId == null || destinationId.toString().isEmpty) ||
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
        successMsg('shift end successfully');
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
              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
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
                      title: const Text("End Shift"),
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
                                child: Text(
                                  value['name'].toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
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

                          //SHIFT RE-MARK
                          const LabelText(text: "Shift Remark"),
                          const SizedBox(height: 5),
                          BasicInputField(
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            controller: shiftRemarkController,
                            padding: 10,
                          ),
                          const SizedBox(height: 10),

                          //IN KM
                          const LabelText(text: "IN KM*"),
                          const SizedBox(height: 5),
                          NumberField(
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                            ],
                            controller: inKmController,
                            padding: 10,
                          ),

                          //END IMAGE
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Image*',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildImagePreview(imageController.text, 'End Image'),

                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Spacer(),
                                      CameraImagePicker(

                                        onImagePicked: (value) {
                                          setState(() {
                                            imageController.text = value.path;
                                          });
                                        },
                                        text: 'Upload Image',
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),

                          //END ODOMETER
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Odo-meter Image*',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildImagePreview(odoMeterImageController.text, 'Odo-meter Image'),

                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Spacer(),
                                      CameraImagePicker(

                                        onImagePicked: (value) {
                                          setState(() {
                                            odoMeterImageController.text = value.path;
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

                          const SizedBox(height: 10),
                          isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : PrimaryButton(text: "Submit", onPressed: startShift)
                        ],
                      ),
                    ),
                  ),
                ),
              );
  }
}
