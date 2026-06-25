import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';
import 'employee_page.dart';


class AddEmployeePage extends StatefulWidget {
  final DropdownData dropdownData;

  const AddEmployeePage({Key? key, required this.dropdownData}) : super(key: key);

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  final _formKey = GlobalKey<FormState>();
  final String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  // Dropdown values from API
  late List<Project> projects;
  late List<Ward> wards;
  late List<Designation> designations;
  late Map<String, String> maritalStatusChoices;
  bool isLoading =false;

  // Form controllers
  Project? selectedProject;
  Ward? selectedWard;
  Designation? selectedDesignation;
  String? selectedMaritalStatus;

  // Other controllers and variables
  final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  String? selectedBloodGroup;

  TextEditingController previousEmployeeIdController = TextEditingController();
  TextEditingController employeeNameController = TextEditingController();
  TextEditingController dateOfBirthController = TextEditingController();
  TextEditingController placeOfBirthController = TextEditingController();
  TextEditingController nationalityController = TextEditingController();
  TextEditingController aadhaarNumberController = TextEditingController();
  TextEditingController uanNumberController = TextEditingController();
  TextEditingController accountNumberController = TextEditingController();
  TextEditingController licenseNumberController = TextEditingController();
  TextEditingController fatherNameController = TextEditingController();
  TextEditingController motherNameController = TextEditingController();
  TextEditingController spouseNameController = TextEditingController();
  TextEditingController nominee1NameController = TextEditingController();
  TextEditingController nominee1RelationshipController = TextEditingController();
  TextEditingController nominee2NameController = TextEditingController();
  TextEditingController nominee2RelationshipController = TextEditingController();
  TextEditingController contactNoController = TextEditingController();
  TextEditingController contactAddressController = TextEditingController();
  TextEditingController residentialAddressController = TextEditingController();
  TextEditingController emailController = TextEditingController();

  bool isPreviousEmployee = false;
  bool isMale = true;
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    // Initialize dropdown data from API response
    projects = widget.dropdownData.projects;
    wards = widget.dropdownData.wards;
    designations = widget.dropdownData.designations;
    maritalStatusChoices = widget.dropdownData.maritalStatusChoices;

