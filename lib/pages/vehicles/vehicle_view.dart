import "dart:convert";
import "dart:io";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:ourlandnew/components/label.dart";
import "package:ourlandnew/config.dart";
import 'package:http/http.dart' as http;
import "package:ourlandnew/pages/login.dart";
import "package:ourlandnew/pages/vehicles/edit_vehicle.dart";

import "../../components/buttons.dart";
import "../../components/image_picker.dart";

class VehicleView extends StatefulWidget {
  final int vehicleId;
  const VehicleView({
    super.key,
    required this.vehicleId,
  });

  @override
  State<VehicleView> createState() => _VehicleViewState();
}

class _VehicleViewState extends State<VehicleView> {
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  Map vehicle = {};
  bool isLoggedIn = false;
  String? username;
  String? password;
  String frontImage = '';
  String leftImage = '';
  String backImage = '';
  String rightImage = '';

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

  void getVehicle(int id) async {
    setState(() {
      isStarting = true;
    });
    var uri = Uri.parse("$baseUrl/drf-vehicle-detail/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    var body = jsonEncode({"vehicle_id": id});
    var response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200) {
      setState(() {
        vehicle = jsonDecode(response.body);
      });
    } else {
      errorMsg("Unable to find Vehicle");
      Navigator.pop(context);
      Navigator.pushNamed(context, "/vehicles_list");
    }

    setState(() {
      isStarting = false;
    });
  }

