// ─── GVP Module — Daily cleaning confirmation flow ────────────────────────────
//
// Drives the swipe-to-confirm behaviour on GVP cards:
//   • NT  → swipe reveals "Before" → capture a camera image → POST create
//   • WIP → swipe reveals "After"  → capture a camera image → PATCH close
//   • C   → card is locked (no swipe)
//
// Both actions require a fresh camera photo (gallery upload is not allowed) plus
// the device location for the backend's proximity check. On success the calling
// screen refreshes so the new today_status is reflected everywhere.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'gvp_card.dart';
import 'gvp_models.dart';
import 'gvp_service.dart';
import 'gvp_status.dart';
import 'gvp_ui.dart';

// ── Public entry point ────────────────────────────────────────────────────────

/// Runs the Before (NT) / After (WIP) confirmation flow for [gvp]. Returns true
/// when the backend accepted the confirmation and the caller should refresh.
Future<bool> runGvpDailyAction(
  BuildContext context, {
  required Gvp gvp,
  required bool isBefore,
}) async {
  // Guard against stale UI — only act on the status the card was showing.
  if (isBefore && gvp.todayStatus != GvpTodayStatus.nt) {
    gvpErrorSnack(context, 'This GVP is no longer awaiting a before image.');
    return false;
  }
  if (!isBefore) {
    if (gvp.todayStatus != GvpTodayStatus.wip) {
      gvpErrorSnack(context, 'This GVP is not in progress.');
      return false;
    }
    if (gvp.gvpOpenDc == null) {
      gvpErrorSnack(context,
          'Confirmation record not found. Pull to refresh and try again.');
      return false;
    }
  }

  final success = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _DailyConfirmationSheet(gvp: gvp, isBefore: isBefore),
  );

  if (success == true && context.mounted) {
    gvpSuccessSnack(
      context,
      isBefore
          ? 'Before image captured — cleaning marked in progress.'
          : 'After image captured — cleaning completed.',
    );
    return true;
  }
  return false;
}

// ── Location helper ───────────────────────────────────────────────────────────

/// Fetches the current device position, throwing a user-friendly message when
/// location is unavailable so the backend proximity check can be performed.
Future<Position> _currentPosition() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw 'Location services are turned off. Please enable GPS and try again.';
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw 'Location permission denied. Please allow location access to confirm.';
  }
  if (permission == LocationPermission.deniedForever) {
    throw 'Location permission is permanently denied. Enable it in settings.';
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
}

// ── Capture sheet ─────────────────────────────────────────────────────────────

class _DailyConfirmationSheet extends StatefulWidget {
  final Gvp gvp;
  final bool isBefore;

  const _DailyConfirmationSheet({required this.gvp, required this.isBefore});

  @override
  State<_DailyConfirmationSheet> createState() =>
      _DailyConfirmationSheetState();
}

class _DailyConfirmationSheetState extends State<_DailyConfirmationSheet> {
  final _service = GvpService.instance;
  final _picker = ImagePicker();
  final _remarkController = TextEditingController();

  File? _image;
  bool _submitting = false;
  String? _error;

  bool get _isBefore => widget.isBefore;

