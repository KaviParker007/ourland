// ─── Bin / collection record card ──────────────────────────────────────────────
//
// The leaf-list card for both the Bins and Collections modules (their list
// endpoints return the same shape). Shows bin number, type, zone, ward, vehicle,
// device, collected/left timestamps, collector and coordinates, plus the before
// and after photos with a zoomable full-screen preview.
//
// Missing or non-http image URLs degrade to a labelled placeholder rather than a
// broken image — see BinRecord.normaliseImageUrl.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:ourlandnew/models/bin_record.dart';

import 'drill_down.dart';

/// Renders `2026-09-08 14:54:15` as `08 Sep 2026, 2:54 PM`, falling back to the
/// raw string if it is not a timestamp we recognise.
String formatRecordTimestamp(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final parsed = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
  if (parsed == null) return raw;
  return DateFormat('dd MMM yyyy, h:mm a').format(parsed);
}

// ── Full-screen image preview ──────────────────────────────────────────────────

/// Opens [url] in a zoomable, dismissible full-screen viewer.
void showRecordImagePreview(
  BuildContext context, {
  required String url,
  required String title,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _ImagePreviewPage(url: url, title: title),
    ),
  );
}

class _ImagePreviewPage extends StatelessWidget {
  final String url;
  final String title;
  const _ImagePreviewPage({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, _) => const SizedBox(
              height: 64,
              width: 64,
              child: Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, _, _) => const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined,
                      size: 56, color: Colors.white38),
                  SizedBox(height: 12),
                  Text('This image could not be loaded',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Before / after thumbnail ───────────────────────────────────────────────────

/// One labelled photo tile. Tapping opens the preview; a null [url] renders an
/// inert "no photo" placeholder.
class RecordImageTile extends StatelessWidget {
  final String label;
  final String? url;
  final String previewTitle;

  const RecordImageTile({
    super.key,
    required this.label,
    required this.url,
    required this.previewTitle,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final available = url != null;

    return Semantics(
      button: available,
      label: available
          ? '$label photo. Double tap to preview.'
          : 'No $label photo available',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: onSurface.withAlpha(130),
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: available
                  ? () => showRecordImagePreview(
                        context,
                        url: url!,
                        title: previewTitle,
                      )
                  : null,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: available
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: url!,
                            fit: BoxFit.cover,
                            memCacheWidth: 480,
                            placeholder: (_, _) => Container(
                              color: onSurface.withAlpha(14),
                              child: const Center(
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (_, _, _) =>
                                _placeholder(onSurface, broken: true),
                          ),
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(120),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.zoom_in_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      )
                    : _placeholder(onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(Color onSurface, {bool broken = false}) {
    return Container(
      color: onSurface.withAlpha(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            broken
                ? Icons.broken_image_outlined
                : Icons.image_not_supported_outlined,
            size: 22,
            color: onSurface.withAlpha(70),
          ),
          const SizedBox(height: 4),
          Text(
            broken ? 'Unavailable' : 'No photo',
            style: TextStyle(fontSize: 10, color: onSurface.withAlpha(90)),
          ),
        ],
      ),
    );
  }
}

// ── The card ───────────────────────────────────────────────────────────────────

/// Leaf-list card for a bin or a collection.
///
/// [showCollectionDetail] adds the timestamps, device, collector and coordinates
/// block — on by default for the Collections list, and still useful on the Bins
/// list for bins that carry a last-collection record.
class BinRecordCard extends StatelessWidget {
  final BinRecord record;
  final bool showCollectionDetail;

  const BinRecordCard({
    super.key,
    required this.record,
    this.showCollectionDetail = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final surface = theme.colorScheme.surface;
    final typeColor = dashCategoryColor(record.binType, known: _kBinTypeOrder);

    final locked = record.lockCard;
    const lockedColor = Color(0xFF78909C);
    final accent = locked ? lockedColor : typeColor;
    final cardColor =
        locked ? Color.alphaBlend(lockedColor.withAlpha(20), surface) : null;

    return Semantics(
      container: true,
      label: [
        record.binNumber,
        record.binType,
        if (record.zone != null) 'zone ${record.zone}',
        if (record.ward != null) 'ward ${record.ward}',
        if (record.collectedVehicleNumber != null)
          'vehicle ${record.collectedVehicleNumber}',
        if (locked) 'locked',
      ].join(', '),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: locked
              ? BorderSide(color: lockedColor.withAlpha(120), width: 1.2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerRow(context, onSurface, typeColor, locked, lockedColor),
              const SizedBox(height: 8),
              _chipsRow(context, onSurface, typeColor),
              if (showCollectionDetail) ...[
                const SizedBox(height: 10),
                _detailBlock(context, onSurface),
              ],
              if (record.hasAnyImage ||
                  record.collectedOn != null ||
                  showCollectionDetail) ...[
                const SizedBox(height: 12),
                _imagesRow(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Bin number + id badge + lock pill.
  Widget _headerRow(BuildContext context, Color onSurface, Color typeColor,
      bool locked, Color lockedColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.binNumber,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.2),
              ),
              if (record.binId != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Bin #${record.binId}',
                  style:
                      TextStyle(fontSize: 11, color: onSurface.withAlpha(130)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (locked) _pill('LOCKED', lockedColor, icon: Icons.lock_rounded),
      ],
    );
  }

  // Type / zone / ward / vehicle.
  Widget _chipsRow(BuildContext context, Color onSurface, Color typeColor) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _pill(record.binType, typeColor),
        if (record.zone != null)
          _outlineChip(
              context, Icons.location_city_outlined, record.zone!),
        if (record.ward != null)
          _outlineChip(context, Icons.map_outlined, record.ward!),
        if (record.collectedVehicleNumber != null)
          _outlineChip(context, Icons.local_shipping_outlined,
              record.collectedVehicleNumber!),
      ],
    );
  }

  /// Timestamps, device, collector and coordinates. Uses a two-column grid on
  /// wide layouts and a single column on phones, so nothing overflows.
  Widget _detailBlock(BuildContext context, Color onSurface) {
    final rows = <_DetailItem>[
      _DetailItem(Icons.schedule_rounded, 'Collected',
          formatRecordTimestamp(record.collectedOn)),
      _DetailItem(Icons.logout_rounded, 'Left',
          formatRecordTimestamp(record.leftOn)),
      if (record.collectedBy != null)
        _DetailItem(Icons.person_outline_rounded, 'Collected by',
            'Employee #${record.collectedBy}'),
      if (record.deviceId != null)
        _DetailItem(
            Icons.smartphone_outlined, 'Device', record.deviceId!),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: onSurface.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onSurface.withAlpha(24)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoUp = constraints.maxWidth >= 420;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (twoUp)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (final r in rows)
                      SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: _detailRow(context, onSurface, r),
                      ),
                  ],
                )
              else
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _detailRow(context, onSurface, rows[i]),
                ],
              if (record.coordinates != null) ...[
                const SizedBox(height: 8),
                Divider(height: 1, color: onSurface.withAlpha(20)),
                const SizedBox(height: 8),
                _coordinatesRow(context, onSurface),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(BuildContext context, Color onSurface, _DetailItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(item.icon, size: 14, color: onSurface.withAlpha(130)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: onSurface.withAlpha(120)),
              ),
              Text(
                item.value,
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Coordinates, copyable — the app has no map view, so copying is the useful
  /// action rather than a dead-end link.
  Widget _coordinatesRow(BuildContext context, Color onSurface) {
    final coords = record.coordinates!;
    return Semantics(
      button: true,
      label: 'Location $coords. Double tap to copy.',
      excludeSemantics: true,
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: coords));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Coordinates copied'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: Row(
          children: [
            Icon(Icons.place_outlined, size: 14, color: onSurface.withAlpha(130)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                coords,
                style: const TextStyle(fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.copy_rounded, size: 13, color: onSurface.withAlpha(110)),
          ],
        ),
      ),
    );
  }

  Widget _imagesRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RecordImageTile(
            label: 'Before',
            url: record.before,
            previewTitle: '${record.binNumber} · Before',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RecordImageTile(
            label: 'After',
            url: record.after,
            previewTitle: '${record.binNumber} · After',
          ),
        ),
      ],
    );
  }

  Widget _pill(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(110), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _outlineChip(BuildContext context, IconData icon, String label) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onSurface.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onSurface.withAlpha(35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: onSurface.withAlpha(150)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: onSurface.withAlpha(200)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  const _DetailItem(this.icon, this.label, this.value);
}

/// Canonical bin-type ordering for colour assignment. Mirrors the documented
/// `bin_type` choices; unknown types still get a stable hashed colour.
const List<String> _kBinTypeOrder = <String>[
  'Compactor',
  'HookLoader',
  'Dumper',
  'Others',
];
