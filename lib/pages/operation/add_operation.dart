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

class AddOperationPage extends StatefulWidget {
  const AddOperationPage({super.key});

  @override
  State<AddOperationPage> createState() => _AddOperationPageState();
}

class _AddOperationPageState extends State<AddOperationPage> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  bool isFetchingWards = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;

  List<dynamic> zones = [];
  List<dynamic> wards = [];
  int? selectedZoneId;
  int? selectedWardId;

  TextEditingController rollcallImageController = TextEditingController();
  TextEditingController attendanceFirstPage1 = TextEditingController();
  TextEditingController attendanceFirstPage2 = TextEditingController();
  TextEditingController attendanceFirstPage3 = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
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
      await fetchZones();
    }

    setState(() {
      isStarting = false;
    });
  }

  Future<void> fetchZones() async {
    try {
      var uri = Uri.parse("$baseUrl/drf-zone-list/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      var response = await http.get(uri, headers: {'authorization': auth});

      if (response.statusCode == 200) {
        print('response.statusCodkkkkkknke');
        print(response.statusCode);
        print(response.body);
        setState(() {
          zones = json.decode(response.body);
          if (zones.isNotEmpty||zones!=[]) {
            selectedZoneId = zones.first['id'];
            fetchWards(selectedZoneId!); // Fetch wards for the first zone by default
          }
        });
      } else {
        errorMsg("Failed to fetch zones: ${response.statusCode}");
      }
    } catch (e) {
      errorMsg("Failed to fetch zones: ${e.toString()}");
    }
  }

  Future<void> fetchWards(int zoneId) async {
    setState(() {
      isFetchingWards = true;
      wards = []; // Clear previous wards
      selectedWardId = null; // Reset selected ward
    });

    try {
      //var uri = Uri.parse("$baseUrl/drf-zonal-ward-list/");
      var uri = Uri.parse("$baseUrl/drf-zonalward-pending-list/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      var response = await http.post(
        uri,
        headers: {
          'authorization': auth,
          'Content-Type': 'application/json',
        },
        body: json.encode({'zone_id': zoneId}),
      );

      if (response.statusCode == 200) {
        setState(() {
          wards = json.decode(response.body);
          if (wards.isNotEmpty) {
            selectedWardId = wards.first['id'];
          }
        });
      } else {
        errorMsg("Failed to fetch wards: ${response.statusCode}");
      }
    } catch (e) {
      errorMsg("Failed to fetch wards: ${e.toString()}");
    } finally {
      setState(() {
        isFetchingWards = false;
      });
    }
  }

  void startShift() async {
    setState(() {
      isLoading = true;
    });

    if (selectedZoneId == null ||
        selectedWardId == null ||
        rollcallImageController.text.isEmpty ||
        attendanceFirstPage1.text.isEmpty) {
      errorMsg("Required * fields cannot be Empty");
    } else {
      final Map<String, dynamic> data = {
        "zone": selectedZoneId,
        "ward": selectedWardId,
      };

      final Map<String, dynamic> images = {
        "roll_call": rollcallImageController.text,
        "attendance_first_page1": attendanceFirstPage1.text,
        "attendance_first_page2": attendanceFirstPage2.text,
        "attendance_first_page3": attendanceFirstPage3.text,
      };

      var response = await addFirstImg(data, images);
      print('Response Body: ${response.body}');
      print('Response Code: ${response.statusCode}');

      // ✅ Decode the JSON string
      var result = jsonDecode(response.body);
      if (response.statusCode == 200) {
        successMsg('Operation created successfully');
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

  Future<http.Response> addFirstImg(Map<String, dynamic> data, Map<String, dynamic> images) async {
    try {
      var uri = Uri.parse("$baseUrl/drf-opim1");
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
      return await http.Response.fromStream(streamedResponse);
    } catch (e) {
      errorMsg(e.toString());
      return http.Response('Error', 500);
    }
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
    if (!isLoggedIn) {
      return const LoginPage();
    }

    if (isStarting) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text("Start Operation"),
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
                const LabelText(text: "Zone"),
                const SizedBox(height: 5),
                DropdownButtonFormField<int>(
                  value: selectedZoneId,
                  items: zones.map<DropdownMenuItem<int>>((zone) {
                    return DropdownMenuItem<int>(
                      value: zone['id'],
                      child: Text(
                        '${zone['zone_code']} (${zone['zone_name']})',
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (int? value) {
                    setState(() {
                      selectedZoneId = value;
                      if (value != null) {
                        fetchWards(value);
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Ward Dropdown
                const LabelText(text: "Ward"),
                const SizedBox(height: 5),
                DropdownButtonFormField<int>(
                  value: selectedWardId,
                  items: wards.map<DropdownMenuItem<int>>((ward) {
                    return DropdownMenuItem<int>(
                      value: ward['id'],
                      child: Text(
                        ward['ward_name'] == 'nan'
                            ? ward['ward_code']
                            : '${ward['ward_code']} - ${ward['ward_name']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (int? value) {
                    setState(() {
                      selectedWardId = value;
                    });
                  },
                  disabledHint: isFetchingWards
                      ? const Text("Loading wards...")
                      : const Text("Select a zone first"),
                ),
                const SizedBox(height: 10),

                // Image Pickers (keep your existing implementation)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Roll Call*',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        _buildImagePreview(rollcallImageController.text, 'Roll Call Image'),

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            CameraImagePicker(

                              onImagePicked: (value) {
                                setState(() {
                                  rollcallImageController.text = value.path;
                                });
                              },
                              text: 'Upload Roll Call Image',
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),
                ),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance First Page 1*',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        _buildImagePreview(attendanceFirstPage1.text, 'Attendance First Page 1 Image'),

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            CameraImagePicker(

                              onImagePicked: (value) {
                                setState(() {
                                  attendanceFirstPage1.text = value.path;
                                });
                              },
                              text: 'Upload Attendance First Page 1',
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance First Page 2',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        _buildImagePreview(attendanceFirstPage2.text, 'Attendance First Page 2 Image'),

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            CameraImagePicker(

                              onImagePicked: (value) {
                                setState(() {
                                  attendanceFirstPage2.text = value.path;
                                });
                              },
                              text: 'Upload Attendance First Page 2',
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance First Page 3',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        _buildImagePreview(attendanceFirstPage3.text, 'Attendance First Page 3 Image'),

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            CameraImagePicker(

                              onImagePicked: (value) {
                                setState(() {
                                  attendanceFirstPage3.text = value.path;
                                });
                              },
                              text: 'Upload Attendance First Page 3',
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
}