  Color get _accent => GvpStatusStyle.of(
        _isBefore ? GvpTodayStatus.wip : GvpTodayStatus.cleared,
      ).color;

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    try {
      // Camera only — gallery upload is not permitted for confirmations.
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (shot == null) return; // user cancelled
      setState(() {
        _image = File(shot.path);
        _error = null;
      });
    } catch (_) {
      setState(() => _error = 'Could not open the camera. Please try again.');
    }
  }

  Future<void> _submit() async {
    final image = _image;
    if (image == null) {
      setState(() => _error = 'Please capture a photo first.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final pos = await _currentPosition();
      if (_isBefore) {
        await _service.createDailyConfirmation(
          gvpId: widget.gvp.id,
          beforeImage: image,
          latitude: pos.latitude,
          longitude: pos.longitude,
          remark: _remarkController.text,
        );
      } else {
        await _service.closeDailyConfirmation(
          confirmationId: widget.gvp.gvpOpenDc!,
          afterImage: image,
          latitude: pos.latitude,
          longitude: pos.longitude,
          remark: _remarkController.text,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on GvpApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // Surface field-level upload errors (e.g. "No file was submitted.")
        // alongside the general/location messages.
        _error = e.hasFieldErrors
            ? e.fieldErrors!.values.expand((v) => v).join('\n')
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grab handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: onSurface.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Icon(
                _isBefore
                    ? Icons.photo_camera_outlined
                    : Icons.check_circle_outline,
                color: _accent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isBefore ? 'Capture Before Image' : 'Capture After Image',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.gvp.name.isEmpty ? 'GVP #${widget.gvp.id}' : widget.gvp.name,
            style: TextStyle(fontSize: 13, color: onSurface.withAlpha(160)),
          ),
          const SizedBox(height: 16),

          // Photo preview / capture target
          _PhotoArea(
            image: _image,
            accent: _accent,
            onTap: _submitting ? null : _capture,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _submitting ? null : _capture,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: Text(_image == null ? 'Take Photo' : 'Retake Photo'),
            ),
          ),
          const SizedBox(height: 6),

          // Optional remark
          TextField(
            controller: _remarkController,
            enabled: !_submitting,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Remark (optional)',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withAlpha(24),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Theme.of(context).colorScheme.error.withAlpha(90)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline,
                      size: 18, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _submitting ? null : () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (_submitting || _image == null) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(_submitting
                      ? 'Submitting…'
                      : (_isBefore ? 'Confirm Before' : 'Confirm After')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoArea extends StatelessWidget {
  final File? image;
  final Color accent;
  final VoidCallback? onTap;

  const _PhotoArea({required this.image, required this.accent, this.onTap});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: image != null ? accent.withAlpha(140) : onSurface.withAlpha(50),
            width: 1.2,
          ),
          color: onSurface.withAlpha(8),
        ),
        child: image != null
            ? Image.file(image!, fit: BoxFit.cover)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 40, color: onSurface.withAlpha(110)),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to capture with camera',
                    style:
                        TextStyle(fontSize: 13, color: onSurface.withAlpha(140)),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Swipeable GVP card ────────────────────────────────────────────────────────

/// Wraps [GvpCard] with swipe-to-confirm behaviour based on today_status.
/// NT/WIP cards expose an end-swipe action; C (and unknown) cards are locked.
class GvpDailyCard extends StatelessWidget {
  final Gvp gvp;
  final String? zoneName;
  final String? wardName;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onImages;

  /// Invoked after a successful confirmation so the list can refresh.
  final Future<void> Function() onChanged;

  const GvpDailyCard({
    super.key,
    required this.gvp,
    required this.onChanged,
    this.zoneName,
    this.wardName,
    this.onView,
    this.onEdit,
    this.onImages,
  });

  Future<void> _run(BuildContext context, bool isBefore) async {
    final changed =
        await runGvpDailyAction(context, gvp: gvp, isBefore: isBefore);
    if (changed) await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final card = GvpCard(
      gvp: gvp,
      showStatus: true,
      zoneName: zoneName,
      wardName: wardName,
      onView: onView,
      onEdit: onEdit,
      onImages: onImages,
    );

    if (gvp.todayStatus == GvpTodayStatus.cleared) {
      // Fully locked: today's cleaning is complete. No Slidable is built, so
      // there are no swipe gestures and no Before/After actions — the card
      // cannot trigger any daily-confirmation API call. A green lock badge makes
      // the completed/locked state explicit.
      final green = GvpStatusStyle.of(GvpTodayStatus.cleared).color;
      return Stack(
        children: [
          card,
          Positioned(
            top: 0,
            bottom: 10,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: green.withAlpha(30),
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10)),
                    border: Border.all(color: green.withAlpha(120), width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 15, color: green),
                      const SizedBox(height: 2),
                      Text(
                        'DONE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!gvp.todayStatus.isSwipeable) {
      // Unknown status — no daily action available; render a plain card.
      return card;
    }

    final isBefore = gvp.todayStatus == GvpTodayStatus.nt;
    final style = GvpStatusStyle.of(
        isBefore ? GvpTodayStatus.wip : GvpTodayStatus.cleared);

    return Slidable(
      key: ValueKey('gvp-${gvp.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.30,
        children: [
          SlidableAction(
            onPressed: (_) => _run(context, isBefore),
            backgroundColor: style.color,
            foregroundColor: Colors.white,
            icon: isBefore
                ? Icons.photo_camera_outlined
                : Icons.check_circle_outline,
            label: isBefore ? 'Before' : 'After',
            borderRadius: BorderRadius.circular(14),
          ),
        ],
      ),
      child: Stack(
        children: [
          card,
          // Subtle affordance hinting the row can be swiped for its action.
          Positioned(
            top: 0,
            bottom: 10,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Icon(
                  Icons.keyboard_double_arrow_left_rounded,
                  size: 18,
                  color: style.color.withAlpha(130),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
