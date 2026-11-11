// ─── Shift activity image upload ───────────────────────────────────────────────
//
// Reached by swiping a running shift card left-to-right on the shift records
// page. Posts to drf-upload-shiftactivity-image/ as multipart/form-data:
//
//   shift_id*  image*  remark (optional)
//
// The backend attaches the photo to the shift's current trip, so the user is
// never asked to pick a trip.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ourlandnew/components/buttons.dart';
import 'package:ourlandnew/components/input_fields.dart';
import 'package:ourlandnew/components/label.dart';
import 'package:ourlandnew/services/dash_api.dart';

import 'shift_dash_service.dart';

class ShiftActivityImagePage extends StatefulWidget {
  final int shiftId;

  /// Vehicle number, shown in the title for context.
  final String? vehicle;

  const ShiftActivityImagePage({super.key, required this.shiftId, this.vehicle});

  @override
  State<ShiftActivityImagePage> createState() => _ShiftActivityImagePageState();
}

class _ShiftActivityImagePageState extends State<ShiftActivityImagePage> {
  final _picker = ImagePicker();
  final _remarkController = TextEditingController();
  File? _image;
  bool _uploading = false;

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null || !mounted) return;
      setState(() => _image = File(picked.path));
    } catch (_) {
      if (mounted) {
        _error(source == ImageSource.camera
            ? 'Could not open the camera. Check the camera permission.'
            : 'Could not open the gallery. Check the storage permission.');
      }
    }
  }

  Future<void> _upload() async {
    if (_uploading) return;
    final image = _image;
    if (image == null) {
      _error('Please capture or select an image.');
      return;
    }

    setState(() => _uploading = true);
    try {
      final message = await ShiftDashboardApi.instance.uploadActivityImage(
        shiftId: widget.shiftId,
        imagePath: image.path,
        remark: _remarkController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.green,
        content: Text(message == 'success'
            ? 'Shift activity image uploaded successfully.'
            : message),
        duration: const Duration(seconds: 3),
      ));
      Navigator.pop(context, true);
    } on DashApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      if (e.statusCode == 403) {
        _showAccessDenied(e.message);
      } else {
        _error(e.message);
      }
    }
  }

  /// Missing `vms_app.add_shiftactivity` permission: not something a retry
  /// fixes, so it gets a dialog rather than a passing snackbar.
  void _showAccessDenied(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.lock_outline,
            color: Theme.of(ctx).colorScheme.error, size: 32),
        title: const Text('Access denied'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Theme.of(context).colorScheme.error,
      content: Text(msg),
      duration: const Duration(seconds: 3),
    ));
  }

  Widget _preview() {
    final image = _image;
    if (image == null) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.grey),
              SizedBox(height: 8),
              Text('No image selected', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    return Container(
      height: 240,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          image,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, _, _) => const Center(
            child: Text('Error loading image',
                style: TextStyle(color: Colors.red)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shift Activity Image'),
                if (widget.vehicle != null)
                  Text(
                    widget.vehicle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          body: Card(
            margin: const EdgeInsets.all(15),
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              children: [
                const LabelText(text: 'Image*'),
                const SizedBox(height: 5),
                _preview(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading
                            ? null
                            : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading
                            ? null
                            : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const LabelText(text: 'Remark (optional)'),
                const SizedBox(height: 5),
                TextAreaField(
                  controller: _remarkController,
                  padding: 10,
                  hintText: 'Add a caption or note',
                ),
                const SizedBox(height: 6),
                Text(
                  "The image is attached to this shift's current trip.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
                  ),
                ),
                const SizedBox(height: 20),
                _uploading
                    ? const Center(child: CircularProgressIndicator())
                    : PrimaryButton(text: 'Upload', onPressed: _upload),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
