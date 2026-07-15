// ─── GVP Module — Add reference images ────────────────────────────────────────
//
// Camera-only capture (no gallery). Users can queue several photos, each with
// an optional caption (≤ 100 chars, live counter). Uploading runs a CONTROLLED
// LOOP — one API call per image — so a failure on one image is reported without
// falsely marking it uploaded, and the others still proceed. The six-image cap
// is enforced in the UI (and the backend enforces it too).

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:ourlandnew/components/image_picker.dart';
import 'gvp_service.dart';
import 'gvp_ui.dart';

const int _kMaxImages = 6;
const int _kMaxCaption = 100;

enum _UploadStatus { pending, uploading, success, failed }

class _CaptureItem {
  File file;
  final TextEditingController caption = TextEditingController();
  _UploadStatus status = _UploadStatus.pending;
  String? error;

  _CaptureItem(this.file);

  void dispose() => caption.dispose();
}

class GvpReferenceImagesPage extends StatefulWidget {
  final int gvpId;
  final int existingCount;

  const GvpReferenceImagesPage({
    super.key,
    required this.gvpId,
    required this.existingCount,
  });

  @override
  State<GvpReferenceImagesPage> createState() =>
      _GvpReferenceImagesPageState();
}

class _GvpReferenceImagesPageState extends State<GvpReferenceImagesPage> {
  final _service = GvpService.instance;
  final List<_CaptureItem> _items = [];
  bool _uploading = false;
  bool _anyUploaded = false;

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  int get _uploadedCount =>
      _items.where((i) => i.status == _UploadStatus.success).length;

  /// Images already saved + successfully uploaded this session.
  int get _usedCount => widget.existingCount + _uploadedCount;

  /// Not-yet-uploaded items currently queued.
  int get _queuedCount =>
      _items.where((i) => i.status != _UploadStatus.success).length;

  int get _remainingSlots => _kMaxImages - _usedCount - _queuedCount;

  bool get _canAddMore => _remainingSlots > 0 && !_uploading;

  void _addCaptured(File file) {
    if (_remainingSlots <= 0) {
      gvpErrorSnack(context,
          'Maximum $_kMaxImages reference images allowed per GVP.');
      return;
    }
    setState(() => _items.add(_CaptureItem(file)));
  }

  void _retake(_CaptureItem item, File file) {
    setState(() {
      item.file = file;
      item.status = _UploadStatus.pending;
      item.error = null;
    });
  }

  void _remove(_CaptureItem item) {
    setState(() {
      _items.remove(item);
      item.dispose();
    });
  }

  bool _captionsValid() {
    for (final item in _items) {
      if (item.caption.text.trim().length > _kMaxCaption) return false;
    }
    return true;
  }

