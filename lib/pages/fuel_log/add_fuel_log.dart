import "dart:convert";
import "dart:io";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:ourlandnew/components/buttons.dart";
import "package:ourlandnew/components/input_fields.dart";
import "package:ourlandnew/components/label.dart";
import "package:ourlandnew/config.dart";
import 'package:ourlandnew/services/http_client.dart' as http;
import "package:ourlandnew/pages/login.dart";

import "fuel_alert_dialog.dart";
import "last_fueling_detail.dart";
import 'package:dropdown_search/dropdown_search.dart';

import "../../components/image_picker.dart";

class AddFuelLog extends StatefulWidget {
  const AddFuelLog({super.key});

  @override
  State<AddFuelLog> createState() => _AddFuelLogState();
}

class _AddFuelLogState extends State<AddFuelLog> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  bool isLoadingLastFuel = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List vehicles = [];
  List fuelStations = [];
  Map vehicleAndFuelStations = {};

  // Controllers
  TextEditingController odoReadingController = TextEditingController();
  TextEditingController fuelQuantityController = TextEditingController();
  TextEditingController fuelUnitCostController = TextEditingController();
  TextEditingController remarkController = TextEditingController();
  TextEditingController beforeImageController = TextEditingController();
  TextEditingController indentImageController = TextEditingController();

  // Read-only controllers for last fuel details
  TextEditingController lastOdoReadingController = TextEditingController();
  TextEditingController lastFuelDateController = TextEditingController();
  TextEditingController lastFuelTimeController = TextEditingController();
  TextEditingController lastFuelQuantityController = TextEditingController();
  TextEditingController lastMileageController = TextEditingController();
  TextEditingController mileageStatusController = TextEditingController();
  TextEditingController fuelFreqController = TextEditingController();

  int? vehicle;
  int? fuelStation;
  String? fuelType = "P";

  LastFuelingDetail lastFuelDetails = LastFuelingDetail.empty;

  /// Maps a grid key to its read-only controller. Keeps the layout list above
  /// declarative without repeating 40 lines of decoration per field.
  TextEditingController _lastFuelController(String key) {
    switch (key) {
      case 'odo':
        return lastOdoReadingController;
      case 'date':
        return lastFuelDateController;
      case 'time':
        return lastFuelTimeController;
      case 'qty':
        return lastFuelQuantityController;
      case 'mileage':
        return lastMileageController;
      case 'mileageStatus':
        return mileageStatusController;
      default:
        return fuelFreqController;
    }
  }

  /// One read-only detail field, styled exactly as the original hand-written
  /// ones were (grey fill, 8 px radius, dense padding).
  Widget _lastFuelField(String label, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        TextFormField(
          controller: _lastFuelController(key),
          enabled: false,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w500, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  /// Lays [fields] out as `[label, key]` pairs: two per row when there is room,
  /// one per row when there is not. The breakpoint scales with the user's text
  /// size, so a large font falls back to a single column instead of squeezing.
  Widget _lastFuelGrid(List<List<String>> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final twoUp = constraints.maxWidth >= 260 * textScale;
        const gap = 10.0;
        final width = twoUp ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;

        return Wrap(
          spacing: gap,
          runSpacing: 8,
          children: [
            for (final f in fields)
              SizedBox(
                width: width,
                child: _lastFuelField(f[0], f[1]),
              ),
          ],
        );
      },
    );
  }

  /// Pushes [lastFuelDetails] into the read-only fields. Called from inside
  /// setState on every outcome — success, non-200 and exception — so the panel
  /// can never keep showing a previous vehicle's figures.
  void _applyLastFuelDetails() {
    lastOdoReadingController.text = lastFuelDetails.odoReadingDisplay;
    lastFuelDateController.text = lastFuelDetails.fuelDateDisplay;
    lastFuelTimeController.text = lastFuelDetails.fuelTimeDisplay;
    lastFuelQuantityController.text = lastFuelDetails.fuelQuantityDisplay;
    lastMileageController.text = lastFuelDetails.mileageDisplay;
    mileageStatusController.text = lastFuelDetails.mileageStatusDisplay;
    fuelFreqController.text = lastFuelDetails.fuelFreqDisplay;
  }

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> getLastFuelingDetails(int vehicleId) async {
    setState(() {
      isLoadingLastFuel = true;
    });

    try {
      var uri = Uri.parse(
          "$baseUrl/drf_get_last_fueling_detail/?vehicle_id=$vehicleId");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      var headers = {
        'Content-Type': 'application/json',
        'authorization': auth
      };

      var response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          // A payload that is not a JSON object still yields the empty detail
          // rather than throwing.
          lastFuelDetails = decoded is Map<String, dynamic>
              ? LastFuelingDetail.fromJson(decoded)
              : LastFuelingDetail.empty;
          _applyLastFuelDetails();
        });
      } else {
        setState(() {
          lastFuelDetails = LastFuelingDetail.empty;
          _applyLastFuelDetails();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Could not fetch last fueling details'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        lastFuelDetails = LastFuelingDetail.empty;
        _applyLastFuelDetails();
      });
    } finally {
      setState(() {
        isLoadingLastFuel = false;
      });
    }
  }

  Future<http.Response> createFuelLogMultipart(
      Map<String, dynamic> data,
      Map<String, dynamic> images,
      ) async {
    try {
      var uri = Uri.parse("$baseUrl/drf-add-fuel-log/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      var request = http.MultipartRequest('POST', uri)
        ..headers['authorization'] = auth;

      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      for (var entry in images.entries) {
        if (entry.value != null && entry.value.toString().isNotEmpty) {
          request.files.add(
            await http.MultipartFile.fromPath(entry.key, entry.value),
          );
        }
      }

      var streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    } catch (e) {
      errorMsg(e.toString());
      return http.Response("Error", 500);
    }
  }

  void addFuelLog() async {
    setState(() {
      isLoading = true;
    });

    String odoReading = odoReadingController.text;
    String fuelQuantity = fuelQuantityController.text;
    String fuelUnitCost = fuelUnitCostController.text;
    String remark = remarkController.text;

    if (vehicle == null ||
        fuelStation == null ||
        odoReading.isEmpty ||
        fuelQuantity.isEmpty ||
        fuelUnitCost.isEmpty ||
        beforeImageController.text.isEmpty) {
      errorMsg("Required * fields cannot be empty");
      setState(() {
        isLoading = false;
      });
    } else {
      // The backend flagged a warning for this vehicle. Gate the save on an
      // explicit acknowledgement — advisory, not a validation failure, so the
      // user can always continue.
      if (lastFuelDetails.shouldWarn) {
        final proceed = await showFuelAlertDialog(context, lastFuelDetails);
        if (!mounted) return;
        if (!proceed) {
          // Cancelled or dismissed — return to the form with nothing submitted.
          setState(() {
            isLoading = false;
          });
          return;
        }
      }

      final Map<String, dynamic> data = {
        "vehicle": vehicle,
        "fuel_station": fuelStation,
        "fuel_type": fuelType,
        "odo_reading": odoReading,
        "fuel_quantity": fuelQuantity,
        "fuel_unit_cost": fuelUnitCost,
        "remark": remark,
        // Posted exactly as the detail endpoint returned it — never generated
        // or reworded here. Omitted entirely when there was no warning.
        if (lastFuelDetails.alertMessageForSubmission != null)
          "alert_message": lastFuelDetails.alertMessageForSubmission,
      };

      final Map<String, dynamic> images = {
        "before_image": beforeImageController.text,
        "indent_image": indentImageController.text,
      };

      try {
        var response = await createFuelLogMultipart(data, images);

        if (response.statusCode == 200 || response.statusCode == 201) {
          successMsg('Fuel Log created successfully');
          Navigator.pop(context);
          Navigator.pushNamed(context, '/fuel_log_list');
        } else {
          String errorMessage = 'Failed to create fuel log';
          try {
            final errorResponse = jsonDecode(response.body);
            if (errorResponse is Map) {
              if (errorResponse.containsKey('error')) {
                errorMessage = errorResponse['error'].toString();
              } else if (errorResponse.containsKey('message')) {
                errorMessage = errorResponse['message'].toString();
              } else if (errorResponse.containsKey('detail')) {
                errorMessage = errorResponse['detail'].toString();
              }
            } else if (errorResponse is String) {
              errorMessage = errorResponse;
            }
          } catch (e) {
            errorMessage =
            'Error ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
          }

          errorMsg(errorMessage);
        }
      } catch (e) {
        errorMsg('Network error: ${e.toString()}');
        print('Exception in addFuelLog: $e');
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> getDropDownValues() async {
    setState(() {
      vehicles = [];
      odoReadingController.text = "0.0";
      fuelQuantityController.text = "1";
      fuelUnitCostController.text = "92.5";
    });

    var vehicleFuelUri = Uri.parse("$baseUrl/drf-add-fuel-log/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var fuelStationResponse = await http.get(vehicleFuelUri, headers: headers);

      if (fuelStationResponse.statusCode == 200) {
        setState(() {
          vehicleAndFuelStations = jsonDecode(fuelStationResponse.body);
          vehicles = vehicleAndFuelStations['vehicle_list'];
          fuelStations = vehicleAndFuelStations['fuelstation_list'];
        });
      }
    } catch (_) {
      // Already logged by the HTTP client; the dropdowns stay empty.
    }
  }

  void checkLoginStatus() async {
    setState(() {
      isStarting = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("menu", "vehicles");
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

  void errorMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ),
    );
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
            title: const Text("Add Fuel Log"),
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

                // ── v7 DropdownSearch ──────────────────────────────
                DropdownSearch<String>(
                  // v7: decoratorProps replaces dropdownDecoratorProps
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10),
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    // v7: itemBuilder has 4 params (added isHighlighted)
                    itemBuilder:
                        (context, item, isSelected, isHighlighted) {
                      return ListTile(
                        title: Text(
                          vehicles
                              .firstWhere(
                                (dynamic element) =>
                            element['id'].toString() == item,
                            orElse: () =>
                            {'vehicle_number': 'Unknown'},
                          )['vehicle_number']
                              .toString(),
                        ),
                      );
                    },
                  ),
                  // v7: items is now a function, not a plain List
                  items: (filter, loadProps) => vehicles
                      .map<String>(
                          (dynamic value) => value['id'].toString())
                      .toList(),
                  itemAsString: (String item) {
                    return vehicles
                        .firstWhere(
                          (dynamic element) =>
                      element['id'].toString() == item,
                      orElse: () => {'vehicle_number': ''},
                    )['vehicle_number']
                        .toString();
                  },
                  // v7: onChanged renamed to onSelected
                  onSelected: (String? value) {
                    if (value == null) return;
                    setState(() {
                      vehicle = int.parse(value);
                    });
                    getLastFuelingDetails(vehicle!);
                  },
                  selectedItem: vehicle?.toString(),
                  dropdownBuilder: (context, selectedItem) {
                    return Text(
                      vehicles
                          .firstWhere(
                            (dynamic item) =>
                        item['id'].toString() == selectedItem,
                        orElse: () =>
                        {'vehicle_number': 'Select a vehicle'},
                      )['vehicle_number']
                          .toString(),
                    );
                  },
                ),
                // ──────────────────────────────────────────────────

                const SizedBox(height: 10),

                // LAST FUEL DETAILS SECTION
                if (vehicle != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history,
                                size: 20,
                                color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Last Fueling Details',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            if (isLoadingLastFuel) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Every field the detail endpoint returns, laid out two
                        // per row on a phone and wider viewports alike, dropping
                        // to one per row when there is not enough width — so a
                        // long value or a large text scale cannot overflow.
                        _lastFuelGrid(const [
                          ['Last ODO Reading', 'odo'],
                          ['Last Fuel Date', 'date'],
                          ['Last Fuel Time', 'time'],
                          ['Last Fuel Qty', 'qty'],
                          ['Mileage', 'mileage'],
                          ['Mileage Status', 'mileageStatus'],
                          ['Fuel Frequency', 'fuelFreq'],
                        ]),
                        FuelAlertBanner(detail: lastFuelDetails),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // FUEL STATION
                const LabelText(text: "Fuel Station*"),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  items: fuelStations
                      .map<DropdownMenuItem<String>>((dynamic value) {
                    return DropdownMenuItem<String>(
                      value: value['id'].toString(),
                      child: Text(value['name'].toString()),
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
                      fuelStation = int.parse(value.toString());
                    });
                  },
                ),
                const SizedBox(height: 10),

                // FUEL TYPE
                const LabelText(text: "Fuel Type*"),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  value: fuelType,
                  items: [
                    ['P', 'Petrol'],
                    ['D', 'Diesel'],
                    ['G', 'Gas'],
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
                      fuelType = value;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // ODO READING
                const LabelText(text: "Odo Reading*"),
                const SizedBox(height: 5),
                NumberField(
                  controller: odoReadingController,
                  padding: 10,
                ),
                const SizedBox(height: 10),

                // FUEL QUANTITY
                const LabelText(text: "Fuel Quantity*"),
                const SizedBox(height: 5),
                NumberField(
                  controller: fuelQuantityController,
                  padding: 10,
                ),
                const SizedBox(height: 10),

                // FUEL UNIT COST
                const LabelText(text: "Fuel Unit Cost*"),
                const SizedBox(height: 5),
                NumberField(
                  controller: fuelUnitCostController,
                  padding: 10,
                ),
                const SizedBox(height: 10),

                // BEFORE IMAGE
                const LabelText(text: "Before Image*"),
                const SizedBox(height: 5),
                _buildImagePreview(
                    beforeImageController.text, 'Before Image'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Spacer(),
                    CameraImagePicker(
                      text: 'Upload Before Image',
                      onImagePicked: (file) {
                        setState(() {
                          beforeImageController.text = file.path;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // INDENT IMAGE
                const LabelText(text: "Indent Image"),
                const SizedBox(height: 5),
                _buildImagePreview(
                    indentImageController.text, 'Indent Image'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Spacer(),
                    CameraImagePicker(
                      text: 'Upload Indent Image',
                      onImagePicked: (file) {
                        setState(() {
                          indentImageController.text = file.path;
                        });
                      },
                    ),
                  ],
                ),

                // REMARK
                const LabelText(text: "Remark"),
                const SizedBox(height: 5),
                TextAreaField(
                  controller: remarkController,
                  padding: 10,
                ),

                const SizedBox(height: 20),
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : PrimaryButton(
                    text: "Submit", onPressed: addFuelLog),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(String imagePath, String placeholderText) {
    if (imagePath.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '$placeholderText Not Uploaded',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    try {
      File imageFile = File(imagePath);
      if (imageFile.existsSync()) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(imageFile, fit: BoxFit.cover),
          ),
        );
      } else {
        return _buildErrorWidget('Image file not found');
      }
    } catch (e) {
      return _buildErrorWidget('Error loading image');
    }
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(message, style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}