  _uploadImage() async {
    setState(() {
      isLoading = true;
    });
    try {
      var uri = Uri.parse("$baseUrl/drf-upload-photoes/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = auth;
      final vehicleIdBytes = utf8.encode(vehicle['id'].toString());
      request.fields['vehicle_id'] = String.fromCharCodes(vehicleIdBytes);

      Future<void> addFileIfExists(String filePath, String fieldName) async {
        if (filePath.isNotEmpty && File(filePath).existsSync()) {
          request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
        } else {
          print('$fieldName image path is invalid or empty: $filePath');
        }
      }

      await addFileIfExists(frontImage, 'front');
      await addFileIfExists(backImage, 'back');
      await addFileIfExists(leftImage, 'left');
      await addFileIfExists(rightImage, 'right');

      final response = await request.send();
      print(response.reasonPhrase);
      if (response.statusCode == 200) {
        successMsg('Image\'s Uploaded Successfully');
      } else {
        errorMsg('Image\'s Uploaded Failed');
      }
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      return errorMsg(e.toString());
    }
  }

  void checkLoginStatus() async {
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
    getVehicle(widget.vehicleId);
  }

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  @override
  Widget build(BuildContext context) {
    return !isLoggedIn
        ? const LoginPage()
        : isStarting
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : Scaffold(
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  title: Text(vehicle['vehicle_number'].toString()),
                  actions: [
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditVehicle(vehicleId: vehicle['id']),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                    ),
                  ],
                ),
                body: ListView(
                  padding: const EdgeInsets.all(15),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 15,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text(
                              vehicle['vehicle_number'].toString(),
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // PILLS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                if (vehicle['is_working'] == false)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 3),
                                    child: Pill(
                                      text: "Not Working",
                                      textColor: Colors.white,
                                      backgroundColor: Colors.red,
                                      fontsize: 12,
                                      verticalPadding: -5,
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(right: 3),
                                    child: Pill(
                                      text: "Working",
                                      textColor: Colors.black,
                                      backgroundColor: Theme.of(context).colorScheme.tertiary,
                                      fontsize: 12,
                                      verticalPadding: -5,
                                    ),
                                  ),
                                if (vehicle['is_active'] == false)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 3),
                                    child: Pill(
                                      text: "In Active",
                                      textColor: Colors.white,
                                      backgroundColor: Colors.red,
                                      fontsize: 12,
                                      verticalPadding: -5,
                                    ),
                                  ),
                                if (vehicle['is_spare'] == true)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 3),
                                    child: Pill(
                                      text: "Spare",
                                      textColor: Colors.white,
                                      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                                      fontsize: 12,
                                      verticalPadding: -5,
                                    ),
                                  ),
                                if (vehicle['is_under_maintenance'] == true)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 3),
                                    child: Pill(
                                      text: "Under Maintenance",
                                      textColor: Colors.white,
                                      backgroundColor: Colors.red,
                                      fontsize: 12,
                                      verticalPadding: -5,
                                    ),
                                  )
                              ],
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const LabelText(text: "Vehicle Type"),
                                Text(
                                  vehicle["vehicle_type"].toString(),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const LabelText(text: "Possession"),
                                Text(
                                  vehicle["possession"].toString(),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const LabelText(text: "Current KM"),
                                Text(
                                  vehicle["current_km"].toString(),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const LabelText(text: "Zone"),
                                Text(
                                  vehicle["zone_code"].toString(),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const LabelText(text: "Workshop"),
                                Text(
                                  vehicle["workshop"].toString(),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            if (vehicle['is_under_maintenance'] == true)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const LabelText(text: "Under Maintenance Date"),
                                    Text(
                                      vehicle["under_maintenance_date"].toString(),
                                      style: const TextStyle(fontSize: 17),
                                    ),
                                  ],
                                ),
                              ),

                            if (vehicle['supervisor'] != [])
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const LabelText(text: "Supervisors"),
                                  Column(
                                    children: [
                                      for (var i = 0; i < vehicle['supervisor'].length; i++)
                                        Text(vehicle['supervisors_name'][i]),
                                    ],
                                  )
                                ],
                              ),

                            if (vehicle['remark'].toString().isNotEmpty)
                              Column(
                                children: [
                                  const SizedBox(height: 10),
                                  const LabelText(text: "Remark"),
                                  Text(
                                    vehicle['remark'].toString(),
                                    style: const TextStyle(fontSize: 17),
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
                              'Vehicle Front Image',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            vehicle['vehicle_front_photo'] != null
                                ? Image.network(
                                    '$baseUrl${vehicle['vehicle_front_photo']}',
                                    loadingBuilder:
                                        (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  (loadingProgress.expectedTotalBytes ?? 1)
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                      return const Text('Failed to load image');
                                    },
                                  )
                                : (frontImage.isNotEmpty)
                                    ? Image.file(
                                        File(frontImage),
                                        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                          return const Text('Failed to load image');
                                        },
                                      )
                                    : const Center(
                                        child: Text('Image Not Yet Uploaded'),
                                      ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Spacer(),
                                CameraImagePicker(
                                  onImagePicked: (value) {
                                    setState(() {
                                      frontImage = value.path;
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vehicle Left Image',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            vehicle['vehicle_left_photo'] != null
                                ? Image.network(
                                    '$baseUrl${vehicle['vehicle_left_photo']}',
                                    loadingBuilder:
                                        (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  (loadingProgress.expectedTotalBytes ?? 1)
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                      return const Text('Failed to load image');
                                    },
                                  )
                                : (leftImage.isNotEmpty)
                                    ? Image.file(
                                        File(leftImage),
                                        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                          return const Text('Failed to load image');
                                        },
                                      )
                                    : const Center(
                                        child: Text('Image Not Yet Uploaded'),
                                      ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Spacer(),
                                CameraImagePicker(
                                  onImagePicked: (value) {
                                    setState(() {
                                      leftImage = value.path;
                                    });
                                  },
                                  text: 'Upload Left Image',
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
                              'Vehicle Back Image',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            vehicle['vehicle_back_photo'] != null
                                ? Image.network(
                                    '$baseUrl${vehicle['vehicle_back_photo']}',
                                    loadingBuilder:
                                        (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  (loadingProgress.expectedTotalBytes ?? 1)
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                      return const Text('Failed to load image');
                                    },
                                  )
                                : (backImage.isNotEmpty)
                                    ? Image.file(
                                        File(backImage),
                                        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                          return const Text('Failed to load image');
                                        },
                                      )
                                    : const Center(
                                        child: Text('Image Not Yet Uploaded'),
                                      ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Spacer(),
                                CameraImagePicker(
                                  onImagePicked: (value) {
                                    setState(() {
                                      backImage = value.path;
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vehicle Right Image',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            vehicle['vehicle_right_photo'] != null
                                ? Image.network(
                                    '$baseUrl${vehicle['vehicle_right_photo']}',
                                    loadingBuilder:
                                        (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  (loadingProgress.expectedTotalBytes ?? 1)
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                      return const Text('Failed to load image');
                                    },
                                  )
                                : (rightImage.isNotEmpty)
                                    ? Image.file(
                                        File(rightImage),
                                        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                          return const Text('Failed to load image');
                                        },
                                      )
                                    : const Center(
                                        child: Text('Image Not Yet Uploaded'),
                                      ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Spacer(),
                                CameraImagePicker(
                                  onImagePicked: (value) {
                                    setState(() {
                                      rightImage = value.path;
                                    });
                                  },
                                  text: 'Upload Right Image',
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : PrimaryButton(text: "Submit", onPressed: _uploadImage)
                  ],
                ),
              );
  }
}
