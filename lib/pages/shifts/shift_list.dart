import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/config.dart';
import 'package:ourlandnew/pages/login.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:ourlandnew/pages/shifts/add_shift.dart';
import 'package:ourlandnew/pages/shifts/rotate_shift.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

import 'end_shift.dart';

class ShiftListBuilder extends StatefulWidget {
  final List shifts;
  const ShiftListBuilder({super.key, required this.shifts});

  @override
  State<ShiftListBuilder> createState() => _ShiftListBuilderState();
}

class _ShiftListBuilderState extends State<ShiftListBuilder> with SingleTickerProviderStateMixin {
  late final controller = SlidableController(this);
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.shifts.length,
            itemBuilder: (context, index) {
              final shift = widget.shifts[index];
              return Slidable(
                key: const ValueKey(0),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    if (shift['end_time'] == null) ...[
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

                      // ROTATE TRIP BUTTON
                      SlidableAction(
                        onPressed: (_) => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => RotateShiftPage(shiftId: shift['id'])),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        icon: Icons.repeat,
                        label: 'Rotate',
                      ),

                      // END TRIP BUTTON
                      SlidableAction(
                        onPressed: (_) => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EndShiftPage(shiftId: shift['id'])),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        icon: Icons.timer_off,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        label: 'End',
                        // spacing: 8,
                      )
                    ],
                  ],
                ),
                child: Card(
                  elevation: 5,
                  child: ListTile(
                    title: Text(
                      "vehicle Number : ${shift['vehicle_number'].toString()}",
                      style: TextStyle(color: shift['end_time'] == null ? null : Colors.grey),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("shift Name : ${shift['shift_name'].toString()}",
                            style: TextStyle(color: shift['end_time'] == null ? null : Colors.grey)),
                        Text("Driver : ${shift['driver'].toString()}",
                            style: TextStyle(color: shift['end_time'] == null ? null : Colors.grey)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }
}

class ShiftListPage extends StatefulWidget {
  const ShiftListPage({super.key});

  @override
  State<ShiftListPage> createState() => _ShiftListPageState();
}

class _ShiftListPageState extends State<ShiftListPage> {
  bool isLoggedIn = false;
  bool isLoading = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List todayShift = [];
  List shifts = [];
  List unclosedShift = [];
  String title = "Todays Shifts";

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

  Future<void> getTodayShift({
    String filter = "is_active",
    bool value = true,
  }) async {
    setState(() {
      isLoading = true;
      todayShift = [];
      unclosedShift = [];
    });
    var uri = Uri.parse("$baseUrl/drf-today-shift-list-v2/");

    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var response = await http.get(uri, headers: headers);
      print('shift_check');
      print(uri);
      print(response.statusCode);
      print(response.body);
      if (response.statusCode == 200) {
        setState(() {
          var responseData = jsonDecode(response.body);
          todayShift = responseData['today_shift_list'];
          unclosedShift = responseData['unclosed_shift'];
          shifts = todayShift;
        });
      } else {
        // print('Failed response: ${response.statusCode} - ${response.body}');
        errorMsg("500 - Server Error");
      }
    } catch (e) {
      // print('Exception: $e');
      errorMsg("500 - Server Error");
    }
    setState(() {
      isLoading = false;
    });
  }

  void checkLoginStatus() async {
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
    await getTodayShift();
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
                title: Text(title),
                backgroundColor: Colors.transparent,
                actions: [
                  const NotificationBellWidget(),
                  IconButton(
                    onPressed: () {
                      showSearch(
                        context: context,
                        delegate: CustomSearchDelegate(shifts: shifts),
                      );
                    },
                    icon: const Icon(Icons.search),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: "today",
                        child: Text("Todays Shifts"),
                      ),
                      const PopupMenuItem(
                        value: "unclosed",
                        child: Text("Unclosed Shifts"),
                      ),
                    ],
                    icon: const Icon(Icons.filter_list_rounded),
                    onSelected: (String filter) {
                      if (filter == "today") {
                        setState(() {
                          shifts = todayShift;
                          title = "Todays Shifts";
                        });
                      } else if (filter == "unclosed") {
                        setState(() {
                          shifts = unclosedShift;
                          title = "Unclosed Shifts";
                        });
                      }
                    },
                  ),
                ],
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
                  onRefresh: getTodayShift,
                  child: ShiftListBuilder(shifts: shifts),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddShiftPage()),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ),
          );
  }
}

class CustomSearchDelegate extends SearchDelegate {
  List shifts = [];
  CustomSearchDelegate({required this.shifts});
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
      return ShiftListBuilder(shifts: shifts);
    } else {
      for (var shift in shifts) {
        for (var searchKey in ['vehicle_number', 'driver']) {
          if (shift[searchKey]
              .toString()
              .toLowerCase()
              .contains(searchQuery)) {
            if (!uniqueIds.contains(shift['id'])) {
              searchList.add(shift);
              uniqueIds.add(shift['id']);
            }
          }
        }
      }
      return ShiftListBuilder(shifts: searchList);
    }
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ShiftListBuilder(shifts: shifts);
  }
}