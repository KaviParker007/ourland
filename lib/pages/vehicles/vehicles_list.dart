import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/config.dart';
import 'package:ourlandnew/pages/login.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import "package:ourlandnew/components/label.dart";
import 'package:ourlandnew/pages/vehicles/add_vehicles.dart';
import 'package:ourlandnew/pages/vehicles/vehicle_view.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

class VehiclesListBuilder extends StatefulWidget {
  final List vehicles;
  final String? user;
  final String? password;

  const VehiclesListBuilder({super.key, required this.vehicles, this.user, this.password});

  @override
  State<VehiclesListBuilder> createState() => _VehiclesListBuilderState();
}

class _VehiclesListBuilderState extends State<VehiclesListBuilder>
    with SingleTickerProviderStateMixin {
  late final controller = SlidableController(this);
  bool isLoading = false;

  // Check if vehicle is idle (not operated today and not under maintenance)
  bool isIdle(Map<String, dynamic> vehicle) {
    // If vehicle is under maintenance, it's not idle
    if (vehicle['is_under_maintenance'] == true) return false;

    final lastOperated = vehicle['last_operated'];
    // If never operated, consider it idle
    if (lastOperated == null) return true;

    final today = DateTime.now();
    final operatedDate = DateTime.parse(lastOperated);

    // Check if last operated date is today
    return !(operatedDate.year == today.year &&
        operatedDate.month == today.month &&
        operatedDate.day == today.day);
  }

  void vehicleView(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VehicleView(vehicleId: id)),
    );
  }

  // Function to handle adding idle reason
  Future<void> addIdleReason(BuildContext context, Map<String, dynamic> vehicle) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Column(
            children: [
              Text(
                'Add Idle Reason',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                vehicle['vehicle_number'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: reasonController,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter reason for idle status...',
                    border: OutlineInputBorder(),
                    labelText: 'Reason',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a reason';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Date: $currentDate',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Submit'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ));

        if (result == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Call the API to submit the idle reason
        final response = await http.post(
          Uri.parse('${AppConfig.apiUrl}/drf-idle-vehicle-reason/'),
          headers: {
            'Content-Type': 'application/json',
            'authorization': 'Basic ${base64Encode(utf8.encode('${widget.user!}:${widget.password!}'))}',
          },
          body: jsonEncode({
            'id': vehicle['id'],
            'reason': reasonController.text,
            'idle_date': currentDate,
          }),
        );

        // Close loading indicator
        Navigator.pop(context);
        print('${AppConfig.apiUrl}/drf-idle-vehicle-reason/');
        print(widget.user);
        print(widget.user);
        print(vehicle['id']);
        print(reasonController.text,);
        print(currentDate);
        print(response.body);
          final responseData = jsonDecode(response.body);
          if (responseData['message'] == 'success') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Idle reason submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            throw Exception('Failed to submit idle reason');
          }

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
      child: CircularProgressIndicator(),
    )
        : ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: widget.vehicles.length,
      itemBuilder: (context, index) {
        final vehicle = widget.vehicles[index];
        final isVehicleIdle = isIdle(vehicle);

        return Slidable(
          key: ValueKey(vehicle['id']),
          // Only enable sliding if vehicle is idle
          enabled: vehicle['current_status']=='idle'?true:false,
          //enabled: true,
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              // IDLE REASON BUTTON
              SlidableAction(
                onPressed: (_) {
                  controller.close();
                  addIdleReason(context,vehicle,);
                },
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                borderRadius: BorderRadius.circular(15),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                icon: Icons.message_outlined,
                label: 'Idle Reason',
              ),
              /*// EDIT BUTTON
              SlidableAction(
                onPressed: (_) => controller.close(),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                borderRadius: BorderRadius.circular(15),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                icon: Icons.edit,
                label: 'Edit',
              ),
              // DEACTIVATE BUTTON
              SlidableAction(
                onPressed: (_) => controller.close(),
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
                borderRadius: BorderRadius.circular(15),
                icon: Icons.person_off_rounded,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                label: 'Deactivate',
              ),*/
            ],
          ),

          child: Column(
            children: [
              Card(
                color: vehicle['current_status']=='utilized'?Colors.greenAccent:vehicle['current_status']=='under-maintenance'?Colors.grey.withOpacity(0.5):vehicle['is_reasoned_today']==null?Color(0xFFff3e1d).withOpacity(0.7):Color(0xFFff3e1d).withOpacity(0.3),
                child: ListTile(
                  title: Text(vehicle['vehicle_number'],
                  style: TextStyle(
                    color: vehicle['is_reasoned_today']==null?Colors.white:Colors.grey,
                  ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle['vehicle_type'],
                      style: TextStyle(
                        color: vehicle['is_reasoned_today']==null?Colors.white:Colors.grey,
                      )
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(vehicle['zone_code'],
                          style: TextStyle(
                            color: vehicle['is_reasoned_today']==null?Colors.white:Colors.grey,
                          ),),
                          Row(
                            children: [

                              if (vehicle['is_working'] == false)
                                 Pill(
                                  text: vehicle['current_status'],
                                  textColor: Colors.black,
                                  backgroundColor: Colors.white,
                                  fontsize: 12,
                                  verticalPadding: -7,
                                ),
                               /* const Pill(
                                  text: "Not Working",
                                  textColor: Colors.white,
                                  backgroundColor: Colors.red,
                                  fontsize: 12,
                                  verticalPadding: -7,
                                ),
                              if (isVehicleIdle)
                                const SizedBox(width: 5),
                              if (isVehicleIdle)
                                const Pill(
                                  text: "Idle",
                                  textColor: Colors.white,
                                  backgroundColor: Colors.orange,
                                  fontsize: 12,
                                  verticalPadding: -7,
                                ),*/
                            ],
                          ),
                        ],
                      ),

                    ],
                  ),
                  onTap: () {
                    vehicleView(vehicle['id']);
                  },
                ),
              ),
              SizedBox(
                height: 2,
              )
            ],
          ),
        );
      },
    );
  }
}

