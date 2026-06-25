import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/components/drawer_page.dart';
import 'package:ourlandnew/config.dart';
import 'package:ourlandnew/pages/login.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'add_operation.dart';
import 'add_second_image.dart';
import 'add_third_image.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

class OperationListBuilder extends StatefulWidget {
  final List operationList;
  const OperationListBuilder({super.key, required this.operationList});

  @override
  State<OperationListBuilder> createState() => _OperationListBuilderState();
}

class _OperationListBuilderState extends State<OperationListBuilder> with SingleTickerProviderStateMixin {
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
      itemCount: widget.operationList.length,
      itemBuilder: (context, index) {
        final operation = widget.operationList[index];
        final hasSecondAttendance = operation['attendance_second_time'] != null;
        final hasThirdAttendance = operation['attendance_third_time'] != null;

        return Slidable(
          key: Key(operation['id'].toString()),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              if (!hasSecondAttendance)
                SlidableAction(
                  onPressed: (_) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => add_second_image(secondImgId: operation['id']),
                    ),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  icon: Icons.looks_two_rounded,
                ),
              if (hasSecondAttendance&&!hasThirdAttendance)
                SlidableAction(
                  onPressed: (_) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => add_third_image(secondImgId: operation['id']),
                    ),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  icon: Icons.looks_3_rounded,
                ),
            ],
          ),
          child: Card(
            elevation: 5,
            child: ListTile(
              title: Text(
                "${operation['ward_code']}",
                style: TextStyle(
                  color: hasSecondAttendance && hasThirdAttendance
                      ? Colors.grey
                      : null,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /* Your other subtitle widgets */
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class OperationPage extends StatefulWidget {
  const OperationPage({super.key});

  @override
  State<OperationPage> createState() => _OperationPageState();
}

class _OperationPageState extends State<OperationPage> {
  bool isLoggedIn = false;
  bool isLoading = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List operationList = [];
  String title = "Operations";

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  void checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("menu", "operations");
    String? user = prefs.getString('username');
    String? pass = prefs.getString('password');
    if (user != null && pass != null) {
      setState(() {
        isLoggedIn = true;
        username = user;
        password = pass;
      });
    }
    await getOperationList();
  }

  Future<void> getOperationList({bool value = true}) async {
    setState(() {
      isLoading = true;
    });

    var uri = Uri.parse("$baseUrl/drf-readall-opim");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        setState(() {
          print('uri_check');
          print(uri);
          print(response.body);
          operationList = jsonDecode(response.body);
        });
      } else {
        errorMsg("Failed to load operations: ${response.statusCode}");
      }
    } catch (e) {
      errorMsg("Error: $e");
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
          actions: const [NotificationBellWidget()],
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
            onRefresh: getOperationList,
            child: OperationListBuilder(operationList: operationList),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddOperationPage()),
            ).then((_) => getOperationList());
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}