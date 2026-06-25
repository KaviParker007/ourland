import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_version.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? menu;
  bool isSuperUser = true;
  bool isAttendanceExpanded = false; // Track if attendance submenu is expanded

  @override
  void initState() {
    super.initState();
    getMenu();
  }

  void getMenu() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      menu = prefs.getString("menu");
    });
  }

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("username");
    await prefs.remove("password");
    await prefs.remove("deviceId");
    await prefs.remove("userid");
    Navigator.pushReplacementNamed(context, '/login_page');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Scrollable part
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                const DrawerHeader(
                  child: CircleAvatar(
                    radius: 80,
                    backgroundImage: AssetImage("assets/images/default-user.png"),
                  ),
                ),
                const SizedBox(height: 10),

                if (isSuperUser)
                  ListTile(
                    selected: menu == "vehicles",
                    leading: const Icon(Icons.directions_car),
                    title: const Text("Vehicle"),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/vehicles_list');
                    },
                  ),

                ListTile(
                  selected: menu == "shifts",
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text("Shift"),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/shift_list');
                  },
                ),
                ListTile(
                  selected: menu == "shift_dashboard",
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text("Shift Dashboard"),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/shift_dashboard');
                  },
                ),
                ListTile(
                  selected: menu == "fuel_log",
                  leading: const Icon(Icons.local_gas_station_rounded),
                  title: const Text("Fuel Log"),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/fuel_log_list');
                  },
                ),
                ListTile(
                  selected: menu == "job_card",
                  leading: const Icon(Icons.car_repair_rounded),
                  title: const Text("Job Card"),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/job_card_list');
                  },
                ),

                // Attendance with submenu
                Column(
                  children: [
                    ListTile(
                      selected: menu == "attendance" ||
                          menu == "attendance_daily" ||
                          menu == "attendance_monthly" ||
                          menu == "attendance_reports",
                      leading: const Icon(Icons.co_present_outlined),
                      title: const Text("Attendance"),
                      trailing: Icon(
                        isAttendanceExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      onTap: () {
                        setState(() {
                          isAttendanceExpanded = !isAttendanceExpanded;
                        });
                      },
                    ),
                    // Submenu items
                    if (isAttendanceExpanded) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 24.0),
                        child: ListTile(
                          selected: menu == "Biometric Attendance",
                          leading: const Icon(Icons.calendar_today, size: 20),
                          title: const Text("Biometric Attendance"),
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/attendance_page');
                          },
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(left: 24.0),
                        child: ListTile(
                          selected: menu == "Pending",
                          leading: const Icon(Icons.manage_accounts, size: 20),
                          title: const Text("Pending"),
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/pending_page');
                          },
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(left: 24.0),
                        child: ListTile(
                          selected: menu == "Conflicts",
                          leading: const Icon(Icons.filter_center_focus, size: 20),
                          title: const Text("Conflicts"),
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/conflict_page');
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 24.0),
                        child: ListTile(
                          selected: menu == "Devices",
                          leading: const Icon(Icons.location_pin, size: 20),
                          title: const Text("Devices"),
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/device_page');
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 24.0),
                        child: ListTile(
                          selected: menu == "operation",
                          leading: const Icon(Icons.photo_camera, size: 20),
                          title: const Text("operation"),
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/operation_page');
                          },
                        ),
                      ),
                    ],
                  ],
                ),

                ListTile(
                  selected: menu == "Employee",
                  leading: const Icon(Icons.person_add_rounded),
                  title: const Text("Employee Addition"),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/employee_page');

                  },
                ),
                ListTile(
                  selected: menu == "Bin Collections",
                  leading: const Icon(Icons.qr_code_2),
                  title: const Text("Bin Collections"),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/bin_collection');

                  },
                ),
              ],
            ),
          ),

          // Footer section
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("L O G O U T"),
            onTap: logout,
          ),
          const Divider(color: Colors.white),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: AppVersionText(),
          ),
        ],
      ),
    );
  }
}