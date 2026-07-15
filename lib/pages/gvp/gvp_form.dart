// ─── GVP Module — Create / Edit form ──────────────────────────────────────────
//
// One page serves both flows:
//   • Create  → GvpFormPage()                — POST /drf_gvp_create
//   • Edit    → GvpFormPage(existing: detail) — PATCH /drf_gvp_update/<id>
//
// Create-form options (project + zone choices) are always fetched BEFORE the
// form is shown. Wards for the chosen zone are loaded on demand. On edit only
// the fields the user actually changed are sent. Audit fields and
// reference_images are never included in the payload (see GvpCreateRequest /
// the changed-field map built here).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gvp_models.dart';
import 'gvp_service.dart';
import 'gvp_ui.dart';

class GvpFormPage extends StatefulWidget {
  /// When non-null the page is in edit mode and pre-fills from this detail.
  final GvpDetail? existing;

  const GvpFormPage({super.key, this.existing});

  bool get isEdit => existing != null;

  @override
  State<GvpFormPage> createState() => _GvpFormPageState();
}

class _GvpFormPageState extends State<GvpFormPage> {
  final _service = GvpService.instance;

  // Options
  bool _optionsLoading = true;
  String? _optionsError;
  List<GvpChoice> _projectItems = [];
  List<GvpZoneChoice> _zoneItems = [];

  // Ward loading (per selected zone)
  List<GvpWardChoice> _wardItems = [];
  bool _wardLoading = false;
  String? _wardError;

  // Field controllers / selections
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();
  String? _project;
  int? _zoneId;
  int? _wardId;

  // Initial snapshot (edit mode change detection)
  late String _initName;
  late String _initProject;
  int? _initZoneId;
  int? _initWardId;
  late String _initLat;
  late String _initLong;

  bool _submitting = false;