  Future<void> _uploadAll() async {
    if (_uploading) return; // guard against duplicate uploads
    final pending = _items
        .where((i) => i.status != _UploadStatus.success)
        .toList(growable: false);
    if (pending.isEmpty) {
      gvpErrorSnack(context, 'Capture at least one photo to upload.');
      return;
    }
    if (!_captionsValid()) {
      gvpErrorSnack(context, 'Captions must be $_kMaxCaption characters or fewer.');
      return;
    }

    setState(() => _uploading = true);

    var failures = 0;
    // Controlled loop — one API request per image.
    for (final item in pending) {
      if (!mounted) return;
      setState(() {
        item.status = _UploadStatus.uploading;
        item.error = null;
      });
      try {
        await _service.addReferenceImage(
          widget.gvpId,
          item.file,
          caption: item.caption.text,
        );
        if (!mounted) return;
        setState(() {
          item.status = _UploadStatus.success;
          _anyUploaded = true;
        });
      } on GvpApiException catch (e) {
        failures++;
        if (!mounted) return;
        setState(() {
          item.status = _UploadStatus.failed;
          item.error = e.message;
        });
        // Stop early if the server says we hit the max — no point continuing.
        if (e.statusCode == 400 &&
            e.message.toLowerCase().contains('maximum')) {
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    if (failures == 0) {
      gvpSuccessSnack(context, 'Reference image(s) uploaded');
      Navigator.pop(context, true);
    } else {
      gvpErrorSnack(context,
          '$failures image(s) failed to upload. You can retry the failed ones.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return whether anything uploaded so the details screen can refresh, even
    // when the user backs out after a partial upload.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _uploading) return;
        Navigator.pop(context, _anyUploaded);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: BackButton(
            onPressed:
                _uploading ? null : () => Navigator.pop(context, _anyUploaded),
          ),
          title: const Text(
            'Add Reference Images',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Column(
          children: [
            _CountHeader(used: _usedCount, max: _kMaxImages),
            Expanded(
              child: _items.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                      itemCount: _items.length,
                      itemBuilder: (context, i) => _CaptureCard(
                        item: _items[i],
                        index: i + 1,
                        enabled: !_uploading,
                        onRetake: (f) => _retake(_items[i], f),
                        onRemove: () => _remove(_items[i]),
                      ),
                    ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return GvpEmpty(
      message: _remainingSlots > 0
          ? 'No photos captured yet'
          : 'Maximum images reached',
      hint: _remainingSlots > 0
          ? 'Capture up to $_remainingSlots more photo(s) with the camera.'
          : 'This GVP already has $_kMaxImages reference images.',
      icon: Icons.add_a_photo_outlined,
    );
  }

  Widget _buildFooter() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canAddMore)
              SizedBox(
                width: double.infinity,
                child: CameraImagePicker(
                  onImagePicked: _addCaptured,
                  text: _items.isEmpty ? 'Capture Photo' : 'Capture Another',
                ),
              )
            else if (_remainingSlots <= 0 && !_uploading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Maximum $_kMaxImages images reached',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(140),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed:
                    (_uploading || _queuedCount == 0) ? null : _uploadAll,
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _uploading
                      ? 'Uploading…'
                      : _queuedCount == 0
                          ? 'Upload'
                          : 'Upload $_queuedCount image(s)',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Count header ──────────────────────────────────────────────────────────────

class _CountHeader extends StatelessWidget {
  final int used;
  final int max;

  const _CountHeader({required this.used, required this.max});

  @override
  Widget build(BuildContext context) {
    final atMax = used >= max;
    final color = atMax ? Colors.orange : Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.photo_library_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            'Reference images',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$used / $max used',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Capture card ──────────────────────────────────────────────────────────────

class _CaptureCard extends StatelessWidget {
  final _CaptureItem item;
  final int index;
  final bool enabled;
  final void Function(File) onRetake;
  final VoidCallback onRemove;

  const _CaptureCard({
    required this.item,
    required this.index,
    required this.enabled,
    required this.onRetake,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor(context).withAlpha(90)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview
          Stack(
            children: [
              SizedBox(
                height: 170,
                width: double.infinity,
                child: _preview(context),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: _StatusChip(status: item.status),
              ),
              if (enabled && item.status != _UploadStatus.success)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.black.withAlpha(120),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: item.caption,
                  enabled: enabled && item.status != _UploadStatus.success,
                  maxLength: _kMaxCaption,
                  decoration: InputDecoration(
                    labelText: 'Caption (optional)',
                    hintText: 'Describe this photo…',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (item.status == _UploadStatus.failed &&
                    item.error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.error!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (enabled && item.status != _UploadStatus.success) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: CameraImagePicker(
                      onImagePicked: onRetake,
                      text: 'Retake',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    try {
      if (item.file.existsSync()) {
        return Image.file(item.file, fit: BoxFit.cover);
      }
    } catch (_) {}
    return Container(
      color: Colors.white.withAlpha(8),
      child: const Center(
        child: Icon(Icons.broken_image_outlined,
            color: Colors.red, size: 28),
      ),
    );
  }

  Color _statusColor(BuildContext context) {
    switch (item.status) {
      case _UploadStatus.success:
        return Colors.green;
      case _UploadStatus.failed:
        return Theme.of(context).colorScheme.error;
      case _UploadStatus.uploading:
        return Theme.of(context).colorScheme.primary;
      case _UploadStatus.pending:
        return Colors.white.withAlpha(30);
    }
  }
}

class _StatusChip extends StatelessWidget {
  final _UploadStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;
    late final IconData icon;
    switch (status) {
      case _UploadStatus.success:
        color = Colors.green;
        label = 'Uploaded';
        icon = Icons.check_circle;
        break;
      case _UploadStatus.failed:
        color = Theme.of(context).colorScheme.error;
        label = 'Failed';
        icon = Icons.error;
        break;
      case _UploadStatus.uploading:
        color = Theme.of(context).colorScheme.primary;
        label = 'Uploading';
        icon = Icons.cloud_upload;
        break;
      case _UploadStatus.pending:
        color = Colors.black.withAlpha(150);
        label = 'Ready';
        icon = Icons.schedule;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(220),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
