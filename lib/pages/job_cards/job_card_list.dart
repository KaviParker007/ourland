import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/config.dart';
import 'package:ourlandnew/pages/job_cards/request_spare.dart';
import 'package:ourlandnew/pages/job_cards/start_job_card.dart';
import 'package:ourlandnew/pages/login.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'add_job_card_detail.dart';
import 'approve_spare.dart';
import 'cancel_job_card.dart';
import 'end_job_card.dart';
import 'job_card_full_details_view.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

class JobCardListBuilder extends StatefulWidget {
  final List jobCard;
  const JobCardListBuilder({super.key, required this.jobCard});

  @override
  State<JobCardListBuilder> createState() => _VehiclesListBuilderState();
}

class _VehiclesListBuilderState extends State<JobCardListBuilder> with SingleTickerProviderStateMixin {
  late final controller = SlidableController(this);
  bool isLoading = false;

  void vehicleView(Map jobCardDetails) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => JobCardDetailsView(jobCardDetails: jobCardDetails)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: widget.jobCard.length,
            itemBuilder: (context, index) {
              final jobCardDetails = widget.jobCard[index];
              return Slidable(
                key: const ValueKey(0),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    if (jobCardDetails["status"].toString().toLowerCase() == "Assigned".toLowerCase() ||
                        jobCardDetails["status"].toString().toLowerCase() == "Spare Allotted".toLowerCase())
                      SlidableAction(
                        onPressed: (_) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => StartJobCard(jobCardId: jobCardDetails['id'])),
                          );
                          controller.close();
                        },
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        icon: Icons.start,
                        label: 'Start',
                      ),
                    if (jobCardDetails["status"].toString().toLowerCase() == "Working".toLowerCase())
                      SlidableAction(
                        onPressed: (_) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => RequestSpare(jobCardId: jobCardDetails['id'])),
                          );
                          controller.close();
                        },
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        icon: Icons.request_page_rounded,
                        label: 'Request Spare',
                      ),
                    if (jobCardDetails["status"].toString().toLowerCase() == "Spare Requested".toLowerCase())
                      SlidableAction(
                        onPressed: (_) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ApproveSpare(jobCardId: jobCardDetails['id'])),
                          );
                          controller.close();
                        },
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        icon: Icons.approval_outlined,
                        label: 'Approve Spare',
                      ),
                    if (jobCardDetails["status"].toString().toLowerCase() == "Working".toLowerCase())
                      SlidableAction(
                        onPressed: (_) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => EndJobCard(jobCardId: jobCardDetails['id'])),
                          );
                          controller.close();
                        },
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        icon: Icons.stop,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        label: 'End',
                        // spacing: 8,
                      ),

                    SlidableAction(
                      onPressed: (_) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CancelJobCard(jobCardId: jobCardDetails['id'])),
                        );
                        controller.close();
                      },
                      backgroundColor: Theme.of(context).colorScheme.outline,
                      foregroundColor: Colors.black,
                      borderRadius: BorderRadius.circular(15),
                      icon: Icons.cancel,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      label: 'Cancel',
                      // spacing: 8,
                    )
                  ],
                ),
                child: Card(
                  child: ListTile(
                    title: Text(jobCardDetails['vehicle_number']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(jobCardDetails['work'] ?? ''),
                        Text(jobCardDetails['assigned_on'] ?? ''),
                        Text(jobCardDetails['status'] ?? ''),
                      ],
                    ),
                    onTap: () {
                      vehicleView(jobCardDetails);
                    },
                  ),
                ),
              );
            });
  }
}

class JobCardList extends StatefulWidget {
  const JobCardList({super.key});

  @override
  State<JobCardList> createState() => _VehiclesListState();
}

class _VehiclesListState extends State<JobCardList> {
  bool isLoggedIn = false;
  bool isLoading = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List jobCard = [];
  List filteredJobCard = []; // ✅ new list for filtered data

  bool isSearching = false; // ✅ toggles search bar
  TextEditingController searchController = TextEditingController(); // ✅ controller for search bar


  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> getJobCardList() async {
    setState(() {
      isLoading = true;
      jobCard = [];
      filteredJobCard = [];
    });

    var uri = Uri.parse("$baseUrl/drf-job-card-list/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        setState(() {
          jobCard = decoded;
          filteredJobCard = decoded; // ✅ Initialize filtered list
        });
      } else {
        errorMsg("500 - Server Error");
      }
    } catch (e) {
      errorMsg("Error - $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  void filterSearch(String query) {
    setState(() {
      filteredJobCard = jobCard
          .where((item) => item['vehicle_number']
          .toString()
          .toLowerCase()
          .contains(query.toLowerCase()))
          .toList();
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



  void checkLoginStatus() async {
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
    await getJobCardList();
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
                backgroundColor: Colors.transparent,
                title: isSearching
                    ? TextField(
                  controller: searchController,
                  decoration:  InputDecoration(
                    hintText: 'Search vehicle number...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Theme.of(context).hintColor),
                  ),
                  style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontSize: 16),

                  onChanged: filterSearch,
                  autofocus: true,
                )
                    : const Text("Job Card List"),
                actions: [
                  if (!isSearching) const NotificationBellWidget(),
                  IconButton(
                    icon: Icon(isSearching ? Icons.close : Icons.search),
                    onPressed: () {
                      setState(() {
                        if (isSearching) {
                          searchController.clear();
                          filteredJobCard = jobCard;
                        }
                        isSearching = !isSearching;
                      });
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
                  onRefresh: getJobCardList,
                  child: JobCardListBuilder(jobCard: filteredJobCard), // ✅ use filtered list
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddJobCardDetail()),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ),
          );
  }
}
