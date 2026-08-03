// ─── GVP Module — Details screen ──────────────────────────────────────────────
//
// Shows Basic Information, Location Information and the read-only reference
// image gallery. Provides Edit, Add Reference Image, Delete Reference Image and
// Back to List actions. Renders a dedicated not-found state on HTTP 404.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'gvp_models.dart';
import 'gvp_service.dart';
import 'gvp_ui.dart';
import 'gvp_form.dart';
import 'gvp_reference_images.dart';
import 'gvp_name_resolver.dart';

const int kGvpMaxReferenceImages = 6;

/// Formats an ISO datetime string the way the web app shows it
/// (e.g. "14 Jul 2026, 10:14 AM"). Falls back to the raw value if unparseable.
String _fmtDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  try {
    return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(raw).toLocal());
  } catch (_) {
    return raw;
  }
}

class GvpDetailPage extends StatefulWidget {
  final int gvpId;

  const GvpDetailPage({super.key, required this.gvpId});

  @override
  State<GvpDetailPage> createState() => _GvpDetailPageState();
}

class _GvpDetailPageState extends State<GvpDetailPage> {
  final _service = GvpService.instance;
  final _resolver = GvpNameResolver.instance;

  GvpDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _notFound = false;
    });
    try {
      final detail = await _service.getGvpDetails(widget.gvpId);
      if (!mounted) return;
      setState(() => _detail = detail);
      // Resolve zone/ward names for display.
      await _resolver.ensureZones();
      if (detail.zone != null) {
        await _resolver.ensureWardsForZone(detail.zone!);
      }
      if (mounted) setState(() {});
    } on GvpApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 404) {
          _notFound = true;
        } else {
          _error = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEdit() async {
    final detail = _detail;
    if (detail == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GvpFormPage(existing: detail)),
    );
    if (updated == true) _fetch();
  }

  Future<void> _openAddImages() async {
    final detail = _detail;
    if (detail == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GvpReferenceImagesPage(
          gvpId: detail.id,
          existingCount: detail.referenceImages.length,
        ),
      ),
    );
    if (changed == true) _fetch();
  }

  Future<void> _confirmDelete(GvpReferenceImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteImageDialog(image: image),
    );
    if (confirmed == true) _deleteImage(image);
  }

  Future<void> _deleteImage(GvpReferenceImage image) async {
    // Optimistic-safe: show a blocking progress, then refresh from server.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _service.deleteReferenceImage(image.id);
      if (!mounted) return;
      Navigator.pop(context); // dismiss progress
      gvpSuccessSnack(context, 'Reference image deleted');
      _fetch();
    } on GvpApiException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss progress
      gvpErrorSnack(context, e.message);
      // If it was already gone, refresh to reconcile.
      if (e.statusCode == 404) _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'GVP Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_detail != null)
            IconButton(
              tooltip: 'Edit GVP',
              onPressed: _openEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const GvpLoading();
    if (_notFound) return _buildNotFound();
    if (_error != null) return GvpFullError(message: _error!, onRetry: _fetch);
    final detail = _detail;
    if (detail == null) return const SizedBox.shrink();

    final imgCount = detail.referenceImages.length;
    final atMax = imgCount >= kGvpMaxReferenceImages;

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        children: [
          // ── Basic Information ──
          _Section(
            icon: Icons.info_outline_rounded,
            title: 'Basic Information',
            child: Column(
              children: [
                _DetailRow(label: 'GVP Name', value: detail.name),
                _DetailRow(label: 'Project', value: detail.project),
                _DetailRow(
                    label: 'Zone', value: _resolver.zoneName(detail.zone)),
                _DetailRow(
                    label: 'Ward', value: _resolver.wardName(detail.ward)),
              ],
            ),
          ),

          // ── Record Information ──
          _Section(
            icon: Icons.badge_outlined,
            title: 'Record Information',
            child: Column(
              children: [
                _DetailRow(
                  label: 'Active',
                  value: detail.active ? 'YES' : 'NO',
                  valueWidget: _ActiveBadge(active: detail.active),
                ),
                _DetailRow(
                  label: 'Created On',
                  value: _fmtDateTime(detail.createdOn),
                ),
                _DetailRow(
                  label: 'Created By',
                  value: (detail.createdBy?.isNotEmpty ?? false)
                      ? detail.createdBy!
                      : '—',
                ),
              ],
            ),
          ),

          // ── Reference Images ──
          _Section(
            icon: Icons.photo_library_outlined,
            title: 'Reference Images',
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (atMax ? Colors.orange : Theme.of(context).colorScheme.primary)
                    .withAlpha(28),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$imgCount / $kGvpMaxReferenceImages',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color:
                      atMax ? Colors.orange : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail.referenceImages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No reference images yet.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(130),
                      ),
                    ),
                  )
                else
                  _ImageGallery(
                    images: detail.referenceImages,
                    onDelete: _confirmDelete,
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: atMax ? null : _openAddImages,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(atMax
                        ? 'Maximum $kGvpMaxReferenceImages images reached'
                        : 'Add Reference Image'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          // ── Back to List ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to List'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(90)),
            const SizedBox(height: 14),
            const Text(
              'GVP not found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'This GVP may have been removed.',
              style: TextStyle(
                fontSize: 13,
                color:
                    Theme.of(context).colorScheme.onSurface.withAlpha(120),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to List'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reference image gallery ───────────────────────────────────────────────────

class _ImageGallery extends StatelessWidget {
  final List<GvpReferenceImage> images;
  final void Function(GvpReferenceImage) onDelete;

  const _ImageGallery({required this.images, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, i) {
        final img = images[i];
        return _GalleryTile(image: img, onDelete: () => onDelete(img));
      },
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final GvpReferenceImage image;
  final VoidCallback onDelete;

  const _GalleryTile({required this.image, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(18)),
        color: Colors.white.withAlpha(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GvpNetworkImage(url: image.image),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black.withAlpha(120),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onDelete,
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(Icons.delete_outline,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              (image.caption?.isNotEmpty ?? false) ? image.caption! : 'No caption',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: (image.caption?.isNotEmpty ?? false)
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withAlpha(110),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Network image with graceful loading + error states, reused by the gallery
/// and the delete-confirmation dialog.
class GvpNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const GvpNetworkImage({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder(context, broken: true);
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stack) =>
          _placeholder(context, broken: true),
    );
  }

  Widget _placeholder(BuildContext context, {bool broken = false}) {
    return Container(
      color: Colors.white.withAlpha(8),
      child: Icon(
        broken ? Icons.broken_image_outlined : Icons.image_outlined,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(90),
        size: 28,
      ),
    );
  }
}

// ── Delete confirmation dialog ────────────────────────────────────────────────

class _DeleteImageDialog extends StatelessWidget {
  final GvpReferenceImage image;

  const _DeleteImageDialog({required this.image});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete reference image?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: GvpNetworkImage(url: image.image),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            (image.caption?.isNotEmpty ?? false)
                ? image.caption!
                : 'No caption',
            style: TextStyle(
              fontSize: 13,
              fontStyle: (image.caption?.isNotEmpty ?? false)
                  ? FontStyle.normal
                  : FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This action cannot be undone.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

// ── Section + detail-row layout ───────────────────────────────────────────────

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 20, color: Colors.white.withAlpha(20)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;

  /// When provided, this widget is shown in place of the text value (e.g. a
  /// status badge).
  final Widget? valueWidget;

  const _DetailRow({
    required this.label,
    required this.value,
    this.muted = false,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: onSurface.withAlpha(140)),
            ),
          ),
          Expanded(
            child: valueWidget != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: valueWidget,
                  )
                : Text(
                    value.isEmpty ? '—' : value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: muted ? onSurface.withAlpha(120) : onSurface,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Active status badge (matches the web's green "YES" pill) ──────────────────

class _ActiveBadge extends StatelessWidget {
  final bool active;

  const _ActiveBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        active ? 'YES' : 'NO',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
