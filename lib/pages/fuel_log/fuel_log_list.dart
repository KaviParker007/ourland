import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/config.dart';
import 'package:ourlandnew/pages/fuel_log/add_fuel_log.dart';
import 'package:ourlandnew/pages/fuel_log/edit_fuel_log.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';
import 'package:ourlandnew/pages/login.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class FuelLogListBuilder extends StatefulWidget {
  final List fuelLogs;
  final String username;
  final String password;
  const FuelLogListBuilder({
    super.key,
    required this.fuelLogs,
    required this.username,
    required this.password,
  });

  @override
  State<FuelLogListBuilder> createState() => _FuelLogListBuilderState();
}

class _FuelLogListBuilderState extends State<FuelLogListBuilder>
    with SingleTickerProviderStateMixin {
  late final controller = SlidableController(this);
  bool isLoading = false;

  void editFuelLog(Map fuelLog) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => EditFuelLog(
            fuelLog: fuelLog,
          )),
    );
  }

  // Helper method to parse color from hex string
  Color _getColorFromCode(String? colorCode) {
    if (colorCode == null || colorCode.isEmpty) {
      return Colors.white; // Default color if no color code
    }

    try {
      // Remove the '#' if present and parse the hex value
      String hexColor = colorCode.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      print('Error parsing color code: $colorCode, error: $e');
      return Colors.white; // Return default color on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
      child: CircularProgressIndicator(),
    )
        : ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: widget.fuelLogs.length,
      itemBuilder: (context, index) {
        final fuelLog = widget.fuelLogs[index];
        final bool isLocked = fuelLog['lock_card'] == true;

        // If locked, show without slidable options
        if (isLocked) {
          return Card(
            color: _getColorFromCode(fuelLog['color_code']),
            child: ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fuelLog['vehicle_number'].toString()),
                  const Icon(
                    Icons.lock,
                    size: 16,
                    color: Colors.black54,
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(fuelLog['fuel_type'].toString()),
                  Text(fuelLog['fueled_person'].toString()),
                  Text(fuelLog['fuel_date'].toString()),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${fuelLog['fuel_quantity']} L"),
                      Text("₹ ${fuelLog['fuel_unit_cost']}"),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          );
        }

        // If not locked, show with slidable options
        return Slidable(
          key: ValueKey(fuelLog['id']),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (context) {
                  openCameraAndUpload(fuelLog['id']);
                },
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                icon: Icons.camera_alt,
                label: 'Camera',
              ),
            ],
          ),
          child: Card(
            color: _getColorFromCode(fuelLog['color_code']),
            child: ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fuelLog['vehicle_number'].toString()),
                  fuelLog['lock_card']==true? Icon(
                    Icons.lock_open,
                    size: 16,
                    color: Colors.black54,
                  ):SizedBox()
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(fuelLog['fuel_type'].toString()),
                  Text(fuelLog['fueled_person'].toString()),
                  Text(fuelLog['fuel_date'].toString()),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${fuelLog['fuel_quantity']} L"),
                      Text("₹ ${fuelLog['fuel_unit_cost']}"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> openCameraAndUpload(int fuelLogId) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (image == null) return;

    await uploadAfterImage(fuelLogId, image.path);
  }

  Future<void> uploadAfterImage(int fuelLogId, String imagePath) async {
    try {
      setState(() {
        isLoading = true;
      });

      String baseUrl = AppConfig.apiUrl;
      var uri = Uri.parse("$baseUrl/drf_fuel_log_after_image/");
      var auth = 'Basic ${base64Encode(utf8.encode('${widget.username}:${widget.password}'))}';

      var request = http.MultipartRequest('POST', uri)
        ..headers['authorization'] = auth;

      request.fields['id'] = fuelLogId.toString();

      request.files.add(
        await http.MultipartFile.fromPath('after_image', imagePath),
      );

      print("Uploading After Image...");
      print("URL: $uri");
      print("ID: $fuelLogId");
      print("Image Path: $imagePath");

      var response = await request.send();
      var res = await http.Response.fromStream(response);

      print("Status: ${res.statusCode}");
      print("Body: ${res.body}");

      if (res.statusCode == 200||res.statusCode ==201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("After Image Uploaded Successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Upload Failed")),
        );
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}

class FuelLogList extends StatefulWidget {
  const FuelLogList({super.key});

  @override
  State<FuelLogList> createState() => _FuelLogListState();
}

class _FuelLogListState extends State<FuelLogList> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isSearching = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List fuelLogs = [];
  List filteredFuelLogs = [];
  TextEditingController searchController = TextEditingController();

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

  Future<void> getFuelLogs() async {
    setState(() {
      isLoading = true;
      fuelLogs = [];
      filteredFuelLogs = [];
    });
    var uri = Uri.parse("$baseUrl/drf-fuel-log-list/");

    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var response = await http.get(uri, headers: headers);
      print('fuellog_check');
      print(uri);
      print(username);
      print(password);
      print(response.statusCode);
      print(response.body);
      if (response.statusCode == 200) {
        setState(() {
          fuelLogs = jsonDecode(response.body);
          filteredFuelLogs = List.from(fuelLogs);
        });
      } else {
        errorMsg("500 - Server Error");
      }
    } catch (e) {
      print('Exception: $e');
      errorMsg("500 - Server Error");
    }
    setState(() {
      isLoading = false;
    });
  }

  void checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("menu", "fuel_log");
    String? user = prefs.getString('username');
    String? pass = prefs.getString('password');
    if (user != null && pass != null) {
      setState(() {
        isLoggedIn = true;
        username = user;
        password = pass;
      });
      await getFuelLogs();
    }
  }

  void filterFuelLogs(String query) {
    setState(() {
      filteredFuelLogs = fuelLogs.where((log) {
        final vehicleNumber = log['vehicle_number'].toString().toLowerCase();
        return vehicleNumber.contains(query.toLowerCase());
      }).toList();
    });
  }

  Widget buildSearchField() {
    return TextField(
      controller: searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search vehicle number...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: Theme.of(context).hintColor),
      ),
      style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontSize: 16),
      onChanged: filterFuelLogs,
    );
  }

  List<Widget> buildAppBarActions() {
    if (isSearching) {
      return [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              isSearching = false;
              searchController.clear();
              filteredFuelLogs = List.from(fuelLogs);
            });
          },
        ),
      ];
    } else {
      return [
        const NotificationBellWidget(),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            setState(() {
              isSearching = true;
            });
          },
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return !isLoggedIn
        ? const LoginPage()
        : GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: isSearching ? buildSearchField() : const Text("Fuel Logs"),
          actions: buildAppBarActions(),
        ),
        drawer: isSearching ? null : const AppDrawer(),
        body: Visibility(
          visible: !isLoading,
          replacement: Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: RefreshIndicator(
            onRefresh: getFuelLogs,
            child: FuelLogListBuilder(
              fuelLogs: filteredFuelLogs,
              username: username!,
              password: password!,
            ),
          ),
        ),
        floatingActionButton: isSearching ? null : FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddFuelLog()),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}