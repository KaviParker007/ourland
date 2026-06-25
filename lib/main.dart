import 'package:flutter/material.dart';
import 'package:ourlandnew/pages/Qr_Scan/bin_collection.dart';
import 'package:ourlandnew/pages/attendance/attendancePage.dart';
import 'package:ourlandnew/pages/attendance/conflict_attendance.dart';
import 'package:ourlandnew/pages/attendance/pending_attendance.dart';
import 'package:ourlandnew/pages/employee/employee_page.dart';
import 'package:ourlandnew/pages/fuel_log/fuel_log_list.dart';
import 'package:ourlandnew/pages/fuel_station/fuel_station_list.dart';
import 'package:ourlandnew/pages/job_cards/job_card_list.dart';
import 'package:ourlandnew/pages/Device/devicesPage.dart';
import 'package:ourlandnew/pages/login.dart';
import 'package:ourlandnew/pages/notifications/notification_list_page.dart';
import 'package:ourlandnew/pages/operation/operation_page.dart';
import 'package:ourlandnew/pages/shifts/shift_list.dart';
import 'package:ourlandnew/pages/shifts/shift_dashboard.dart';
import 'package:ourlandnew/pages/zones/zones_list.dart';
import 'package:ourlandnew/theme/dark_mode.dart';

import 'package:ourlandnew/auth/auth_page.dart';
import 'package:ourlandnew/pages/vehicles/vehicles_list.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ourland',
      theme: darkMode,
      debugShowCheckedModeBanner: false,
      home: const AuthPage(),
      routes: {
        "/login_page": (context) => const LoginPage(),
        "/vehicles_list": (context) => const VehiclesList(),
        "/zones_list": (context) => const ZonesList(),
        "/shift_list": (context) => const ShiftListPage(),
        "/shift_dashboard": (context) => const ShiftDashboardPage(),
        "/fuel_log_list": (context) => const FuelLogList(),
        "/job_card_list": (context) => const JobCardList(),
        "/fuel_station_list": (context) => const FuelStationList(),
        "/operation_page": (context) => const OperationPage(),
        "/attendance_page": (context) => const AttendancePage(),
        "/pending_page": (context) => const PendingAttendance(),
        "/device_page": (context) => const DeviceStatusPage(),
        "/employee_page": (context) => const EmployeeDetailsPage(),
        "/bin_collection": (context) => const BinCollectionScreen(),
        "/conflict_page": (context) => const ConflictsPage(),
        "/notifications": (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, String?>;
          return NotificationListPage(
            model: args['model'] ?? '',
            label: args['label'] ?? 'Notifications',
          );
        },
      },
    );
  }
}
