import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../../components/drawer_page.dart';
import '../../config.dart';
import 'bin_collection.dart';
import 'bin_data_Model.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with WidgetsBindingObserver {
  BinData? scannedData;
  bool isScanning = true;
  bool isLoadingLocation = false;
  bool isSubmitting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  String? deviceID;
  int? userid;

  // Vehicle state
  bool isLoadingVehicles = false;
  List<Vehicle> vehicles = [];
  Vehicle? selectedVehicle;

  // Image state
  File? beforeImage;
  final ImagePicker _picker = ImagePicker();

  late final MobileScannerController cameraController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cameraController = MobileScannerController(
      torchEnabled: false,
      formats: const [BarcodeFormat.qrCode],
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    getDeviceId();
  }

  Future<void> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceID= androidInfo.id;
      print('checccckk1');
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceID = iosInfo.identifierForVendor; // unique per vendor
    }
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username');
      password = prefs.getString('password');
      userid = prefs.getInt('userid');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!cameraController.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        cameraController.start();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        cameraController.stop();
        break;
      default:
        break;
    }
  }


  void _onDetect(BarcodeCapture capture) {
    if (!isScanning || !mounted) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    try {
      final jsonMap = jsonDecode(barcode!.rawValue!) as Map<String, dynamic>;
      final data = BinData.fromJson(jsonMap);

      setState(() {
        scannedData = data;
        isScanning = false;
      });

      cameraController.stop();

      if (data.isLocationMissing) {
        _fetchCurrentLocation();
      }

      if (data.project?.isNotEmpty == true) {
        _fetchVehiclesForProject(data.project!);
      }
    } catch (e) {
      _showSnackBar('Invalid QR Code: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _fetchCurrentLocation() async {
    if (!mounted) return;
    setState(() => isLoadingLocation = true);

    try {
      final permission = await Geolocator.requestPermission();
      if (![LocationPermission.always, LocationPermission.whileInUse].contains(permission)) {
        throw 'Location permission denied';
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      String? address = "Unknown Location";
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address = "${place.street}, ${place.locality}";
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        scannedData = scannedData!..latitude = position.latitude
          ..longitude = position.longitude
          ..location = scannedData!.location?.isNotEmpty == true
              ? scannedData!.location
              : address;
        isLoadingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingLocation = false);
      _showSnackBar('Location error: $e', Colors.orange);
    }
  }

  Future<void> _fetchVehiclesForProject(String project) async {
    if (!mounted) return;
    setState(() {
      isLoadingVehicles = true;
      vehicles = [];
      selectedVehicle = null;
    });

    try {

      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final url = "$baseUrl/bins/drf_collect_bin/?project=$project";
      final response = await http.get(Uri.parse(url), headers: {
        'Authorization': username!=null&&password!=null?auth:'',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
      print('url____');
      print(url);
      print(username);
      print(password);
      print(response.statusCode);
      print(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(response.body);
        final fetched = jsonList.map((e) => Vehicle.fromJson(e)).toList();

        setState(() {
          vehicles = fetched;
          isLoadingVehicles = false;
        });
      } else {
        throw 'Failed to load vehicles (${response.statusCode})';
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingVehicles = false);
      _showSnackBar('Failed to load vehicles', Colors.red);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1080,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image != null && mounted) {
        setState(() => beforeImage = File(image.path));
      }
    } catch (e) {
      _showSnackBar('Image capture failed', Colors.red);
    }
  }


  Future<void> _submitBinCollection() async {
    if (selectedVehicle == null || beforeImage == null || scannedData == null) {
      _showSnackBar('Please complete all fields', Colors.orange);
      return;
    }

    if (!mounted) return;
    setState(() => isSubmitting = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/bins/drf_collect_bin/'),
      );

      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      request.headers.addAll({
        'Authorization': username != null && password != null ? auth : '',
        'Accept': 'application/json',
      });

      // Add fields
      request.fields.addAll({
        'bin': scannedData!.id.toString(),
        'collected_vehicle': selectedVehicle!.id.toString(),
        'device_id': deviceID ?? '',
      });
      if (userid != null) {
        request.fields['collected_by'] = userid!.toString();
      }
      print('$baseUrl/bins/drf_collect_bin/');
      print('Device ID: $deviceID');

      if (scannedData!.latitude != null && scannedData!.longitude != null) {
        request.fields['latitude'] = scannedData!.latitude!.toStringAsFixed(6);
        request.fields['longitude'] = scannedData!.longitude!.toStringAsFixed(6);
      }

      // Add file
      request.files.add(await http.MultipartFile.fromPath('before', beforeImage!.path));

      // Print request details
      print('=== REQUEST DETAILS ===');
      print('URL: ${request.url}');
      print('Fields: ${request.fields}');
      print('Files count: ${request.files.length}');

      // Send request
      final response = await request.send().timeout(const Duration(seconds: 30));
      final resp = await http.Response.fromStream(response);

      if (!mounted) return;

      print('Response Status Code: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSnackBar('Collection submitted successfully!', Colors.green);

        // Delay navigation to show success message
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const BinCollectionScreen(),
            ),
          );
        }
      } else {
        final responseBody = jsonDecode(resp.body);
        final msg = responseBody['detail'] ??
            responseBody['message'] ??
            'Submission failed with status ${response.statusCode}';

        _showSnackBar(msg, Colors.red);
        print('Error: $msg');
        print('Response body: ${resp.body}');
      }
    }
    catch (e) {
      if (mounted) {
        _showSnackBar('Network error: ${e.toString()}', Colors.red);
      }
      print('Network error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }
  void _resetScan() {
    setState(() {
      scannedData = null;
      isScanning = true;
      selectedVehicle = null;
      beforeImage = null;
      vehicles = [];
      isLoadingVehicles = false;
      isLoadingLocation = false;
    });
    cameraController.start();
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bin Collection Scanner',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),

        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // Scanner Mode
          if (isScanning)
            MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
              fit: BoxFit.cover,
            ),

          // Result Mode
          if (!isScanning && scannedData != null)
            _buildResultView(),
        ],
      ),
    );
  }


  Widget _buildResultView() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildInfoCard(
                title: 'Bin Details',
                child: Column(
                  children: [
                    _buildRow('Bin ID', scannedData!.id.toString()),
                    _buildRow('Project', scannedData!.project ?? 'N/A'),
                    _buildRow('Bin Number', scannedData!.binNumber ?? 'N/A'),
                    const SizedBox(height: 12),
                    if (isLoadingLocation)
                      const LinearProgressIndicator()
                    else if (scannedData!.latitude != null)
                      _buildLocationCard(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildVehicleCard(),
              const SizedBox(height: 16),
              _buildImageCard(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
              const SizedBox(height: 16),
             /* TextButton.icon(
                onPressed: _resetScan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Another Bin'),
              ),*/
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Location Captured', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(scannedData!.location ?? 'Unknown', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip('Lat', scannedData!.latitude),
              const SizedBox(width: 8),
              _chip('Lng', scannedData!.longitude),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, double? value) {
    return Chip(
      label: Text('$label: ${value?.toStringAsFixed(6) ?? "N/A"}', style: const TextStyle(color:Colors.black45,fontSize: 11)),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildVehicleCard() {
    return _buildInfoCard(
      title: 'Select Collection Vehicle',
      child: isLoadingVehicles
          ? const Center(child: CircularProgressIndicator())
          : vehicles.isEmpty
          ? const Text('No vehicles available', style: TextStyle(color: Colors.red))
          : SearchableDropdown<Vehicle>(
        items: vehicles,
        value: selectedVehicle,
        onChanged: (v) => setState(() => selectedVehicle = v),
        itemToString: (v) => v.vehicleNumber,
        subtitleBuilder: (v) => '${v.vehicleType} • ID: ${v.id}',
        hintText: 'Search vehicle...',
      ),
    );
  }

  Widget _buildImageCard() {
    return _buildInfoCard(
      title: 'Capture Bin Image (Before)',
      child: beforeImage == null
          ? ElevatedButton.icon(
        onPressed: _pickImage,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Take Photo'),
      )
          : Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(beforeImage!, height: 220, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.refresh), label: const Text('Retake')),
              const SizedBox(width: 12),
              ElevatedButton.icon(onPressed: () => setState(() => beforeImage = null), icon: const Icon(Icons.delete), label: const Text('Remove'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = selectedVehicle != null && beforeImage != null && !isSubmitting;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canSubmit ? _submitBinCollection : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canSubmit ? Colors.green : Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isSubmitting
            ? const CircularProgressIndicator(color: Colors.blue)
            : const Text('SUBMIT COLLECTION', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}



class SearchableDropdown<T> extends StatefulWidget {
  final List<T> items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final String Function(T) itemToString;
  final String Function(T)? subtitleBuilder;
  final String hintText;
  final String? labelText;
  final bool showSearchBar;
  final bool isExpanded;

  const SearchableDropdown({
    Key? key,
    required this.items,
    required this.onChanged,
    required this.value,
    required this.itemToString,
    this.subtitleBuilder,
    this.hintText = 'Select',
    this.labelText,
    this.showSearchBar = true,
    this.isExpanded = false,
  }) : super(key: key);

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  late List<T> filteredItems;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    filteredItems = List.from(widget.items);
  }

  @override
  void didUpdateWidget(covariant SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _filterItems(searchQuery);
    }
  }

  void _filterItems(String query) {
    setState(() {
      searchQuery = query.toLowerCase();
      if (query.isEmpty) {
        filteredItems = List.from(widget.items);
      } else {
        filteredItems = widget.items.where((item) {
          final mainText = widget.itemToString(item).toLowerCase();
          final subtitle = widget.subtitleBuilder != null
              ? widget.subtitleBuilder!(item).toLowerCase()
              : '';

          // Search in both main text and subtitle
          return mainText.contains(searchQuery) ||
              subtitle.contains(searchQuery) ||
              // For vehicles, also search in ID
              (item is Vehicle && item.id.toString().contains(searchQuery));
        }).toList();
      }
    });
  }

  Future<T?> _showSearchableDialog(BuildContext context) async {
    return await showDialog<T>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  children: [
                    // Search Bar
                    if (widget.showSearchBar)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search by ID, vehicle number, or type...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) {
                            setState((){
                              _filterItems(value);
                            });

                          },
                        ),
                      ),

                    // Results Count
                    if (widget.showSearchBar)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Found ${filteredItems.length} vehicles',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            if (searchQuery.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  _filterItems('');
                                  // Clear the search field in dialog
                                  setState(() {});
                                },
                                child: const Text('Clear'),
                              ),
                          ],
                        ),
                      ),

                    const Divider(height: 1),

                    // Items List
                    Expanded(
                      child: filteredItems.isEmpty
                          ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No vehicles found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                          : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return ListTile(
                            title: Text(widget.itemToString(item)),
                            subtitle: widget.subtitleBuilder != null
                                ? Text(widget.subtitleBuilder!(item))
                                : null,
                            trailing: widget.value == item
                                ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            )
                                : null,
                            onTap: () {
                              Navigator.of(context).pop(item);
                            },
                            // For Vehicle items, show ID as well
                            leading: item is Vehicle
                                ? CircleAvatar(
                              backgroundColor: Colors.blue.shade50,
                              child: Text(
                                item.id.toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            )
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.labelText!,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: InkWell(
            onTap: () async {
              final T? selectedItem = await _showSearchableDialog(context);
              if (selectedItem != null && widget.onChanged != null) {
                widget.onChanged!(selectedItem);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                children: [
                  Expanded(
                    child: widget.value == null
                        ? Text(
                      widget.hintText,
                      style: TextStyle(
                        color: Colors.grey[500],
                      ),
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.itemToString(widget.value!),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.subtitleBuilder != null)
                          Text(
                            widget.subtitleBuilder!(widget.value!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        // Show ID for vehicles
                        if (widget.value is Vehicle)
                          Text(
                            'ID: ${(widget.value as Vehicle).id}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}