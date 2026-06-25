import "dart:convert";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:ourlandnew/components/buttons.dart";
import "package:ourlandnew/components/label.dart";
import "package:ourlandnew/config.dart";
import 'package:http/http.dart' as http;
import "package:ourlandnew/pages/login.dart";

class ZoneViewPage extends StatefulWidget {
  final int zoneId;
  const ZoneViewPage({
    super.key,
    required this.zoneId,
  });

  @override
  State<ZoneViewPage> createState() => _ZoneViewPageState();
}

class _ZoneViewPageState extends State<ZoneViewPage> {
  bool isLoading = false;
  String baseUrl = AppConfig.apiUrl;
  Map zone = {};
  bool isLoggedIn = false;
  String? username;
  String? password;

  void errorMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void getZone(int id) async {
    setState(() {
      isLoading = true;
    });
    var uri = Uri.parse("$baseUrl/test/zone/$id/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'Authorization': auth};
    var response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      setState(() {
        zone = jsonDecode(response.body);
      });
    } else {
      errorMsg("Unable to find User");
      Navigator.pop(context);
      Navigator.pushNamed(context, "/zones_list");
    }

    setState(() {
      isLoading = false;
    });
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
    getZone(widget.zoneId);
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
        : isLoading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : Scaffold(
                appBar: AppBar(
                  title: Text(zone["zone_code"].toString()),
                  backgroundColor: Colors.transparent,
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
                            // PILLS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                if (zone['enable_assistant'])
                                  const Padding(
                                    padding: EdgeInsets.only(right: 3),
                                    child: Pill(
                                      text: "Assistant Enabled",
                                      textColor: Colors.black,
                                      backgroundColor: Colors.green,
                                      fontsize: 12,
                                      verticalPadding: -5,
                                    ),
                                  ),
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
                            // ZONE CODE
                            const SizedBox(height: 5),
                            Text(
                              zone['zone_code'].toString(),
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),

                            // CORE ZONE
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const LabelText(text: "Core Zone"),
                                Text(
                                  zone["core_zone"].toString(),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            // ZONE NAME
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const LabelText(text: "Zone Name"),
                                Text(
                                  zone["zone_name"].toString(),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            // ZONE CODE
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const LabelText(text: "Zone Code"),
                                Text(
                                  zone["zone_code"].toString(),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            // PRROJECT HEAD
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const LabelText(text: "Project Head"),
                                Text(
                                  zone["project_head"].toString(),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            // OPERATION MANAGER
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const LabelText(text: "Operation Manager"),
                                Text(
                                  zone["operation_manager"].toString(),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            // ZONAL MANAGER
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const LabelText(text: "Zonal Manager"),
                                Text(
                                  zone["zonal_manager"].toString(),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
  }
}
