import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ourlandnew/components/buttons.dart';
import 'package:ourlandnew/components/label.dart';
import 'package:ourlandnew/components/input_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../components/app_version.dart';
import '../config.dart';
import 'Qr_Scan/bin_collection.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  String baseUrl = AppConfig.apiUrl;
  String? deviceID;

  @override
  void initState() {
    super.initState();
    getDeviceId();

  }

  void getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceID = prefs.getString('deviceId');
    print(deviceID);
  }


  void goToHome() {
    Navigator.pushReplacementNamed(context, '/vehicles_list');
  }

  login(data) async {
    try {
      var uri = Uri.parse("$baseUrl/drf-login/");

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      return response;
    } catch (e) {
      return e.toString();
    }
  }

  void loginValidate() async {
    setState(() {
      isLoading = true;
    });

    String? username = usernameController.text.trim();
    String? password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text('Please enter both Username and Password'),
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        isLoading = false;
      });

      return;
    }

    var data = {
      "username": username,
      "password":password
    };

    var response = await login(data);
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if(response.statusCode == 200) {
      var responseData = jsonDecode(response.body);
      // Print is_superuser and user_type
      print('is_superuser: ${responseData['is_superuser']}');
      print('user_type: ${responseData['user_type']}');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('password', password);
      await prefs.setString('usertype', responseData['user_type']);
      await prefs.setInt('userid', responseData['id']);
      goToHome();
    } else {
      var error = jsonDecode(response.body);
     errorMsg(error['detail'].toString());
    }

    setState(() {
      isLoading = false;
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // LOGO
                  const Image(
                    image: AssetImage("assets/logo/ourland-logo.png"),
                  ),
                  const SizedBox(height: 50),

                  // USERNAME
                  const LabelText(text: "Username"),
                  const SizedBox(height: 5),
                  BasicInputField(
                    controller: usernameController,
                    obscureText: false,
                    hintText: "Enter your username",
                  ),
                  const SizedBox(height: 20),

                  // PASSWORD
                  const LabelText(text: "Password"),
                  const SizedBox(height: 5),
                  BasicInputField(
                    controller: passwordController,
                    obscureText: true,
                    hintText: "Enter your Password",
                  ),
                  const SizedBox(height: 20),

                  // SUBMIT BUTTON
                  if (isLoading) const CircularProgressIndicator(),
                  if (!isLoading)
                  GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BinCollectionScreen(),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            color: Color(0xffFFFFFF),
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Bin Collections',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xffFFFFFF),
                            ),
                          ),

                        ],
                      ),
                    ),
                  SizedBox(height: 6),
                  PrimaryButton(text: "Login", onPressed: loginValidate),
                  SizedBox(height: 20,),
                  AppVersionText(),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
