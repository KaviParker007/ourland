import "dart:convert";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:ourlandnew/components/buttons.dart";
import "package:ourlandnew/components/input_fields.dart";
import "package:ourlandnew/components/label.dart";
import "package:ourlandnew/config.dart";
import 'package:http/http.dart' as http;
import "package:ourlandnew/pages/login.dart";

class EndJobCard extends StatefulWidget {
  final int jobCardId;
  const EndJobCard({super.key, required this.jobCardId});

  @override
  State<EndJobCard> createState() => _EndJobCardState();
}

class _EndJobCardState extends State<EndJobCard> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  TextEditingController remarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<http.Response> endJobCard(String body) async {
    var uri = Uri.parse("$baseUrl/drf-end-job-card/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    var response = await http.post(uri, headers: headers, body: body);
    return response;
  }

  void addJobCard() async {
    setState(() {
      isLoading = true;
    });
    String? remark = remarkController.text;

    var body = {
      "id": widget.jobCardId,
      "vehicle_incharge_remark": remark
    };
    var response = await endJobCard(jsonEncode(body));
    if (response.statusCode == 200) {
      successMsg('job card ended successfully');
      Navigator.pop(context);
      Navigator.pushNamed(context, '/job_card_list');
    } else {
      print(response.body);
      errorMsg("Unable to end Job Card");
    }

    setState(() {
      isLoading = false;
    });
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
              title: const Text("End Job Card"),
            ),
            body: Card(
              margin: const EdgeInsets.all(15),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 10,
                ),
                children: [
                  const LabelText(text: "Vehicle Incharge Remark"),
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