    // Set default values if available
    if (projects.isNotEmpty) selectedProject = projects.first;
    if (wards.isNotEmpty) selectedWard = wards.first;
    if (designations.isNotEmpty) selectedDesignation = designations.first;
    if (maritalStatusChoices.isNotEmpty) {
      selectedMaritalStatus = maritalStatusChoices.keys.first;
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    previousEmployeeIdController.dispose();
    employeeNameController.dispose();
    dateOfBirthController.dispose();
    placeOfBirthController.dispose();
    nationalityController.dispose();
    aadhaarNumberController.dispose();
    uanNumberController.dispose();
    accountNumberController.dispose();
    licenseNumberController.dispose();
    fatherNameController.dispose();
    motherNameController.dispose();
    spouseNameController.dispose();
    nominee1NameController.dispose();
    nominee1RelationshipController.dispose();
    nominee2NameController.dispose();
    nominee2RelationshipController.dispose();
    contactNoController.dispose();
    contactAddressController.dispose();
    residentialAddressController.dispose();
    emailController.dispose();
    super.dispose();
  }



  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        dateOfBirthController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
    else
      {
        dateOfBirthController.text = '';
      }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _saveEmployeeData();
    }
  }

  Future<void> _saveEmployeeData() async {
    setState(() {
      isLoading =true;
    });
    // Prepare data for API submission
    final employeeData = {
      'project': selectedProject?.value,
      'zone': widget.dropdownData.zone.id,
      'ward': selectedWard?.id,
      'designation': selectedDesignation?.id,
      'is_previous_employee': isPreviousEmployee,
      'previous_employee_id': previousEmployeeIdController.text,
      'employee_name': employeeNameController.text,
      'gender': isMale ? 'M' : 'F',
      'dateofbirth': dateOfBirthController.text,
      'placeofbirth': placeOfBirthController.text,
      'nationality': nationalityController.text,
      'aadhaar_number': aadhaarNumberController.text,
      'UAN_number': uanNumberController.text,
      'account_number': accountNumberController.text,
      'license_number': licenseNumberController.text,
      'father_name': fatherNameController.text,
      'mother_name': motherNameController.text,
      'maritalstatus': selectedMaritalStatus,
      'spousename': spouseNameController.text,
      'nominee1_name': nominee1NameController.text,
      'nominee1_relationship': nominee1RelationshipController.text,
      'nominee2_name': nominee2NameController.text,
      'nominee2_relationship': nominee2RelationshipController.text,
      'contact_no': contactNoController.text,
      'contact_address': contactAddressController.text,
      'residential_address': residentialAddressController.text,
      'email': emailController.text,
      'bloodgroup': selectedBloodGroup,
    };

    print('Employee Data to Submit: $employeeData');


    try {
      final prefs = await SharedPreferences.getInstance();
      username = prefs.getString('username');
      password = prefs.getString('password');
      print('Employee usernamme: $username');
      print('Employee password: $password');
      if (username == null || password == null) {
        _showError("Missing credentials. Please log in again.");
        return;
      }

      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      final response = await http.post(
        Uri.parse("$baseUrl/hr/drf_request_emp_addition"),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
        body: jsonEncode(employeeData), // ✅ sending data here
      );
      print('response.statusCode');
      print("$baseUrl/hr/drf_request_emp_addition/");
      print(response.statusCode);
      print(response.body);

      final result = jsonDecode(response.body);


      if (response.statusCode == 200) {
        print("Success: $result");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmployeeDetailsPage(),
          ),
        );
      } else if (response.statusCode == 400) {
        _showError(result['error'] ?? "Invalid request.");
      } else {
        _showError(result['error'] ?? "Invalid request.");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (){
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text(
            'Add Employee',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: Form(
              key: _formKey,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 3,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Basic Information'),

                        // Project Dropdown
                        _buildProjectDropdown(),

                        // Zone (Display only - from API)
                        _buildZoneDisplay(),

                        // Ward Dropdown
                        _buildWardDropdown(),

                        // Designation Dropdown
                        _buildDesignationDropdown(),

                        _buildSectionHeader('Employment Details'),
                        Row(
                          children: [
                        CheckboxTheme(
                        data: CheckboxThemeData(
                        side: BorderSide(color: Colors.grey, width: 2), // inactive border
                  ),
                  child: Checkbox(
                    value: isPreviousEmployee,
                    onChanged: (value) =>
                        setState(() => isPreviousEmployee = value!),
                  ),
                ),


                Text('Is Previous Employee', style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),),
                          ],
                        ),
                        if (isPreviousEmployee)
                          _buildTextFormField(
                            'Previous Employee ID',
                            previousEmployeeIdController,
                            TextInputType.text,
                          ),

                        _buildSectionHeader('Personal Information'),
                        _buildTextFormField(
                          'Employee Name',
                          employeeNameController,
                          TextInputType.text,
                          isRequired: true,
                        ),

                        // Gender Selection
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Gender *',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        RadioTheme(
                          data: RadioThemeData(
                            fillColor: MaterialStateColor.resolveWith((states) {
                              if (states.contains(MaterialState.selected)) {
                                return Colors.blue; // Active color
                              }
                              return Colors.grey; // Inactive border color
                            }),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: Text(
                                    'Male',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  value: true,
                                  groupValue: isMale,
                                  onChanged: (value) => setState(() => isMale = value!),
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: Text(
                                    'Female',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  value: false,
                                  groupValue: isMale,
                                  onChanged: (value) => setState(() => isMale = value!),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Date of Birth
                        _buildDatePickerField(
                          'Date of Birth',
                          dateOfBirthController,
                          Icons.calendar_today,
                        ),

                        _buildTextFormField(
                          'Place of Birth',
                          placeOfBirthController,
                          TextInputType.text,
                        ),
                        _buildTextFormField(
                          'Nationality',
                          nationalityController,
                          TextInputType.text,
                        ),
                        _buildTextFormField(
                          'Aadhaar Number',
                          aadhaarNumberController,
                          TextInputType.number,
                          isRequired: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12), // 12 digits + 2 spaces

                          ],
                          customValidator: (value) {
                            if (value == null || value.isEmpty) return 'Aadhaar Number is required';
                            if (!RegExp(r'^\d{12}$').hasMatch(value)) {
                              return 'Enter a valid 12-digit Aadhaar Number';
                            }
                            return null;
                          },
                        ),
                        _buildTextFormField(
                          'UAN Number',
                          uanNumberController,
                          TextInputType.number,
                          isRequired: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,          // Allow only digits
                            LengthLimitingTextInputFormatter(12),            // UAN is 12 digits
                          ],
                         /* customValidator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'UAN Number is required';
                            }
                            if (!RegExp(r'^[0-9]{12}$').hasMatch(value)) {
                              return 'Enter a valid 12-digit UAN Number';
                            }
                            return null;
                          },*/
                        ),

                        _buildTextFormField(
                          'Account Number',
                          accountNumberController,
                          TextInputType.number,
                          isRequired: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,         // Only digits
                            LengthLimitingTextInputFormatter(18),           // Max length 18
                          ],
                         /* customValidator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Account Number is required';
                            }
                            if (!RegExp(r'^\d{9,18}$').hasMatch(value)) {
                              return 'Enter a valid Account Number';
                            }
                            return null;
                          },*/
                        ),

                        _buildTextFormField(
                          'License Number',
                          licenseNumberController,
                          TextInputType.text,
                          inputFormatters: [

                            LengthLimitingTextInputFormatter(16),
                          ],
                         /* customValidator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (!RegExp(r'^[A-Z]{2}\d{2}\s?\d{4}\d{7}$').hasMatch(value)) {
                                return 'Enter a valid License Number (e.g. TN12 20120012345)';
                              }
                            }
                            return null;
                          },*/
                        ),

                        _buildSectionHeader('Family Information'),
                        _buildTextFormField(
                          'Father Name',
                          fatherNameController,
                          TextInputType.text,
                        ),
                        _buildTextFormField(
                          'Mother Name',
                          motherNameController,
                          TextInputType.text,
                        ),

                        // Marital Status Dropdown
                        _buildMaritalStatusDropdown(),

                        if (selectedMaritalStatus == 'Married')
                          _buildTextFormField(
                            'Spouse Name',
                            spouseNameController,
                            TextInputType.text,
                          ),

                        _buildSectionHeader('Nominee Information'),
                        _buildTextFormField(
                          'Nominee 1 Name',
                          nominee1NameController,
                          TextInputType.text,
                        ),
                        _buildTextFormField(
                          'Nominee 1 Relationship',
                          nominee1RelationshipController,
                          TextInputType.text,
                        ),
                        _buildTextFormField(
                          'Nominee 2 Name',
                          nominee2NameController,
                          TextInputType.text,
                        ),
                        _buildTextFormField(
                          'Nominee 2 Relationship',
                          nominee2RelationshipController,
                          TextInputType.text,
                        ),

                        _buildSectionHeader('Contact Information'),
                        _buildTextFormField(
                          'Contact Number',
                          contactNoController,
                          TextInputType.phone,
                        ),
                        _buildTextFormField(
                          'Contact Address',
                          contactAddressController,
                          TextInputType.multiline,
                          maxLines: 3,
                        ),
                        _buildTextFormField(
                          'Residential Address',
                          residentialAddressController,
                          TextInputType.multiline,
                          maxLines: 3,
                        ),
                        _buildTextFormField(
                          'Email',
                          emailController,
                          TextInputType.emailAddress,
                        ),

                        _buildSectionHeader('Medical Information'),
                        _buildBloodGroupDropdown(),

                        const SizedBox(height: 20),
                        _buildSubmitButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildProjectDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            'Project *',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: DropdownButton<Project>(
                value: selectedProject,
                items: projects.map((Project project) {
                  return DropdownMenuItem<Project>(
                    value: project,
                    child: Text(
                      project.name,
                      style: const TextStyle(fontSize: 14,color: Colors.grey),
                    ),
                  );
                }).toList(),
                onChanged: (Project? newValue) {
                  setState(() {
                    selectedProject = newValue;
                  });
                },
                isExpanded: true,
                hint: const Text(
                  'Select Project',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                underline: const SizedBox(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneDisplay() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            'Zone *',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              widget.dropdownData.zone.zoneCode,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            'Ward *',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: DropdownButton<Ward>(
                value: selectedWard,
                items: wards.map((Ward ward) {
                  return DropdownMenuItem<Ward>(
                    value: ward,
                    child: Text(
                      ward.wardCode,
                      style: const TextStyle(fontSize: 14,color: Colors.grey),
                    ),
                  );
                }).toList(),
                onChanged: (Ward? newValue) {
                  setState(() {
                    selectedWard = newValue;
                  });
                },
                isExpanded: true,
                hint: const Text(
                  'Select Ward',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                underline: const SizedBox(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignationDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            'Designation',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: DropdownButton<Designation>(
                value: selectedDesignation,
                items: designations.map((Designation designation) {
                  return DropdownMenuItem<Designation>(
                    value: designation,
                    child: Text(
                      designation.designationName,
                      style: const TextStyle(fontSize: 14,color: Colors.grey),
                    ),
                  );
                }).toList(),
                onChanged: (Designation? newValue) {
                  setState(() {
                    selectedDesignation = newValue;
                    print('selectedDesignation');
                    print(selectedDesignation?.id);
                  });
                },
                isExpanded: true,
                hint: const Text(
                  'Select Designation',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                underline: const SizedBox(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaritalStatusDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Marital Status',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: DropdownButton<String>(
                value: selectedMaritalStatus,
                items: maritalStatusChoices.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 14,color: Colors.grey),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedMaritalStatus = newValue;
                  });
                },
                isExpanded: true,
                hint: const Text(
                  'Select Marital Status',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                underline: const SizedBox(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodGroupDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blood Group',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: DropdownButton<String>(
                value: selectedBloodGroup,
                items: bloodGroups.map((String bloodGroup) {
                  return DropdownMenuItem<String>(
                    value: bloodGroup,
                    child: Text(
                      bloodGroup,
                      style: const TextStyle(fontSize: 14,color: Colors.grey),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedBloodGroup = newValue;
                  });
                },
                isExpanded: true,
                hint: const Text(
                  'Select Blood Group',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                underline: const SizedBox(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormField(
      String label,
      TextEditingController controller,
      TextInputType keyboardType, {
        bool isRequired = false,
        int maxLines = 1,
        String? Function(String?)? customValidator,
        List<TextInputFormatter>? inputFormatters, // 👈 new
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label${isRequired ? ' *' : ''}',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            inputFormatters: inputFormatters, // 👈 new
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (value) {
              if (customValidator != null) return customValidator(value);
              if (isRequired && (value == null || value.isEmpty)) {
                return 'This field is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }



  Widget _buildDatePickerField(
      String label,
      TextEditingController controller,
      IconData icon,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(
              color: Colors.grey, // 👈 This sets the typed text color
              fontSize: 16,        // (optional) control font size
              fontWeight: FontWeight.w400, // (optional) control weight
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              suffixIcon: IconButton(
                icon: Icon(icon, color: Colors.blue),
                onPressed: () => _selectDate(context),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            /*validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select date';
              }
              return null;
            },*/
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        child:  isLoading
            ? const Center(child: CircularProgressIndicator(
          color: Colors.white,
        )): Text(
          'Add Employee',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}