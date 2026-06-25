import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../components/drawer_page.dart';
import '../../config.dart';
import 'Qr_scan_screen.dart';
import 'bin_data_Model.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

class BinCollectionScreen extends StatefulWidget {
  const BinCollectionScreen({super.key});

  @override
  State<BinCollectionScreen> createState() => _BinCollectionScreenState();
}

class _BinCollectionScreenState extends State<BinCollectionScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final Future<void> _initFuture;

  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  String? deviceID;
  bool isLoggedIn = false;
  bool isLoading = false;
  String? errorMessage;
  List<BinCollection> collections = [];
  bool showQRScanOption = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceID = androidInfo.id;
      print('checccckk1');
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceID = iosInfo.identifierForVendor;
    }
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username');
    password = prefs.getString('password');
    if (username != null && password != null) {
      setState(() => isLoggedIn = true);
      print(isLoggedIn);
    }
    await _fetchBinCollections();
  }

  Future<void> _fetchBinCollections() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      showQRScanOption = false;
    });

    try {
      String url = "$baseUrl/bins/drf_list_bin_collection/";
      Map<String, String> headers = {
        'Accept': 'application/json',
      };

      if (username != null && password != null) {
        final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
        headers['Authorization'] = auth;
        print('url____sdvbkdjfbkje22');
        print(auth);
      } else if (deviceID != null) {
        url = "$url?device_id=$deviceID";
      } else {
        throw 'No authentication method available';
      }
      print('url____sdvbkdjfbkje');
      print(url);


      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final List<BinCollection> fetched = jsonList
            .map((e) => BinCollection.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          collections = fetched;
          isLoading = false;
          showQRScanOption = fetched.isEmpty;
        });
      } else {
        throw 'Server returned ${response.statusCode}';
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = e.toString().contains('TimeoutException')
            ? 'Request timed out. Check your connection.'
            : 'Failed to load data: ${e.toString()}';
        showQRScanOption = collections.isEmpty;
      });
    }
  }

  Future<void> _showImageSourceDialog(
      BuildContext context, BinCollection item) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take Photo with Camera',
                  style: TextStyle(color: Colors.black45)),
              onTap: () {
                Navigator.pop(context);
                _uploadAfterImage(item, ImageSource.camera);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: Colors.black45)),
              onTap: () {
                Navigator.pop(context);
                _uploadAfterImage(item, ImageSource.gallery);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title:
              const Text('Cancel', style: TextStyle(color: Colors.black45)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadAfterImage(
      BinCollection item, ImageSource source) async {
    try {
      // Pick image
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile == null) {
        _showSnackBar('No image selected', backgroundColor: Colors.orange);
        return;
      }

      // Check if card is locked
      if (item.lockCard == true) {
        _showSnackBar('This card is locked and cannot be modified',
            backgroundColor: Colors.orange);
        return;
      }

      // Prepare authentication
      String? auth;
      if (username != null && password != null) {
        auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      }

      // Create multipart request
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/bins/drf_after_bin_collection/'),
      );

      // Add headers
      if (auth != null) {
        request.headers['Authorization'] = auth;
      }
      request.headers['Accept'] = 'application/json';

      // Add fields
      request.fields['id'] = item.id.toString();

      // Add image file
      final file = File(pickedFile.path);
      final multipartFile = await http.MultipartFile.fromPath(
        'after',
        file.path,
        filename: 'after_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      request.files.add(multipartFile);

      // Show uploading dialog
      _showUploadingDialog();

      // Send request
      final response =
      await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      // Close dialog
      if (mounted) Navigator.pop(context);

      // Parse response
      final responseData = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        // Success
        _showSnackBar(
          responseData['message'] ?? 'After image uploaded successfully!',
          backgroundColor: Colors.green,
        );

        // Refresh the list to show updated after image
        await _fetchBinCollections();

        // Show success dialog
        _showSuccessDialog(file);
      } else {
        // Error
        final errorMsg = responseData['detail'] ??
            responseData['message'] ??
            'Failed to upload image. Status: ${response.statusCode}';
        _showSnackBar(errorMsg, backgroundColor: Colors.red);
      }
    } on TimeoutException {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Request timeout. Please try again.',
          backgroundColor: Colors.orange);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Error uploading image: ${e.toString()}',
          backgroundColor: Colors.red);
    }
  }

  // Show uploading progress dialog
  void _showUploadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Uploading After Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Please wait while we upload the image...',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Show success dialog with preview
  void _showSuccessDialog(File imageFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Success!',
          style: TextStyle(color: Colors.green),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                imageFile,
                height: 200,
                width: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'After image uploaded successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: isLoggedIn
            ? null
            : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Collected Bins',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        actions: [
          const NotificationBellWidget(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBinCollections,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: isLoggedIn ? AppDrawer() : null,
      body: RefreshIndicator(
        onRefresh: _fetchBinCollections,
        color: Colors.blue,
        child: FutureBuilder(
          future: _initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildBody();
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (showQRScanOption) {
      return _buildNoDataView();
    }

    if (isLoading && collections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Connection Error',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchBinCollections,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _navigateToQRScanner,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Start Scanning'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (collections.isEmpty) {
      return _buildNoDataView();
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: collections.length,
          itemExtent: 200,
          cacheExtent: 500,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final item = collections[index];
            final isLocked = item.lockCard == true;

            if (isLocked) {
              // For locked cards, show non-slidable card
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _buildCollectionCard(item),
              );
            } else {
              // For unlocked cards, show slidable card
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Slidable(
                  key: ValueKey(item.id),
                  startActionPane: null,
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.5,
                    dismissible: DismissiblePane(
                      onDismissed: () {
                        print('item__id');
                        print(item.id);
                      },
                    ),
                    dragDismissible: false,
                    children: [
                      SlidableAction(
                        onPressed: (_) =>
                            _showImageSourceDialog(context, item),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        icon: Icons.add_a_photo,
                        label: 'Upload After Image',
                        autoClose: true,
                      ),
                    ],
                  ),
                  child: _buildCollectionCard(item),
                ),
              );
            }
          },
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.extended(
            onPressed: _navigateToQRScanner,
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan New Bin'),
            elevation: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_scanner_rounded,
              size: 120,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            Text(
              'No Bin Collections Found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Start scanning bins to collect them',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToQRScanner,
                icon: const Icon(Icons.qr_code_scanner, size: 24),
                label: const Text(
                  'START SCANNING',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _fetchBinCollections,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionCard(BinCollection item) {
    final hasImage = item.beforeImage != null && item.beforeImage!.isNotEmpty;
    final isLocked = item.lockCard == true;

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              _showSnackBar('Tapped on Bin #${item.binNumber}');
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Left: Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: hasImage
                        ? CachedNetworkImage(
                      imageUrl: item.beforeImage!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                            child:
                            CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image,
                            color: Colors.grey),
                      ),
                      memCacheWidth: 300,
                      memCacheHeight: 300,
                    )
                        : Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported,
                          size: 40, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Right: Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Chip(
                              label: Text('#${item.id}',
                                  style: const TextStyle(
                                      color: Colors.blue, fontSize: 11)),
                              backgroundColor: Colors.blue[50],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.binNumber ?? 'Unknown Bin',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        _infoRow(Icons.location_on_outlined, 'Zone', item.zone),
                        _infoRow(
                            Icons.location_city_outlined, 'Ward', item.ward),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.directions_car,
                                size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.collectedVehicleNumber ?? 'No vehicle',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.green),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lock icon in top right corner when card is locked
          if (isLocked)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[800]?.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Locked',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Semi-transparent overlay when card is locked
          if (isLocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            value ?? 'N/A',
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}