class VehiclesList extends StatefulWidget {
  const VehiclesList({super.key});

  @override
  State<VehiclesList> createState() => _VehiclesListState();
}

class _VehiclesListState extends State<VehiclesList> {
  bool isLoggedIn = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List vehicles = [];

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> getVehiclesList({
    String filter = "is_active",
    bool value = true,
  }) async {
    setState(() {
      vehicles = [];
    });
    var uri = Uri.parse("$baseUrl/drf-vehicles/");
    print("urikkkkkkkkkkkkkkkkkkkkkkkkkk");
    print(uri);

    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    Map body = {};
    if (filter == "is_active") {
      body['is_active'] = value;
    } else if (filter == "is_working") {
      body['is_working'] = value;
    } else if (filter == "is_under_maintenance") {
      body['is_under_maintenance'] = value;
    } else if (filter == "is_spare") {
      body['is_spare'] = true;
    }

    try {
      var response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        setState(() {
          vehicles = jsonDecode(response.body);
          print('vehicles___');
          print(username);
          print(password);
          print(vehicles);
          print(body);
        });
      } else {
        // print('Failed response: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text("500 - Server Error"),
          duration: const Duration(seconds: 10),
        ));
      }
    } catch (e) {
      // print('Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(e.toString()),
        duration: const Duration(seconds: 10),
      ));
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
    await getVehiclesList();
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
                title: const Text("Vehicles List"),
                actions: [
                  const NotificationBellWidget(),
                  IconButton(
                    onPressed: () {
                      showSearch(
                        context: context,
                        delegate: CustomSearchDelegate(vehicles: vehicles),
                      );
                    },
                    icon: const Icon(Icons.search),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: "active",
                        child: Text("Active"),
                      ),
                      const PopupMenuItem(
                        value: "inactive",
                        child: Text("In Active"),
                      ),
                      const PopupMenuItem(
                        value: "working",
                        child: Text("Working"),
                      ),
                      const PopupMenuItem(
                        value: "notworking",
                        child: Text("Not Working"),
                      ),
                      const PopupMenuItem(
                        value: "undermaintenance",
                        child: Text("Under Maintenance"),
                      ),
                      const PopupMenuItem(
                        value: "sparevehicle",
                        child: Text("Spare Vehicle List"),
                      ),
                    ],
                    icon: const Icon(Icons.filter_list_rounded),
                    onSelected: (String filter) {
                      if (filter == "active") {
                        getVehiclesList(filter: "is_active", value: true);
                      } else if (filter == "inactive") {
                        getVehiclesList(filter: "is_active", value: false);
                      } else if (filter == "working") {
                        getVehiclesList(filter: "is_working", value: true);
                      } else if (filter == "notworking") {
                        getVehiclesList(filter: "is_working", value: false);
                      } else if (filter == "undermaintenance") {
                        getVehiclesList(
                            filter: "is_under_maintenance", value: true);
                      } else if (filter == "sparevehicle") {
                        getVehiclesList(filter: "is_spare", value: true);
                      }
                    },
                  ),
                ],
              ),
              drawer: const AppDrawer(),
              body: Visibility(
                visible: vehicles != [],
                replacement: Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                child: RefreshIndicator(
                  onRefresh: getVehiclesList,
                  child: VehiclesListBuilder(vehicles: vehicles,user: username,password: password),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddVehiclePage()),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ),
          );
  }
}

class CustomSearchDelegate extends SearchDelegate {
  List vehicles = [];
  CustomSearchDelegate({required this.vehicles});
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = "";
        },
        icon: const Icon(Icons.clear),
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    String searchQuery = query.toLowerCase();
    List searchList = [];
    Set<int> uniqueIds = {};
    if (searchQuery.isEmpty) {
      return VehiclesListBuilder(vehicles: vehicles);
    } else {
      for (var vehicle in vehicles) {
        for (var searchKey in ['vehicle_number', 'zone_code']) {
          if (vehicle[searchKey]
              .toString()
              .toLowerCase()
              .contains(searchQuery)) {
            if (!uniqueIds.contains(vehicle['id'])) {
              searchList.add(vehicle);
              uniqueIds.add(vehicle['id']);
            }
          }
        }
      }
      return VehiclesListBuilder(vehicles: searchList);
    }
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return VehiclesListBuilder(vehicles: vehicles,);
  }
}
