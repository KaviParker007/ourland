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
import 'package:geolocator/geolocator.dart';

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

  // Project options (loaded once on init)
  bool _projectsLoading = true;
  String? _projectsError;
  List<GvpChoice> _projectItems = [];

  // Zone options (depend on the selected project)
  bool _zonesLoading = false;
  String? _zonesError;
  List<GvpZoneChoice> _zoneItems = [];

  // Ward options (depend on the selected zone)
  bool _wardLoading = false;
  String? _wardError;
  List<GvpWardChoice> _wardItems = [];

  // Field controllers / selections
  final _nameController = TextEditingController();
  String? _project;
  int? _zoneId;
  int? _wardId;

  // Initial snapshot (edit mode change detection)
  late String _initName;
  late String _initProject;
  int? _initZoneId;
  int? _initWardId;

  bool _submitting = false;

  // Backend + client field errors, keyed by API field name.
  final Map<String, List<String>> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _seedInitialValues();
    _loadProjects();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _seedInitialValues() {
    final e = widget.existing;
    _initName = e?.name ?? '';
    _initProject = e?.project ?? '';
    _initZoneId = e?.zone;
    _initWardId = e?.ward;

    _nameController.text = _initName;
    _project = _initProject.isEmpty ? null : _initProject;
    _zoneId = _initZoneId;
    _wardId = _initWardId;
  }

  // ── Dependent option loading (Project → Zone → Ward) ─────────────────────────

  /// Loads the Project list. In edit mode it then preloads the dependent Zone
  /// and Ward lists so the existing selections are shown.
  Future<void> _loadProjects() async {
    setState(() {
      _projectsLoading = true;
      _projectsError = null;
    });
    try {
      final projects = await _service.getProjectChoices();
      if (!mounted) return;
      setState(() {
        _projectItems = projects;
        _ensureProjectInList();
        _projectsLoading = false;
      });
      // Edit mode: hydrate the dependent chain for the pre-filled selection.
      if (_project != null && _project!.isNotEmpty) {
        await _loadZones(_project!, preserveSelection: true);
      }
    } on GvpApiException catch (e) {
      if (mounted) {
        setState(() {
          _projectsError = e.message;
          _projectsLoading = false;
        });
      }
    }
  }

  /// Loads the Zone list for [projectCode]. Stale responses (the user picked a
  /// different project mid-flight) are discarded.
  Future<void> _loadZones(String projectCode,
      {bool preserveSelection = false}) async {
    setState(() {
      _zonesLoading = true;
      _zonesError = null;
      _zoneItems = [];
      if (!preserveSelection) {
        _zoneId = null;
        _wardId = null;
        _wardItems = [];
        _wardError = null;
      }
    });
    try {
      final zones = await _service.getProjectZoneChoices(projectCode);
      if (!mounted || _project != projectCode) return;
      setState(() {
        _zoneItems = zones;
        _ensureZoneInList();
        _zonesLoading = false;
      });
      // Edit mode: continue hydrating wards for the pre-filled zone.
      if (preserveSelection && _zoneId != null) {
        await _loadWards(_zoneId!, preserveSelection: true);
      }
    } on GvpApiException catch (e) {
      if (!mounted || _project != projectCode) return;
      setState(() {
        _zonesError = e.message;
        _zonesLoading = false;
      });
    }
  }

  /// Loads the Ward list for [zoneId]. Stale responses are discarded.
  Future<void> _loadWards(int zoneId, {bool preserveSelection = false}) async {
    setState(() {
      _wardLoading = true;
      _wardError = null;
      _wardItems = [];
      if (!preserveSelection) _wardId = null;
    });
    try {
      final wards = await _service.getZonalWardChoices(zoneId);
      if (!mounted || _zoneId != zoneId) return;
      setState(() {
        _wardItems = wards;
        _ensureWardInList();
        _wardLoading = false;
      });
    } on GvpApiException catch (e) {
      if (!mounted || _zoneId != zoneId) return;
      setState(() {
        _wardError = e.message;
        _wardLoading = false;
      });
    }
  }

  /// Keep an already-selected project/zone/ward visible even if it isn't among
  /// the fetched options (e.g. editing a record whose option list differs),
  /// which also prevents a Dropdown "value not in items" assertion.
  void _ensureProjectInList() {
    final p = _project;
    if (p != null && p.isNotEmpty && !_projectItems.any((c) => c.value == p)) {
      _projectItems = [GvpChoice(value: p, label: p), ..._projectItems];
    }
  }

  void _ensureZoneInList() {
    if (_zoneId != null && !_zoneItems.any((z) => z.id == _zoneId)) {
      _zoneItems = [
        GvpZoneChoice(id: _zoneId!, code: 'Zone $_zoneId'),
        ..._zoneItems,
      ];
    }
  }

  void _ensureWardInList() {
    if (_wardId != null && !_wardItems.any((w) => w.id == _wardId)) {
      _wardItems = [
        GvpWardChoice(id: _wardId!, code: 'Ward $_wardId'),
        ..._wardItems,
      ];
    }
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  /// Runs client-side validation, populating [_fieldErrors]. Returns true when
  /// the form is valid. Location is captured silently at submit — never a field.
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

    setState(() {});
    return _fieldErrors.isEmpty;
  }

  // ── Change detection (edit mode) ────────────────────────────────────────────
  // Location is intentionally excluded — it is captured on the device and sent
  // to the backend, never shown or edited here.

  bool get _hasChanges {
    if (!widget.isEdit) return true; // create always "changed"
    return _nameController.text.trim() != _initName ||
        (_project ?? '') != _initProject ||
        _zoneId != _initZoneId ||
        _wardId != _initWardId;
  }

  Map<String, dynamic> _buildChangedFields() {
    final map = <String, dynamic>{};
    if (_nameController.text.trim() != _initName) {
      map['name'] = _nameController.text.trim();
    }
    if ((_project ?? '') != _initProject) map['project'] = _project;
    if (_zoneId != _initZoneId) map['zone'] = _zoneId;
    if (_wardId != _initWardId) map['ward'] = _wardId;
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
        // Capture the device location silently (best-effort) and include it in
        // the payload — it is never shown to or entered by the user.
        final pos = await _tryCaptureLocation();
        final payload = GvpCreateRequest(
          name: _nameController.text,
          project: _project!,
          zone: _zoneId!,
          ward: _wardId!,
          latitude: pos?.latitude.toString(),
          longitude: pos?.longitude.toString(),
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

  /// Best-effort device location capture for the create payload. Returns null
  /// (never throws) when GPS is off or permission is denied, so GVP creation is
  /// never blocked. The coordinates are sent to the backend but never shown.
  Future<Position?> _tryCaptureLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return null;
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
    if (_projectsLoading) return const GvpLoading();
    if (_projectsError != null) {
      return GvpFullError(message: _projectsError!, onRetry: _loadProjects);
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
                        child: Text(c.label, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (v) {
                      if (v == null || v == _project) return;
                      setState(() {
                        _project = v;
                        _zoneId = null;
                        _wardId = null;
                        _zoneItems = [];
                        _wardItems = [];
                        _zonesError = null;
                        _wardError = null;
                      });
                      _clearError('project');
                      _clearError('zone');
                      _clearError('ward');
                      _loadZones(v);
                    },
            ),
            _errorText('project'),
            const SizedBox(height: 14),
            const _FieldLabel('Zone', required: true),
            _buildZoneField(),
            _errorText('zone'),
            const SizedBox(height: 14),
            const _FieldLabel('Ward', required: true),
            _buildWardField(),
            _errorText('ward'),
          ],
        ),
        const SizedBox(height: 4),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildZoneField() {
    // Disabled until a project is chosen.
    if (_project == null || _project!.isEmpty) {
      return _disabledDropdown('Select a project first');
    }
    if (_zonesLoading) return _loadingField('Loading zones…');
    if (_zonesError != null) {
      return GvpInlineError(
        message: _zonesError!,
        onRetry: () => _loadZones(_project!),
      );
    }
    return DropdownButtonFormField<int>(
      value: _zoneId,
      isExpanded: true,
      decoration: _decor(hint: 'Select zone'),
      items: _zoneItems
          .map((z) => DropdownMenuItem(
                value: z.id,
                child: Text(z.code, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: _submitting
          ? null
          : (v) {
              if (v == null || v == _zoneId) return;
              setState(() {
                _zoneId = v;
                _wardId = null;
                _wardItems = [];
                _wardError = null;
              });
              _clearError('zone');
              _clearError('ward');
              _loadWards(v);
            },
    );
  }

  Widget _buildWardField() {
    // Disabled until a zone is chosen.
    if (_zoneId == null) {
      return _disabledDropdown('Select a zone first');
    }
    if (_wardLoading) return _loadingField('Loading wards…');
    if (_wardError != null) {
      return GvpInlineError(
        message: _wardError!,
        onRetry: () => _loadWards(_zoneId!),
      );
    }
    return DropdownButtonFormField<int>(
      value: _wardId,
      isExpanded: true,
      decoration: _decor(hint: 'Select ward'),
      items: _wardItems
          .map((w) => DropdownMenuItem(
                value: w.id,
                child: Text(w.code, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: _submitting
          ? null
          : (v) {
              if (v == null) return;
              setState(() => _wardId = v);
              _clearError('ward');
            },
    );
  }

  /// A greyed-out, non-interactive dropdown placeholder used while a dependency
  /// (project / zone) has not been selected yet.
  Widget _disabledDropdown(String hint) {
    return DropdownButtonFormField<int>(
      value: null,
      isExpanded: true,
      decoration: _decor(hint: hint),
      items: const [],
      onChanged: null,
    );
  }

  /// An inline loading row shown in place of a dropdown while its data loads.
  Widget _loadingField(String message) {
    return InputDecorator(
      decoration: _decor(),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(message, style: const TextStyle(fontSize: 13)),
        ],
      ),
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
