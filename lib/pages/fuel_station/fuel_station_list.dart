import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/config.dart';
import 'package:ourlandnew/pages/fuel_station/add_fuel_station.dart';
import 'package:ourlandnew/pages/fuel_station/edit_fuel_station.dart';
import 'package:ourlandnew/pages/login.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

class FuelStationListBuilder extends StatefulWidget {
  final List fuelStations;
  const FuelStationListBuilder({super.key, required this.fuelStations});

  @override
  State<FuelStationListBuilder> createState() => _FuelStationListBuilderState();
}

class _FuelStationListBuilderState extends State<FuelStationListBuilder>
    with SingleTickerProviderStateMixin {
  late final controller = SlidableController(this);
  bool isLoading = false;

  void editFuelStation(Map fuelStation) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => EditFuelStation(fuelStation: fuelStation)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.fuelStations.length,
            itemBuilder: (context, index) {
              final fuelStation = widget.fuelStations[index];
              return Slidable(
                key: const ValueKey(0),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    // EDIT BUTTON
                    SlidableAction(
                      onPressed: (_) => editFuelStation(fuelStation),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      icon: Icons.edit,
                      label: 'Edit',
                    ),
                  ],
                ),
                child: Card(
                  child: ListTile(
                    title: Text(fuelStation['name'].toString()),
                    subtitle: Text(fuelStation['core_zone'].toString()),
                  ),
                ),
              );
            },
          );
  }
}

class FuelStationList extends StatefulWidget {
  const FuelStationList({super.key});

  @override
  State<FuelStationList> createState() => _FuelStationListState();
}

class _FuelStationListState extends State<FuelStationList> {
  bool isLoggedIn = false;
  bool isLoading = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List fuelStations = [];

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

  Future<void> getFuelStations() async {
    setState(() {
      isLoading = true;
      fuelStations = [];
    });
    var uri = Uri.parse("$baseUrl/drf-fuel-station-list/");

    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        setState(() {
          fuelStations = jsonDecode(response.body);
        });
      } else {
        // print('Failed response: ${response.statusCode} - ${response.body}');
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
      await getFuelStations();
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
                title: const Text("Fuel Stations"),
                actions: const [NotificationBellWidget()],
              ),
              drawer: const AppDrawer(),
              body: Visibility(
                visible: !isLoading,
                replacement: Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                child: RefreshIndicator(
                  onRefresh: getFuelStations,
                  child: FuelStationListBuilder(fuelStations: fuelStations),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddFuelStation()),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ),
          );
  }
}
