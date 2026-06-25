import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/buttons.dart';
import 'package:ourlandnew/components/input_fields.dart';
import 'package:ourlandnew/components/label.dart';
import "package:ourlandnew/config.dart";
import 'package:ourlandnew/pages/login.dart';

class AddZonePage extends StatefulWidget {
  const AddZonePage({super.key});

  @override
  State<AddZonePage> createState() => _AddZonePageState();
}

class _AddZonePageState extends State<AddZonePage> {
  bool isLoading = false;
  String baseUrl = AppConfig.apiUrl;
  Map zone = {};
  bool isLoggedIn = false;
  String? username;
  String? password;
  bool isStarting = false;
  List staffs = [];
  String? coreZone;

  Future<void> getDropDownValues() async {
    setState(() {
      staffs = [];
    });
    var staffUri = Uri.parse("$baseUrl/drf-staff-list/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    // STAFFS
    try {
      var staffResponse = await http.post(
        staffUri,
        headers: headers,
        body: jsonEncode({'filter': 'active'}),
      );
      if (staffResponse.statusCode == 200) {
        setState(() {
          staffs = jsonDecode(staffResponse.body);
        });
      }
    } catch (e) {
      print('Exception: $e');
    }
  }

  void checkLoginStatus() async {
    setState(() {
      isStarting = true;
    });
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
    await getDropDownValues();
    setState(() {
      isStarting = false;
    });
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
            ? const Center(child: CircularProgressIndicator())
            : GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                },
                child: SafeArea(
                  child: Scaffold(
                    appBar: AppBar(
                      backgroundColor: Colors.transparent,
                      title: const Text("Add Zone"),
                    ),
                    body: Card(
                      margin: const EdgeInsets.all(15),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 10,
                        ),
                        children: [
                          // CORE ZONE
                          const LabelText(text: "Core Zone*"),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            items: [
                              ['TBM', 'Tambaram'],
                              ['MDU', 'Madurai'],
                            ].map<DropdownMenuItem<String>>(
                                (List<String> value) {
                              return DropdownMenuItem<String>(
                                value: value[0],
                                child: Text(value[1]),
                              );
                            }).toList(),
                            decoration: InputDecoration(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onChanged: (String? value) {
                              setState(() {
                                coreZone = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              );
  }
}
