import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/pages/login.dart';

import 'package:ourlandnew/pages/vehicles/vehicles_list.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool? isLoggedIn;

  @override
  void initState() {
    super.initState();
    getDeviceId();
    checkLoginStatus();
  }

  Future<void> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceInfo = DeviceInfoPlugin();
    String? deviceId = "";

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      await prefs.setString('deviceId', androidInfo.id);
      print('checccckk1');
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor; // unique per vendor
    }
  }

  void checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    String? password = prefs.getString('password');

    setState(() {
      isLoggedIn = username != null && password != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoggedIn == null) {
      // Show loading indicator while checking login status
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      // Show appropriate screen based on login status
      return isLoggedIn! ? const VehiclesList() : const LoginPage();
    }
  }
}
