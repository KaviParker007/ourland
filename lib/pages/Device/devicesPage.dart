import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/config.dart';
import 'package:ourlandnew/pages/login.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'DeviceLogScreen.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

class DeviceListBuilder extends StatefulWidget {
  final List deviceList;
  const DeviceListBuilder({super.key, required this.deviceList});

  @override
  State<DeviceListBuilder> createState() => _DeviceListBuilderState();
}

class _DeviceListBuilderState extends State<DeviceListBuilder> {
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
      child: CircularProgressIndicator(),
    )
        : ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: widget.deviceList.length,
      itemBuilder: (context, index) {
        final device = widget.deviceList[index];
        final status = device['status'];
        final isOnline = status == 'online';

         return Slidable(
            key: ValueKey(device['serialnumber']),
            startActionPane: ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) {
                    loadDeviceLog(
                      serialNumber: device['serialnumber'],
                    );
                  },
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  icon: Icons.cloud_download,
                  label: 'Load',
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeviceLogScreen(
                      deviceId: device['deviceid'],
                      deviceName: device['devicesname'] ??
                          device['devicefname'] ??
                          'Unknown Device',
                    ),
                  ),
                );
              },
              child: Card(

              elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          device['devicesname'] ??
                              device['devicefname'] ??
                              'No Name',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('SERIAL NUMBER', device['serialnumber']),
                  _buildInfoRow('LAST PING', device['lastping']),
                  _buildInfoRow('LOCATION', device['devicelocation']),
                ],
              ),
            ),
          ),
         ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.35,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<void> loadDeviceLog({
    required String serialNumber,
  }) async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final password = prefs.getString('password');

    final uri = Uri.parse(
      "${AppConfig.apiUrl}/hr/drf_write_att_from_single_device_log/",
    );

    final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
        body: jsonEncode({
        //  "logdate": "2026-01-13", // 🔹 can be dynamic if needed
          "serial_number": serialNumber,
        }),
      );

      final data = jsonDecode(response.body);
      print('cheeee____');
      print(username);
      print(password);
      print(serialNumber);
      print(uri);
      print(response.statusCode);
      print(response.body);

      if (data['message'] != null && data['message'].toString().isNotEmpty) {
        _showSnackBar(
          data['message'],
          Colors.green,
        );
      }

      if (data['error'] != null && data['error'].toString().trim().isNotEmpty) {
        _showSnackBar(
          data['error'],
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar(
        "Something went wrong: $e",
        Colors.red,
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

}

class DeviceStatusPage extends StatefulWidget {
  const DeviceStatusPage({super.key});

  @override
  State<DeviceStatusPage> createState() => _DeviceStatusPageState();
}

class _DeviceStatusPageState extends State<DeviceStatusPage> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isSearching = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List deviceList = [];
  List filteredDeviceList = [];
  String title = "Devices";
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  void checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    String? user = prefs.getString('username');
    String? pass = prefs.getString('password');
    if (user != null && pass != null) {
      setState(() {
        isLoggedIn = true;
        username = user;
        password = pass;
      });
    }
    await getDeviceStatusList();
  }

  Future<void> getDeviceStatusList() async {
    setState(() {
      isLoading = true;
    });

    var uri = Uri.parse("$baseUrl/drf-device-status-list");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    print(uri);
    print(username);
    print(password);
    try {
      var response = await http.get(uri, headers: headers);
      print('devices_check');
      print(response.statusCode);
      print(response.body);
      if (response.statusCode == 200) {
        setState(() {
          deviceList = jsonDecode(response.body);
          filteredDeviceList = List.from(deviceList);
        });
      } else {
        errorMsg("Failed to load devices: ${response.statusCode}");
      }
    } catch (e) {
      errorMsg("Error: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  void filterDevices(String query) {
    setState(() {
      filteredDeviceList = deviceList.where((device) {
        final name = (device['devicesname'] ?? device['devicefname'] ?? '')
            .toString()
            .toLowerCase();
        final serial = (device['serialnumber'] ?? '')
            .toString()
            .toLowerCase();
        return name.contains(query.toLowerCase()) ||
            serial.contains(query.toLowerCase());
      }).toList();
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
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return !isLoggedIn
        ? const LoginPage()
        : Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
          controller: searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by name or serial...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: filterDevices,
        )
            : Text(title),
        backgroundColor: Colors.transparent,
        actions: [
          if (!isSearching) const NotificationBellWidget(),
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  searchController.clear();
                  filteredDeviceList = List.from(deviceList);
                }
              });
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      )
          : RefreshIndicator(
        onRefresh: getDeviceStatusList,
        child: DeviceListBuilder(deviceList: filteredDeviceList),
      ),
    );
  }
}