import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/components/label.dart';
import 'package:ourlandnew/config.dart';
import 'package:ourlandnew/pages/login.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:ourlandnew/pages/zones/add_zone.dart';
import 'package:ourlandnew/pages/zones/zone_view.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

class ZonesListBuilder extends StatefulWidget {
  final List zones;
  const ZonesListBuilder({super.key, required this.zones});

  @override
  State<ZonesListBuilder> createState() => _ZonesListBuilderState();
}

class _ZonesListBuilderState extends State<ZonesListBuilder>
    with SingleTickerProviderStateMixin {
  late final controller = SlidableController(this);
  bool isLoading = false;

  void zoneView(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ZoneViewPage(zoneId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: widget.zones.length,
            itemBuilder: (context, index) {
              final zone = widget.zones[index];
              return Slidable(
                key: const ValueKey(0),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    // EDIT BUTTON
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
                      // spacing: 8,
                    )
                  ],
                ),
                child: Card(
                  child: ListTile(
                    title: Text(zone['zone_code']),
                    subtitle: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(zone['zone_name']),
                        if (!zone['is_active'])
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
                      ],
                    ),
                    onTap: () {
                      zoneView(zone['id']);
                    },
                  ),
                ),
              );
            });
  }
}

class ZonesList extends StatefulWidget {
  const ZonesList({super.key});

  @override
  State<ZonesList> createState() => _ZonesListState();
}

class _ZonesListState extends State<ZonesList> {
  bool isLoggedIn = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List zones = [];

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> getZonesList() async {
    var uri = Uri.parse("$baseUrl/test/zone/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    try {
      var response = await http.get(
        uri,
        headers: headers,
      );
      if (response.statusCode == 200) {
        setState(() {
          zones = jsonDecode(response.body);
        });
      } else {
        // print('Failed response: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text(response.body.toString()),
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
    await prefs.setString("menu", "zones");
    String? user = prefs.getString('username');
    String? pass = prefs.getString('password');
    if (user != null && pass != null) {
      setState(() {
        isLoggedIn = true;
        username = user;
        password = pass;
      });
    }
    await getZonesList();
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
                title: const Text("Zones List"),
                actions: const [NotificationBellWidget()],
              ),
              drawer: const AppDrawer(),
              body: Visibility(
                visible: zones != [],
                replacement: const Center(
                  child: CircularProgressIndicator(),
                ),
                child: RefreshIndicator(
                  onRefresh: getZonesList,
                  child: ZonesListBuilder(zones: zones),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddZonePage()),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ),
          );
  }
}
