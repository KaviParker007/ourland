import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';

class UploadEmployeeDetailsPage extends StatefulWidget {
  final int employeeId;
  final String employeeName;

  const UploadEmployeeDetailsPage({
    Key? key,
    required this.employeeId,
    required this.employeeName,
  }) : super(key: key);

  @override
  State<UploadEmployeeDetailsPage> createState() => _UploadEmployeeDetailsPageState();
}

class _UploadEmployeeDetailsPageState extends State<UploadEmployeeDetailsPage> {
  final String baseUrl = AppConfig.apiUrl;
  final ImagePicker _picker = ImagePicker();

  // Image files
  File? employeePhoto;
  File? aadhaarImageFront;
  File? aadhaarImageBack;
  File? licenseImageFront;
  File? licenseImageBack;

  // URLs for already uploaded images
  String? employeePhotoUrl;
  String? aadhaarFrontUrl;
  String? aadhaarBackUrl;
  String? licenseFrontUrl;
  String? licenseBackUrl;

  bool isUploading = false;
  bool isLoading = true;
  String? username;
  String? password;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username');
      password = prefs.getString('password');
    });
    await _fetchExistingImages();
  }

  // Fetch already uploaded images
  Future<void> _fetchExistingImages() async {
    try {
      setState(() => isLoading = true);

      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final response = await http.get(
        Uri.parse('$baseUrl/hr/drf_upload_employee_images/?employee_id=${widget.employeeId}'),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );

      print('Fetch Images Status: ${response.statusCode}');
      print('Fetch Images Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        setState(() {
          // Extract image URLs from response
          employeePhotoUrl = responseData['employee_photo'];
          aadhaarFrontUrl = responseData['aadhaar_image_front'];
          aadhaarBackUrl = responseData['aadhaar_image_back'];
          licenseFrontUrl = responseData['license_image_front'];
          licenseBackUrl = responseData['license_image_back'];
        });
      } else {
        print('No existing images found or error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching existing images: ${e.toString()}');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Build complete image URL
  String _buildImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';

    // Check if it's already a full URL
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    // If it's a relative path, construct full URL
    return '$baseUrl${imagePath.startsWith('/') ? imagePath : '/$imagePath'}';
  }

  // Pick image from gallery or camera
  Future<void> _pickImage(ImageType imageType) async {
    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile != null) {
        setState(() {
          switch (imageType) {
            case ImageType.employeePhoto:
              employeePhoto = File(pickedFile.path);
              employeePhotoUrl = null; // Clear existing URL when new file is selected
              break;
            case ImageType.aadhaarFront:
              aadhaarImageFront = File(pickedFile.path);
              aadhaarFrontUrl = null;
              break;
            case ImageType.aadhaarBack:
              aadhaarImageBack = File(pickedFile.path);
              aadhaarBackUrl = null;
              break;
            case ImageType.licenseFront:
              licenseImageFront = File(pickedFile.path);
              licenseFrontUrl = null;
              break;
            case ImageType.licenseBack:
              licenseImageBack = File(pickedFile.path);
              licenseBackUrl = null;
              break;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Validate required fields
  bool _validateFields() {
    if (employeePhoto == null && employeePhotoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee photo is mandatory'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (aadhaarImageFront == null && aadhaarFrontUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aadhaar front image is mandatory'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  // Upload images to API
  Future<void> _uploadImages() async {
    if (!_validateFields()) return;

    setState(() => isUploading = true);

    try {
      var uri = Uri.parse("$baseUrl/hr/drf_upload_employee_images");

      // Basic Auth
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      var request = http.MultipartRequest('POST', uri)
        ..headers['authorization'] = auth
        ..headers['Accept'] = 'application/json';

      // Add employee_id
      request.fields['employee_id'] = widget.employeeId.toString();

      // Add images safely
      Future<void> addFile(String fieldName, File? file) async {
        if (file != null) {
          request.files.add(
            await http.MultipartFile.fromPath(fieldName, file.path),
          );
        } else {
          request.fields[fieldName] = '';
        }
      }

      await addFile('employee_photo', employeePhoto);
      await addFile('aadhaar_image_front', aadhaarImageFront);
      await addFile('aadhaar_image_back', aadhaarImageBack);
      await addFile('license_image_front', licenseImageFront);
      await addFile('license_image_back', licenseImageBack);

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      setState(() => isUploading = false);

      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Images uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the existing images after upload
        await _fetchExistingImages();

        Navigator.pop(context, true);
      } else if (response.statusCode == 400) {
        final responseData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['error'] ?? 'Bad request. Please check your inputs.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server Error (${response.statusCode}): ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading images: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Upload Employee Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee Info
            Card(
              color: Colors.grey.shade800,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employee: ${widget.employeeName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID: ${widget.employeeId}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Employee Photo (Mandatory)
            _buildImagePicker(
              title: 'Employee Photo *',
              imageFile: employeePhoto,
              imageUrl: employeePhotoUrl,
              imageType: ImageType.employeePhoto,
              isMandatory: true,
            ),
            const SizedBox(height: 16),

            // Aadhaar Front (Mandatory)
            _buildImagePicker(
              title: 'Aadhaar Front Image *',
              imageFile: aadhaarImageFront,
              imageUrl: aadhaarFrontUrl,
              imageType: ImageType.aadhaarFront,
              isMandatory: true,
            ),
            const SizedBox(height: 16),

            // Aadhaar Back
            _buildImagePicker(
              title: 'Aadhaar Back Image',
              imageFile: aadhaarImageBack,
              imageUrl: aadhaarBackUrl,
              imageType: ImageType.aadhaarBack,
              isMandatory: false,
            ),
            const SizedBox(height: 16),

            // License Front
            _buildImagePicker(
              title: 'License Front Image',
              imageFile: licenseImageFront,
              imageUrl: licenseFrontUrl,
              imageType: ImageType.licenseFront,
              isMandatory: false,
            ),
            const SizedBox(height: 16),

            // License Back
            _buildImagePicker(
              title: 'License Back Image',
              imageFile: licenseImageBack,
              imageUrl: licenseBackUrl,
              imageType: ImageType.licenseBack,
              isMandatory: false,
            ),
            const SizedBox(height: 32),

            // Upload Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isUploading ? null : _uploadImages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Upload Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker({
    required String title,
    required File? imageFile,
    required String? imageUrl,
    required ImageType imageType,
    required bool isMandatory,
  }) {
    final hasExistingImage = imageUrl != null && imageUrl.isNotEmpty;
    final hasNewImage = imageFile != null;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:  Colors.red,
                  ),
                ),
                if (hasExistingImage) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Uploaded',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            if (hasNewImage)
              _buildImagePreview(imageFile!, imageType, true)
            else if (hasExistingImage)
              _buildImagePreview(_buildImageUrl(imageUrl!), imageType, false)
            else
              _buildPlaceholder(imageType, isMandatory),

            if (hasNewImage || hasExistingImage) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickImage(imageType),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Change Image'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasExistingImage)
                    OutlinedButton.icon(
                      onPressed: () {
                        // Show existing image in full screen
                        _showFullScreenImage(_buildImageUrl(imageUrl!));
                      },
                      icon: const Icon(Icons.zoom_in),
                      label: const Text('View'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(dynamic imageSource, ImageType imageType, bool isFile) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isFile
              ? Image.file(
            imageSource as File,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                color: Colors.grey.shade300,
                child: const Center(
                  child: Icon(Icons.error, color: Colors.red, size: 48),
                ),
              );
            },
          )
              : Image.network(
            imageSource as String,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                color: Colors.grey.shade300,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                color: Colors.grey.shade300,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (isFile)
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.red,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () {
                  setState(() {
                    switch (imageType) {
                      case ImageType.employeePhoto:
                        employeePhoto = null;
                        break;
                      case ImageType.aadhaarFront:
                        aadhaarImageFront = null;
                        break;
                      case ImageType.aadhaarBack:
                        aadhaarImageBack = null;
                        break;
                      case ImageType.licenseFront:
                        licenseImageFront = null;
                        break;
                      case ImageType.licenseBack:
                        licenseImageBack = null;
                        break;
                    }
                  });
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder(ImageType imageType, bool isMandatory) {
    return InkWell(
      onTap: () => _pickImage(imageType),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isMandatory ? Colors.red : Colors.grey.shade400,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate,
                size: 48,
                color: Colors.grey.shade600,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to select image',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.white,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 48),
                          SizedBox(height: 16),
                          Text('Failed to load image'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.red.shade400,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ImageType {
  employeePhoto,
  aadhaarFront,
  aadhaarBack,
  licenseFront,
  licenseBack,
}