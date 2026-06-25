import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/buttons.dart';
import 'package:ourlandnew/components/label.dart';
import "package:ourlandnew/config.dart";
import 'package:ourlandnew/pages/login.dart';
import '../../components/image_picker.dart';

class add_third_image extends StatefulWidget {
  final int secondImgId;
  const add_third_image({super.key, required this.secondImgId});

  @override
  State<add_third_image> createState() => _add_third_imageState();
}

class _add_third_imageState extends State<add_third_image> {
  TextEditingController attendance_third_page1 = TextEditingController();
  TextEditingController attendance_third_page2 = TextEditingController();
  TextEditingController attendance_third_page3 = TextEditingController();
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  int? selectedOpimId;
  String? username;
  String? password;
  String baseUrl = AppConfig.apiUrl;
  List<int> opimIds = []; // This should be populated with your zones data

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
    // Initialize with the passed secondImgId
    selectedOpimId = widget.secondImgId;
    // Simulate fetching Opim IDs - replace with your actual data fetching
    fetchOpimIds();
    // Fetch zones data here if not already available
    // fetchZones(); // Uncomment if you need to fetch zones
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

    setState(() {
      isStarting = false;
    });
  }

  void fetchOpimIds() async {
    // This is just a simulation - replace with your actual data fetching logic
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      // Add some dummy IDs including the secondImgId
      opimIds = [widget.secondImgId];
      // Ensure the selected ID exists in the list
      if (!opimIds.contains(widget.secondImgId)) {
        opimIds.add(widget.secondImgId);
      }
    });
  }
  // Your existing methods...
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


  void ThirdImgUpload() async {
    setState(() {
      isLoading = true;
    });


    if ((selectedOpimId == null || selectedOpimId.toString().isEmpty) ||
        (attendance_third_page1.text.isEmpty)) {
      errorMsg("Required * fields cannot be Empty");
    } else {

      final Map<String, dynamic> data = {
        "opim_id": selectedOpimId,
      };

      final Map<String, dynamic> images = {
        "attendance_third_page1": attendance_third_page1.text,
        "attendance_third_page2": attendance_third_page2.text,
        "attendance_third_page3": attendance_third_page3.text,

      };

      var response = await addThirdImg(data, images);
      var result = jsonDecode(response.body);
      if (response.statusCode == 200) {
        successMsg('Third Attendance created successfully');
        Navigator.pop(context);
        Navigator.pushNamed(context, '/operation_page');
      } else {
        String errorMessage = result['error'] ?? 'Something went wrong';
        errorMsg(errorMessage);
        print('Error: $errorMessage');
      }
    }

    setState(() {
      isLoading = false;
    });
  }


  addThirdImg(Map<String, dynamic> data, Map<String, dynamic> images) async {
    try {
      var uri = Uri.parse("$baseUrl/drf-opim3");
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


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text("Third Image"),
          ),
          body: Card(
            margin: const EdgeInsets.all(15),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 10,
              ),
              children: [
                // Zone Dropdown


                // Rest of your widgets...
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Third Page1*',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        _buildImagePreview(attendance_third_page1.text, 'Attendance Third Page 1 Image'),

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            CameraImagePicker(

                              onImagePicked: (value) {
                                setState(() {
                                  attendance_third_page1.text = value.path;
                                });
                              },
                              text: 'Upload Attendance Third Page 1',
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Third Page2',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        _buildImagePreview(attendance_third_page2.text, 'Attendance Third Page 2 Image'),

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            CameraImagePicker(

                              onImagePicked: (value) {
                                setState(() {
                                  attendance_third_page2.text = value.path;
                                });
                              },
                              text: 'Upload Attendance Third Page 2',
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Third Page3',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        _buildImagePreview(attendance_third_page3.text, 'Attendance Third Page 3 Image'),

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            CameraImagePicker(

                              onImagePicked: (value) {
                                setState(() {
                                  attendance_third_page3.text = value.path;
                                });
                              },
                              text: 'Upload Attendance Third Page 3',
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
                    : PrimaryButton(
                    text: "Submit", onPressed: ThirdImgUpload)
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
  // Dummy function to avoid errors - replace with your actual implementation
  void fetchWards(int value) {
    // Your ward fetching logic here
  }
}