import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ourlandnew/components/buttons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CameraImagePicker extends StatefulWidget {
  final Function(File) onImagePicked;
  final String text;
  final int maxFileSize;

  const CameraImagePicker({
    super.key,
    required this.onImagePicked,
    required this.text,
    this.maxFileSize = 1048576, // 1 MB in bytes
  });

  @override
  State<CameraImagePicker> createState() => _CameraImagePickerState();
}

class _CameraImagePickerState extends State<CameraImagePicker> {
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return DarkButton(
      onPressed: () {
        getImage();
      },
      text: widget.text,
    );
  }

  Future<void> getImage() async {
    try {
      final pickImage = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickImage == null) {
        return;
      }

      File capturedImage = File(pickImage.path);

      // Check file size first
      final originalSize = await capturedImage.length();
      final originalSizeMB = originalSize / 1048576;

      File finalImage;
      String sizeInfo;

      if (originalSize > widget.maxFileSize) {
        // Compress if larger than max size
        finalImage = await _compressImageToTargetSize(capturedImage);
        final compressedSize = await finalImage.length();
        final compressedSizeMB = compressedSize / 1048576;

        sizeInfo = 'Compressed: ${compressedSizeMB.toStringAsFixed(2)}MB (from ${originalSizeMB.toStringAsFixed(2)}MB)';
      } else {
        // Use original if already small enough
        finalImage = capturedImage;
        sizeInfo = 'Original: ${originalSizeMB.toStringAsFixed(2)}MB';
      }
      print('sizeInfo____');
      print('${originalSizeMB.toStringAsFixed(2)}MB  original');
      print('sizeInfo____2');
      print(sizeInfo);

      // Show snackbar with file size info


      widget.onImagePicked(finalImage);
    } catch (e) {
      print('Error capturing image: $e');

    }
  }

  Future<File> _compressImageToTargetSize(File imageFile) async {
    try {
      final directory = await getTemporaryDirectory();
      String newPath = path.join(
        directory.path,
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final bytes = await imageFile.readAsBytes();
      final image = await decodeImageFromList(bytes);

      // Calculate scale factor to reduce size
      double scale = 1.0;
      if (image.width > 1024 || image.height > 1024) {
        scale = 1024 / image.width > 1024 / image.height
            ? 1024 / image.width
            : 1024 / image.height;
      }

      // Apply additional scaling if needed (progressive compression)
      int attempts = 0;
      File compressedFile = imageFile;
      double currentScale = scale;

      while (attempts < 5) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.scale(currentScale, currentScale);
        canvas.drawImage(image, Offset.zero, Paint());

        final picture = recorder.endRecording();
        final newImage = await picture.toImage(
          (image.width * currentScale).toInt(),
          (image.height * currentScale).toInt(),
        );

        final byteData = await newImage.toByteData(format: ui.ImageByteFormat.png);
        final newBytes = byteData!.buffer.asUint8List();

        compressedFile = File(newPath);
        await compressedFile.writeAsBytes(newBytes);

        final compressedSize = await compressedFile.length();

        if (compressedSize <= widget.maxFileSize) {
          break; // Successfully compressed below target size
        }

        // Reduce scale further for next attempt
        currentScale *= 0.8;
        attempts++;
      }

      return compressedFile;
    } catch (e) {
      print('Error processing image: $e');
      return imageFile;
    }
  }
}