  // Backend + client field errors, keyed by API field name.
  final Map<String, List<String>> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _seedInitialValues();
    _loadOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }

  void _seedInitialValues() {
    final e = widget.existing;
    _initName = e?.name ?? '';
    _initProject = e?.project ?? '';
    _initZoneId = e?.zone;
    _initWardId = e?.ward;
    _initLat = e?.latitude ?? '';
    _initLong = e?.longitude ?? '';

    _nameController.text = _initName;
    _latController.text = _initLat;
    _longController.text = _initLong;
    _project = _initProject.isEmpty ? null : _initProject;
    _zoneId = _initZoneId;
    _wardId = _initWardId;
  }

  // ── Options loading ─────────────────────────────────────────────────────────

  Future<void> _loadOptions() async {
    setState(() {
      _optionsLoading = true;
      _optionsError = null;
    });
    try {
      final opts = await _service.getGvpCreateOptions();
      if (!mounted) return;

      // Prefer backend project choices; fall back to the canonical constant so
      // the dropdown is never empty.
      final projects = opts.projectChoices.isNotEmpty
          ? opts.projectChoices
          : kGvpProjects
              .map((p) => GvpChoice(value: p, label: p))
              .toList();

      setState(() {
        _projectItems = projects;
        _zoneItems = opts.zonalChoices;
        _optionsLoading = false;
      });

      // In edit mode, preload wards for the existing zone so the ward dropdown
      // shows the current selection.
      if (_zoneId != null) {
        await _loadWards(_zoneId!, preserveSelection: true);
      }
    } on GvpApiException catch (e) {
      if (mounted) {
        setState(() {
          _optionsError = e.message;
          _optionsLoading = false;
        });
      }
    }
  }

  Future<void> _loadWards(int zoneId, {bool preserveSelection = false}) async {
    // Prefer wards embedded in the zone choice; otherwise use the documented
    // by-ward endpoint to enumerate wards for the zone.
    final embedded = _zoneItems
        .firstWhere(
          (z) => z.id == zoneId,
          orElse: () => const GvpZoneChoice(id: -1, code: ''),
        )
        .wards;

    if (embedded.isNotEmpty) {
      setState(() {
        _wardItems = embedded;
        _wardError = null;
        _wardLoading = false;
        if (!preserveSelection) _wardId = null;
        _ensureWardInList();
      });
      return;
    }

    setState(() {
      _wardLoading = true;
      _wardError = null;
      _wardItems = [];
      if (!preserveSelection) _wardId = null;
    });
    try {
      final counts = await _service.getGvpCountByWard(zoneId: zoneId);
      if (!mounted) return;
      setState(() {
        _wardItems = counts
            .map((c) => GvpWardChoice(id: c.wardId, code: c.wardCode))
            .toList();
        _ensureWardInList();
      });
    } on GvpApiException catch (e) {
      if (mounted) setState(() => _wardError = e.message);
    } finally {
      if (mounted) setState(() => _wardLoading = false);
    }
  }

  /// Keep an already-selected ward visible even if it isn't among the fetched
  /// options (e.g. editing a GVP whose ward has no siblings listed).
  void _ensureWardInList() {
    if (_wardId != null && !_wardItems.any((w) => w.id == _wardId)) {
      _wardItems = [
        GvpWardChoice(id: _wardId!, code: 'Ward $_wardId'),
        ..._wardItems,
      ];
    }
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  String? _validateLatitude(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null; // optional
    final v = double.tryParse(s);
    if (v == null) return 'Enter a valid number.';
    if (v < -90 || v > 90) return 'Latitude must be between -90 and 90.';
    return null;
  }

  String? _validateLongitude(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null; // optional
    final v = double.tryParse(s);
    if (v == null) return 'Enter a valid number.';
    if (v < -180 || v > 180) return 'Longitude must be between -180 and 180.';
    return null;
  }

  /// Runs client-side validation, populating [_fieldErrors]. Returns true when
  /// the form is valid.
  bool _validateClient() {
    _fieldErrors.clear();
    if (_nameController.text.trim().isEmpty) {
      _fieldErrors['name'] = ['GVP name is required.'];
    }
    if (_project == null || _project!.isEmpty) {
      _fieldErrors['project'] = ['Project is required.'];
    }
    if (_zoneId == null) {
      _fieldErrors['zone'] = ['Zone is required.'];
    }
    if (_wardId == null) {
      _fieldErrors['ward'] = ['Ward is required.'];
    }
    final latErr = _validateLatitude(_latController.text);
    if (latErr != null) _fieldErrors['latitude'] = [latErr];
    final longErr = _validateLongitude(_longController.text);
    if (longErr != null) _fieldErrors['longitude'] = [longErr];

    setState(() {});
    return _fieldErrors.isEmpty;
  }

  // ── Change detection (edit mode) ────────────────────────────────────────────

  bool get _hasChanges {
    if (!widget.isEdit) return true; // create always "changed"
    return _nameController.text.trim() != _initName ||
        (_project ?? '') != _initProject ||
        _zoneId != _initZoneId ||
        _wardId != _initWardId ||
        _latController.text.trim() != _initLat ||
        _longController.text.trim() != _initLong;
  }

  Map<String, dynamic> _buildChangedFields() {
    final map = <String, dynamic>{};
    if (_nameController.text.trim() != _initName) {
      map['name'] = _nameController.text.trim();
    }
    if ((_project ?? '') != _initProject) map['project'] = _project;
    if (_zoneId != _initZoneId) map['zone'] = _zoneId;
    if (_wardId != _initWardId) map['ward'] = _wardId;
    if (_latController.text.trim() != _initLat) {
      map['latitude'] = _latController.text.trim();
    }
    if (_longController.text.trim() != _initLong) {
      map['longitude'] = _longController.text.trim();
    }
    return map;
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting) return; // guard against duplicate submissions
    if (!_validateClient()) return;

    setState(() => _submitting = true);
    try {
      if (widget.isEdit) {
        final changed = _buildChangedFields();
        if (changed.isEmpty) {
          gvpErrorSnack(context, 'No changes to save.');
          return;
        }
        await _service.updateGvp(widget.existing!.id, changed);
        if (!mounted) return;
        gvpSuccessSnack(context, 'GVP updated successfully');
      } else {
        final payload = GvpCreateRequest(
          name: _nameController.text,
          project: _project!,
          zone: _zoneId!,
          ward: _wardId!,
          latitude: _latController.text,
          longitude: _longController.text,
        );
        await _service.createGvp(payload);
        if (!mounted) return;
        gvpSuccessSnack(context, 'GVP created successfully');
      }
      Navigator.pop(context, true);
    } on GvpApiException catch (e) {
      if (!mounted) return;
      if (e.hasFieldErrors) {
        setState(() {
          _fieldErrors
            ..clear()
            ..addAll(e.fieldErrors!);
        });
        gvpErrorSnack(context, e.message);
      } else {
        gvpErrorSnack(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.isEdit ? 'Edit GVP' : 'Add GVP',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_optionsLoading) return const GvpLoading();
    if (_optionsError != null) {
      return GvpFullError(message: _optionsError!, onRetry: _loadOptions);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
      children: [
        _SectionCard(
          icon: Icons.info_outline_rounded,
          title: 'Basic Information',
          children: [
            const _FieldLabel('GVP Name', required: true),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _decor(hint: 'Enter GVP name'),
              onChanged: (_) => _clearError('name'),
            ),
            _errorText('name'),
            const SizedBox(height: 14),
            const _FieldLabel('Project', required: true),
            DropdownButtonFormField<String>(
              value: _project,
              isExpanded: true,
              decoration: _decor(hint: 'Select project'),
              items: _projectItems
                  .map((c) => DropdownMenuItem(
                        value: c.value,
                        child: Text(c.label),
                      ))
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (v) {
                      setState(() => _project = v);
                      _clearError('project');
                    },
            ),
            _errorText('project'),
            const SizedBox(height: 14),
            const _FieldLabel('Zone', required: true),
            DropdownButtonFormField<int>(
              value: _zoneId,
              isExpanded: true,
              decoration: _decor(hint: 'Select zone'),
              items: _zoneItems
                  .map((z) => DropdownMenuItem(
                        value: z.id,
                        child: Text(z.code),
                      ))
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (v) {
                      setState(() {
                        _zoneId = v;
                        _wardId = null;
                        _wardItems = [];
                      });
                      _clearError('zone');
                      _clearError('ward');
                      if (v != null) _loadWards(v);
                    },
            ),
            _errorText('zone'),
            const SizedBox(height: 14),
            const _FieldLabel('Ward', required: true),
            _buildWardField(),
            _errorText('ward'),
          ],
        ),
        _SectionCard(
          icon: Icons.my_location_rounded,
          title: 'Location (optional)',
          children: [
            const _FieldLabel('Latitude'),
            TextField(
              controller: _latController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
              ],
              decoration: _decor(hint: 'e.g. 12.987654'),
              onChanged: (_) => _clearError('latitude'),
            ),
            _errorText('latitude'),
            const SizedBox(height: 14),
            const _FieldLabel('Longitude'),
            TextField(
              controller: _longController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
              ],
              decoration: _decor(hint: 'e.g. 80.123456'),
              onChanged: (_) => _clearError('longitude'),
            ),
            _errorText('longitude'),
          ],
        ),
        const SizedBox(height: 4),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildWardField() {
    if (_wardLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Loading wards…', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }
    if (_wardError != null) {
      return GvpInlineError(
        message: _wardError!,
        onRetry: () => _zoneId != null ? _loadWards(_zoneId!) : null,
      );
    }
    return DropdownButtonFormField<int>(
      value: _wardId,
      isExpanded: true,
      decoration: _decor(
        hint: _zoneId == null ? 'Select a zone first' : 'Select ward',
      ),
      items: _wardItems
          .map((w) => DropdownMenuItem(
                value: w.id,
                child: Text(w.code),
              ))
          .toList(),
      onChanged: (_submitting || _zoneId == null)
          ? null
          : (v) {
              setState(() => _wardId = v);
              _clearError('ward');
            },
    );
  }

  Widget _buildSubmitButton() {
    if (_submitting) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(),
        ),
      );
    }
    final enabled = _hasChanges; // create: always true; edit: only when changed
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: enabled ? _submit : null,
        icon: Icon(widget.isEdit ? Icons.save_rounded : Icons.check_rounded),
        label: Text(
          widget.isEdit ? 'Update GVP' : 'Create GVP',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ── Small helpers ───────────────────────────────────────────────────────────

  void _clearError(String field) {
    if (_fieldErrors.containsKey(field)) {
      setState(() => _fieldErrors.remove(field));
    }
  }

  Widget _errorText(String field) {
    final errors = _fieldErrors[field];
    if (errors == null || errors.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        errors.join('\n'),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  InputDecoration _decor({String? hint}) => InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withAlpha(80)),
        ),
      );
}

// ── Section card (matches Add Shift styling) ──────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
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
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 20, color: Colors.white.withAlpha(20)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
            ),
          ),
          if (required)
            const Text(
              ' *',
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
