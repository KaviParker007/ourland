import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/pages/employee/upload_employee_details.dart';

import '../../components/drawer_page.dart';
import '../../config.dart';
import '../login.dart';
import 'add_employee_page.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

// Model class for Employee


// Main Employee Details Page
class EmployeeDetailsPage extends StatefulWidget {
  const EmployeeDetailsPage({Key? key}) : super(key: key);

  @override
  State<EmployeeDetailsPage> createState() => _EmployeeDetailsPageState();
}

class _EmployeeDetailsPageState extends State<EmployeeDetailsPage> {
  final String baseUrl = AppConfig.apiUrl;
  List<Employee> employees = [];
  bool isLoading = true;
  String errorMessage = '';
  String? username;
  String? password;
  bool isLoggedIn = false;
  bool _selectionMode = false;
  DropdownData? dropdownData;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username');
    password = prefs.getString('password');

    if (username != null && password != null) {
      setState(() => isLoggedIn = true);
      await fetchEmployees();
      await fetchDropdownData();
    }
  }
  // API call to fetch employee data
  Future<void> fetchEmployees() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final response = await http.get(Uri.parse('$baseUrl/hr/drf_list_req_employee'),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );
      print('cheeeeeee');
      print(response.statusCode);
      print(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        setState(() {
          employees = jsonData.map((json) => Employee.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load employees. Status: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> fetchDropdownData() async {
    print('check drpppp1');
    try {
      print('check drpppp2');
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final url = '$baseUrl/hr/drf_request_emp_addition';
      print('API URL: $url'); // 👈 Prints the full URL
      print('API URL: $username');
      print('API URL: $password');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );

      if (response.statusCode == 200) {
        print('check drpppp3');
        print(response.statusCode);
        print(response.body);
        final Map<String, dynamic> jsonData = json.decode(response.body);
        setState(() {
          dropdownData = DropdownData.fromJson(jsonData);
        });
      } else {
        print('Failed to load dropdown data. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching dropdown data: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return const LoginPage();
    }
    return Scaffold(

      appBar: AppBar(
        title:  Text(
          'Employee Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [NotificationBellWidget()],

      ),
      drawer: _selectionMode ? null : const AppDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : employees.isEmpty
          ? const Center(
        child: Text(
          'No employees found',
          style: TextStyle(fontSize: 18),
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          await fetchEmployees();
          await fetchDropdownData();// reload employees
        },
            child: LayoutBuilder(

                    builder: (context, constraints) {
               return ListView.builder(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                itemCount: employees.length,
                itemBuilder: (context, index) {
                  final employee = employees[index];
                  return Slidable(
                    key: ValueKey(employee.employeeId),

                    // Slide from right to left
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UploadEmployeeDetailsPage(
                                  employeeId: employee.employeeId,
                                  employeeName: employee.employeeName,
                                ),
                              ),
                            );

                            // Refresh the list if upload was successful
                            if (result == true) {
                              fetchEmployees();
                            }
                          },
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          icon: Icons.info,
                          label: 'Upload Details',
                        ),
                      ],
                    ),

                    child: InkWell(
                      onTap: () {

                        // Handle onTap -> Navigate to details page or show dialog
                      },
                      child: EmployeeCard(employee: employee),
                    ),
                  );
                },
              );



            // For multiple columns, use GridView

                    },
                  ),
          ),
      floatingActionButton: FloatingActionButton(

        onPressed: () {
          if (dropdownData != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEmployeePage(dropdownData: dropdownData!),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Loading dropdown data, please wait...'),
                backgroundColor: Colors.orange,
              ),
            );
          }

        },
        //backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),

    );
  }
}

// Employee Card Widget
class EmployeeCard extends StatelessWidget {
  final Employee employee;

  const EmployeeCard({Key? key, required this.employee}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade700, Colors.grey.shade700,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow(
                label: 'Id',
                value: employee.employeeId.toString(),
              ),
              const Divider(height: 5),
              _buildInfoRow(
                label: 'Name',
                value: employee.employeeName,
              ),
              const Divider(height: 5),

              // Ward Code
              _buildInfoRow(
                label: 'Ward',
                value: employee.wardCode,
              ),
              const SizedBox(height: 5),

              // Designation
              _buildInfoRow(
                label: 'Designation',
                value: employee.designationName,
              ),
              const SizedBox(height: 5),

              // Aadhaar Number
              _buildInfoRow(
                label: 'Aadhaar',
                value: employee.aadhaarNumber != null
                    ? _formatAadhaar(employee.aadhaarNumber!)
                    : 'N/A',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({

    required String label,
    required String value,

  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              label+': ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              value,
              style: TextStyle(
                fontSize:  15,
                fontWeight:  FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ],
    );
  }

  // Format Aadhaar number with spaces (XXXX XXXX XXXX)
  String _formatAadhaar(int aadhaar) {
    String aadhaarStr = aadhaar.toString();
    if (aadhaarStr.length == 12) {
      return '${aadhaarStr.substring(0, 4)} ${aadhaarStr.substring(4, 8)} ${aadhaarStr.substring(8, 12)}';
    }
    return aadhaarStr;
  }
}


class Employee {
  final int employeeId;
  final String employeeName;
  final String wardCode;
  final String designationName;
  final int? aadhaarNumber;

  Employee({
    required this.employeeId,
    required this.employeeName,
    required this.wardCode,
    required this.designationName,
    this.aadhaarNumber,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      employeeId: json['employee_id'] ?? 0,
      employeeName: json['employee_name'] ?? 'N/A',
      wardCode: json['ward_code'] ?? 'N/A',
      designationName: json['designation_name'] ?? 'N/A',
      aadhaarNumber: json['aadhaar_number'],
    );
  }
}

class DropdownData {
  final List<Project> projects;
  final Zone zone;
  final List<Ward> wards;
  final List<Designation> designations;
  final Map<String, String> maritalStatusChoices;

  DropdownData({
    required this.projects,
    required this.zone,
    required this.wards,
    required this.designations,
    required this.maritalStatusChoices,
  });

  factory DropdownData.fromJson(Map<String, dynamic> json) {
    return DropdownData(
      projects: (json['project'] as List).map((item) {
        if (item is List && item.length >= 2) {
          return Project(name: item[0] ?? '', value: item[1] ?? '');
        }
        return Project(name: 'Unknown', value: 'Unknown');
      }).toList(),
      zone: Zone.fromJson(json['zone']),
      wards: (json['ward'] as List).map((item) => Ward.fromJson(item)).toList(),
      designations: (json['designation'] as List).map((item) => Designation.fromJson(item)).toList(),
      maritalStatusChoices: Map<String, String>.from(json['maritalstatus_choices'] ?? {}),
    );
  }
}

class Project {
  final String name;
  final String value;

  Project({required this.name, required this.value});
}

class Zone {
  final int id;
  final String zoneCode;

  Zone({required this.id, required this.zoneCode});

  factory Zone.fromJson(Map<String, dynamic> json) {
    return Zone(
      id: json['id'] ?? 0,
      zoneCode: json['zone_code'] ?? '',
    );
  }
}

class Ward {
  final int id;
  final String wardCode;

  Ward({required this.id, required this.wardCode});

  factory Ward.fromJson(Map<String, dynamic> json) {
    return Ward(
      id: json['id'] ?? 0,
      wardCode: json['ward_code'] ?? '',
    );
  }
}

class Designation {
  final int id;
  final String designationName;

  Designation({required this.id, required this.designationName});

  factory Designation.fromJson(Map<String, dynamic> json) {
    return Designation(
      id: json['id'] ?? 0,
      designationName: json['designation_name'] ?? '',
    );
  }
}