import "dart:convert";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:ourlandnew/components/buttons.dart";
import "package:ourlandnew/components/input_fields.dart";
import "package:ourlandnew/components/label.dart";
import "package:ourlandnew/config.dart";
import 'package:http/http.dart' as http;
import "package:ourlandnew/pages/login.dart";
import 'package:dropdown_search/dropdown_search.dart';

class AddJobCardDetail extends StatefulWidget {
  const AddJobCardDetail({super.key});

  @override
  State<AddJobCardDetail> createState() => _AddJobCardDetailState();
}

class _AddJobCardDetailState extends State<AddJobCardDetail> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  Map vehicleAndWorkshop = {};
  List vehiclesList = [];
  List workShopsList = [];
  TextEditingController workController = TextEditingController();
  TextEditingController remarkController = TextEditingController();
  int? vehicle;
  int? workShop;

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<http.Response> createJobCard(String body) async {
    var uri = Uri.parse("$baseUrl/drf-add-job-card/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    var response = await http.post(uri, headers: headers, body: body);
    return response;
  }

  void addJobCard() async {
    setState(() {
      isLoading = true;
    });
    String? work = workController.text;
    String? remark = remarkController.text;

    if (vehicle == null ||
        workShop == null || work.isEmpty) {
      errorMsg("Required * fields cannot be null");
    } else {
      var body = {
        "vehicle": int.parse(vehicle.toString()),
        "workshop": int.parse(workShop.toString()),
        "work": work,
        "work_assignee_remark": remark
      };

      var response = await createJobCard(jsonEncode(body));
      if (response.statusCode == 200) {
        successMsg('job card created successfully');
        Navigator.pop(context);
        Navigator.pushNamed(context, '/job_card_list');
      } else {
        print(response.body);
        errorMsg("Unable to create Job Card");
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> getDropDownValues() async {
    setState(() {
      vehiclesList = [];
      workShopsList = [];
    });
    var vehicleWorkshopUri = Uri.parse("$baseUrl/drf-add-job-card/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var vehicleWorkshopResponse = await http.get(
        vehicleWorkshopUri,
        headers: headers,
      );
      if (vehicleWorkshopResponse.statusCode == 200) {
        setState(() {
          vehicleAndWorkshop = jsonDecode(vehicleWorkshopResponse.body);
          vehiclesList = vehicleAndWorkshop['vehicles'];
          workShopsList = vehicleAndWorkshop['workshops'];
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
    await prefs.setString("menu", "job_card");
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

  void successMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ),
    );
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
              title: const Text("Add Job Card"),
            ),
            body: Card(
              margin: const EdgeInsets.all(15),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 10,
                ),
                children: [
                  // VEHICLE
                  const LabelText(text: "Vehicle*"),
                  const SizedBox(height: 5),
                  DropdownSearch<String>(
                    items: (filter, infiniteScrollProps) {
                      return vehiclesList
                          .map<String>((e) => e['id'].toString())
                          .toList();
                    },

                    selectedItem: vehicle?.toString(),

                    onSelected: (value) {
                      setState(() {
                        vehicle = int.tryParse(value ?? '');
                      });
                    },

                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    popupProps: PopupProps.menu(
                      showSearchBox: true,

                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Search Vehicles',
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      itemBuilder: (context, item, isDisabled, isSelected) {
                        final vehicleData = vehiclesList.firstWhere(
                              (e) => e['id'].toString() == item,
                          orElse: () => {'vehicle_number': 'Unknown'},
                        );

                        return ListTile(
                          title: Text(vehicleData['vehicle_number']),
                        );
                      },
                    ),

                    itemAsString: (item) {
                      final vehicleData = vehiclesList.firstWhere(
                            (e) => e['id'].toString() == item,
                        orElse: () => {'vehicle_number': ''},
                      );
                      return vehicleData['vehicle_number'];
                    },
                  ),
                  const SizedBox(height: 10),

                  // WORKSHOP
                  const LabelText(text: "WorkShop*"),
                  const SizedBox(height: 5),
                  DropdownSearch<String>(
                    items: (filter, infiniteScrollProps) {
                      return workShopsList
                          .map<String>((e) => e['id'].toString())
                          .toList();
                    },

                    selectedItem: workShop?.toString(),

                    onSelected: (value) {
                      setState(() {
                        workShop = int.tryParse(value ?? '');
                      });
                    },

                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    popupProps: PopupProps.menu(
                      showSearchBox: true,

                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Search Workshops',
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      itemBuilder: (context, item, isDisabled, isSelected) {
                        final workshopData = workShopsList.firstWhere(
                              (e) => e['id'].toString() == item,
                          orElse: () => {'workshop_name': 'Unknown'},
                        );

                        return ListTile(
                          title: Text(workshopData['workshop_name']),
                        );
                      },
                    ),

                    itemAsString: (item) {
                      final workshopData = workShopsList.firstWhere(
                            (e) => e['id'].toString() == item,
                        orElse: () => {'workshop_name': ''},
                      );
                      return workshopData['workshop_name'];
                    },
                  ),
                  const SizedBox(height: 10),

                  // WORK
                  const LabelText(text: "Work*"),
                  const SizedBox(height: 5),
                  BasicInputField(
                    controller: workController,
                    padding: 10,
                  ),
                  const SizedBox(height: 10),

                  // REMARK
                  const LabelText(text: "Work Assignee Remark"),
                  const SizedBox(height: 5),
                  TextAreaField(
                    controller: remarkController,
                    padding: 10,
                  ),

                  const SizedBox(height: 20),
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : PrimaryButton(
                      text: "Submit", onPressed: addJobCard)
                ],
              ),
            ),
          )),
    );
  }
}
