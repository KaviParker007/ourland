import "dart:io";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:ourlandnew/components/buttons.dart";
import "package:ourlandnew/components/input_fields.dart";
import "package:ourlandnew/components/label.dart";
import "package:ourlandnew/pages/login.dart";

import "fuel_alert_dialog.dart";
import "fuel_log_service.dart";
import "last_fueling_detail.dart";
import 'package:dropdown_search/dropdown_search.dart';

import "../../components/image_picker.dart";

/// Add Fuel Log (FuelMaster).
///
/// Flow: load the vehicle and fuel station lists → user picks a vehicle → load
/// its last fueling detail (prefills the tag number, shows mileage and any
/// warning) → user completes the form → if the detail carried an alert, the
/// warning dialog gates the save → multipart POST.
///
/// Pops with `true` after a successful save so the list can refresh.
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
  String? username;
  String? password;

  FuelLogService? service;
  List<FuelVehicle> vehicles = [];
  List<FuelStation> fuelStations = [];
  String? optionsError;

  // Controllers
  TextEditingController odoReadingController = TextEditingController();
  TextEditingController fuelQuantityController = TextEditingController();
  TextEditingController fuelUnitCostController = TextEditingController();
  TextEditingController tagNumberController = TextEditingController();
  TextEditingController remarkController = TextEditingController();
  TextEditingController beforeImageController = TextEditingController();
  TextEditingController indentImageController = TextEditingController();
  TextEditingController afterImageController = TextEditingController();

  // Read-only controllers for last fuel details
  TextEditingController lastOdoReadingController = TextEditingController();
  TextEditingController lastFuelDateController = TextEditingController();
  TextEditingController lastFuelTimeController = TextEditingController();
  TextEditingController lastFuelQuantityController = TextEditingController();
  TextEditingController lastMileageController = TextEditingController();
  TextEditingController mileageStatusController = TextEditingController();
  TextEditingController fuelFreqController = TextEditingController();
  TextEditingController lastTagNumberController = TextEditingController();

  int? vehicle;
  int? fuelStation;
  String? fuelType = "P";

  LastFuelingDetail lastFuelDetails = LastFuelingDetail.empty;

  /// Set when the detail call for the selected vehicle failed. Submission is
  /// held until it loads, since it decides whether the warning must be shown.
  String? lastFuelError;

  /// Whether [lastFuelDetails] belongs to the selected vehicle.
  bool lastFuelLoaded = false;

  FuelVehicle? get selectedVehicle {
    for (final v in vehicles) {
      if (v.id == vehicle) return v;
    }
    return null;
  }

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
      case 'tag':
        return lastTagNumberController;
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

  /// Pushes [lastFuelDetails] into the read-only fields and prefills the tag
  /// number. Called from inside setState on every outcome — success and
  /// failure — so the panel can never keep showing a previous vehicle's figures.
  void _applyLastFuelDetails() {
    lastOdoReadingController.text = lastFuelDetails.odoReadingDisplay;
    lastFuelDateController.text = lastFuelDetails.fuelDateDisplay;
    lastFuelTimeController.text = lastFuelDetails.fuelTimeDisplay;
    lastFuelQuantityController.text = lastFuelDetails.fuelQuantityDisplay;
    lastMileageController.text = lastFuelDetails.mileageDisplay;
    mileageStatusController.text = lastFuelDetails.mileageStatusDisplay;
    fuelFreqController.text = lastFuelDetails.fuelFreqDisplay;
    lastTagNumberController.text = lastFuelDetails.tagNumberDisplay;
    // Prefilled for review; it is only posted if the user changes it.
    tagNumberController.text = lastFuelDetails.tagNumber?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  @override
  void dispose() {
    for (final c in [
      odoReadingController,
      fuelQuantityController,
      fuelUnitCostController,
      tagNumberController,
      remarkController,
      beforeImageController,
      indentImageController,
      afterImageController,
      lastOdoReadingController,
      lastFuelDateController,
      lastFuelTimeController,
      lastFuelQuantityController,
      lastMileageController,
      mileageStatusController,
      fuelFreqController,
      lastTagNumberController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> getLastFuelingDetails(int vehicleId) async {
    setState(() {
      isLoadingLastFuel = true;
      lastFuelError = null;
      lastFuelLoaded = false;
      lastFuelDetails = LastFuelingDetail.empty;
      _applyLastFuelDetails();
    });

    try {
      final detail = await service!.fetchLastFuelingDetail(vehicleId);
      // Ignore a late answer for a vehicle the user has since changed.
      if (!mounted || vehicle != vehicleId) return;
      setState(() {
        lastFuelDetails = detail;
        lastFuelLoaded = true;
        _applyLastFuelDetails();
      });
    } on FuelLogApiException catch (e) {
      if (!mounted || vehicle != vehicleId) return;
      setState(() => lastFuelError = e.message);
    } finally {
      if (mounted && vehicle == vehicleId) {
        setState(() => isLoadingLastFuel = false);
      }
    }
  }

  void addFuelLog() async {
    // A second tap while a save is in flight must not post twice.
    if (isLoading) return;

    final validationError = validateFuelLogInput(
      vehicle: vehicle,
      fuelStation: fuelStation,
      fuelType: fuelType,
      odoReading: odoReadingController.text,
      fuelQuantity: fuelQuantityController.text,
      fuelUnitCost: fuelUnitCostController.text,
      tagNumber: tagNumberController.text,
      beforeImagePath: beforeImageController.text,
      lastDetail: lastFuelLoaded ? lastFuelDetails : null,
    );
    if (validationError != null) {
      errorMsg(validationError);
      return;
    }
    if (isLoadingLastFuel) {
      errorMsg("Please wait while the last fueling details load.");
      return;
    }
    if (!lastFuelLoaded) {
      errorMsg("Last fueling details could not be loaded. Tap Retry first.");
      return;
    }

    setState(() {
      isLoading = true;
    });

    // The backend flagged a warning for this vehicle. Gate the save on an
    // explicit acknowledgement — advisory, not a validation failure, so the
    // user can always continue.
    String? alertMessage;
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
      // Posted exactly as the detail endpoint returned it — never generated or
      // reworded here. Left null, and so omitted, when no warning was shown.
      alertMessage = lastFuelDetails.alertMessageForSubmission;
    }

    final submission = FuelLogSubmission(
      vehicle: vehicle!,
      fuelStation: fuelStation!,
      fuelType: fuelType!,
      odoReading: odoReadingController.text,
      fuelQuantity: fuelQuantityController.text,
      fuelUnitCost: fuelUnitCostController.text,
      tagNumber: tagNumberToSubmit(
          tagNumberController.text, lastFuelDetails.tagNumber),
      remark: remarkController.text,
      alertMessage: alertMessage,
      beforeImagePath: beforeImageController.text,
      indentImagePath: indentImageController.text,
      afterImagePath: afterImageController.text,
    );

    try {
      final message = await service!.submitFuelLog(submission);
      if (!mounted) return;
      successMsg(message ?? 'Fuel Log created successfully');
      Navigator.pop(context, true);
    } on FuelLogApiException catch (e) {
      if (!mounted) return;
      errorMsg(e.message);
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> getDropDownValues() async {
    setState(() {
      optionsError = null;
    });

    try {
      final options = await service!.fetchFormOptions();
      if (!mounted) return;
      setState(() {
        vehicles = options.vehicles;
        fuelStations = options.fuelStations;
        // Drop a selection the refreshed lists no longer offer.
        if (!fuelStations.any((s) => s.id == fuelStation)) fuelStation = null;
      });
    } on FuelLogApiException catch (e) {
      if (!mounted) return;
      setState(() => optionsError = e.message);
    }
  }

  Future<void> _retryOptions() async {
    setState(() => isStarting = true);
    await getDropDownValues();
    if (mounted) setState(() => isStarting = false);
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
        service = FuelLogService(username: user, password: pass);
      });
      await getDropDownValues();
    }

    if (!mounted) return;
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

  /// Shown in place of the form when the vehicle / fuel station lists failed.
  Widget _optionsErrorCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Icon(Icons.error_outline,
              size: 40, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 10),
          Text(
            "Could not load vehicles and fuel stations.\n$optionsError",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _retryOptions,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  /// Body of the Last Fueling Details panel: the grid, a first-fueling note, or
  /// an error with Retry.
  Widget _lastFuelBody() {
    if (lastFuelError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(lastFuelError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          TextButton(
            onPressed: () => getLastFuelingDetails(vehicle!),
            child: const Text("Retry"),
          ),
        ],
      );
    }
    if (lastFuelLoaded && lastFuelDetails.isFirstFueling) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No previous fueling found — this is the first fueling for this vehicle.',
            style: TextStyle(color: Colors.blue.shade900),
          ),
          FuelAlertBanner(detail: lastFuelDetails),
        ],
      );
    }
    return Column(
      children: [
        // Every field the detail endpoint returns, laid out two per row on a
        // phone and wider viewports alike, dropping to one per row when there
        // is not enough width — so a long value or a large text scale cannot
        // overflow.
        _lastFuelGrid(const [
          ['Last ODO Reading', 'odo'],
          ['Last Fuel Date', 'date'],
          ['Last Fuel Time', 'time'],
          ['Last Fuel Qty', 'qty'],
          ['Mileage', 'mileage'],
          ['Mileage Status', 'mileageStatus'],
          ['Fuel Frequency', 'fuelFreq'],
          ['Last Tag Number', 'tag'],
        ]),
        FuelAlertBanner(detail: lastFuelDetails),
      ],
    );
  }

  /// Picker + preview for one image field.
  List<Widget> _imageSection({
    required String label,
    required TextEditingController controller,
    required String buttonText,
  }) {
    return [
      LabelText(text: label),
      const SizedBox(height: 5),
      _buildImagePreview(controller.text, label.replaceAll('*', '')),
      const SizedBox(height: 10),
      Row(
        children: [
          const Spacer(),
          CameraImagePicker(
            text: buttonText,
            onImagePicked: (file) {
              setState(() {
                controller.text = file.path;
              });
            },
          ),
        ],
      ),
      const SizedBox(height: 10),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lastOdoHint = lastFuelLoaded && !lastFuelDetails.isFirstFueling
        ? 'Last reading: ${lastFuelDetails.odoReadingDisplay}'
        : null;
    final previousTag = lastFuelDetails.tagNumber;

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
              children: optionsError != null
                  ? [_optionsErrorCard()]
                  : [
                // VEHICLE
                const LabelText(text: "Vehicle*"),
                const SizedBox(height: 5),

                DropdownSearch<FuelVehicle>(
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
                    itemBuilder:
                        (context, item, isSelected, isHighlighted) {
                      return ListTile(title: Text(item.vehicleNumber));
                    },
                    emptyBuilder: (context, filter) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        filter.isEmpty
                            ? 'No vehicles available for your account.'
                            : 'No vehicles match "$filter"',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  items: (filter, loadProps) => vehicles,
                  itemAsString: (FuelVehicle v) => v.vehicleNumber,
                  compareFn: (a, b) => a.id == b.id,
                  onSelected: (FuelVehicle? value) {
                    // Re-picking the same vehicle does not refetch.
                    if (value == null || value.id == vehicle) return;
                    setState(() {
                      vehicle = value.id;
                    });
                    getLastFuelingDetails(value.id);
                  },
                  selectedItem: selectedVehicle,
                  dropdownBuilder: (context, selectedItem) {
                    return Text(
                        selectedItem?.vehicleNumber ?? 'Select a vehicle');
                  },
                ),

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
                        _lastFuelBody(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // FUEL STATION
                const LabelText(text: "Fuel Station*"),
                const SizedBox(height: 5),
                DropdownButtonFormField<int>(
                  initialValue: fuelStation,
                  isExpanded: true,
                  hint: Text(fuelStations.isEmpty
                      ? 'No fuel stations available'
                      : 'Select a fuel station'),
                  items: fuelStations
                      .map<DropdownMenuItem<int>>((FuelStation s) {
                    return DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (int? value) {
                    setState(() {
                      fuelStation = value;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // FUEL TYPE
                const LabelText(text: "Fuel Type*"),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  initialValue: fuelType,
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
                  hintText: lastOdoHint,
                ),
                const SizedBox(height: 10),

                // FUEL QUANTITY
                const LabelText(text: "Fuel Quantity*"),
                const SizedBox(height: 5),
                NumberField(
                  controller: fuelQuantityController,
                  padding: 10,
                  hintText: '1 – 250',
                ),
                const SizedBox(height: 10),

                // FUEL UNIT COST — no default price: the backend applies the
                // station's configured price when it has one.
                const LabelText(text: "Fuel Unit Cost"),
                const SizedBox(height: 5),
                NumberField(
                  controller: fuelUnitCostController,
                  padding: 10,
                  hintText: '70 – 120 (station price applies if set)',
                ),
                const SizedBox(height: 10),

                // TANK TAG NUMBER
                const LabelText(text: "Tag Number"),
                const SizedBox(height: 5),
                NumberField(
                  controller: tagNumberController,
                  padding: 10,
                  hintText: 'Enter tank tag number',
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                if (lastFuelLoaded)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      previousTag == null
                          ? 'No tag recorded at the last fueling. Enter one if the tank is tagged.'
                          : 'Previous tag: $previousTag. Change it only if the tank tag is different.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 10),

                ..._imageSection(
                  label: "Before Image*",
                  controller: beforeImageController,
                  buttonText: 'Upload Before Image',
                ),
                ..._imageSection(
                  label: "Indent Image",
                  controller: indentImageController,
                  buttonText: 'Upload Indent Image',
                ),
                ..._imageSection(
                  label: "After Image",
                  controller: afterImageController,
                  buttonText: 'Upload After Image',
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
