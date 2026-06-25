import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../components/drawer_page.dart';
import '../../config.dart';
import '../login.dart';
import 'package:ourlandnew/pages/notifications/notification_bell.dart';

class ConflictsPage extends StatefulWidget {
  const ConflictsPage({super.key});

  @override
  State<ConflictsPage> createState() => _ConflictsPageState();
}

class _ConflictsPageState extends State<ConflictsPage> {
  bool isLoading = false;
  bool isLoggedIn = false;
  String? username;
  String? password;
  String? usertype;
  List<dynamic> conflictsList = [];
  List<dynamic> filteredConflictsList = [];
  DateTime selectedDate = DateTime.now();
  final String baseUrl = AppConfig.apiUrl;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _selectionMode = false;
  List<int> selectedIds = [];

  // Navigation stack for hierarchical navigation
  List<Map<String, dynamic>> _navigationStack = [];

  // Current view state
  String _currentView = 'initial'; // 'initial', 'zone', 'ward', 'attendance'
  String _currentTitle = 'Conflicts';
  String _currentZone = '';
  String _currentWard = '';
  int _currentZoneId = 0;
  int _currentWardId = 0;

  String get formattedDate => DateFormat('yyyy-MM-dd').format(selectedDate);

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username');
    password = prefs.getString('password');
    usertype = prefs.getString('usertype');

    if (username != null && password != null) {
      setState(() => isLoggedIn = true);
      await _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      isLoading = true;
      _currentView = 'initial';
      _currentTitle = 'Conflicts';
      _navigationStack.clear();
      selectedIds.clear();
      _selectionMode = false;
    });

    await _fetchZones();
  }

  Future<void> _refreshCurrentData() async {
    setState(() => isLoading = true);

    try {
      switch (_currentView) {
        case 'initial':
        case 'zone':
          await _fetchZones();
          break;
        case 'ward':
          if (_currentZoneId != 0) {
            await _fetchZoneWards(_currentZoneId, _currentZone);
          }
          break;
        case 'attendance':
          if (_currentWardId != 0) {
            await _fetchWardConflicts(_currentWardId, _currentWard);
          }
          break;
      }
    } catch (e) {
      _showError("Error refreshing data: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchZones() async {
    setState(() {
      isLoading = true;
    });

    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final response = await http.get(
        Uri.parse("$baseUrl/hr/drf_att_dash_by_zone/?date=$formattedDate"),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          conflictsList = data;
          filteredConflictsList = conflictsList;
          _currentView = 'zone';
          _currentTitle = 'Zones';

          // Clear child data
          _currentZone = '';
          _currentWard = '';
          _currentZoneId = 0;
          _currentWardId = 0;

          // Clear selections
          selectedIds.clear();
          _selectionMode = false;

          // Clear navigation stack when loading zones
          _navigationStack.clear();
        });
      } else {
        _showError("Failed to load zones: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchZoneWards(int zoneId, String zoneName) async {
    setState(() {
      isLoading = true;
    });

    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final response = await http.get(
        Uri.parse("$baseUrl/hr/drf_att_dash_by_ward/?zone_id=$zoneId&date=$formattedDate"),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          conflictsList = data;
          filteredConflictsList = conflictsList;
          _currentView = 'ward';
          _currentTitle = 'Wards - $zoneName';
          _currentZone = zoneName;
          _currentZoneId = zoneId;

          // Clear child data
          _currentWard = '';
          _currentWardId = 0;

          // Clear selection when loading new data
          selectedIds.clear();
          _selectionMode = false;

          // Push to navigation stack AFTER successful load
          _pushToNavigationStack('zone', 'Zones', zoneId, zoneName, 0, '');
        });
      } else {
        _showError("Failed to load wards: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchWardConflicts(int wardId, String wardName) async {
    setState(() {
      isLoading = true;
      // Push current state to navigation stack BEFORE loading new data
      _pushToNavigationStack(
        _currentView,
        _currentTitle,
        _currentZoneId,
        _currentZone,
        wardId,
        wardName,
        preserveData: false, // Don't preserve old data
      );
    });

    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final response = await http.get(
        Uri.parse("$baseUrl/hr/drf_list_ward_att_by_query/?ward_id=$wardId&att_status=conflicts&date=$formattedDate"),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );
      print("$baseUrl/hr/drf_list_ward_att_by_query/?ward_id=$wardId&att_status=conflicts&date=$formattedDate");
      print(response.statusCode);
      print(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          conflictsList = data.map((item) {
            return {...item, 'isSelected': false};
          }).toList();
          filteredConflictsList = conflictsList;
          _currentView = 'attendance';
          _currentTitle = 'Conflicts - $wardName';
          _currentWard = wardName;
          _currentWardId = wardId;
        });
      } else {
        _showError("Failed to load conflicts: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _pushToNavigationStack(
      String view,
      String title,
      int zoneId,
      String zone,
      int wardId,
      String ward, {
        bool preserveData = false,
      }) {
    // Create state object with current date
    final state = {
      'view': view,
      'title': title,
      'zone': zone,
      'ward': ward,
      'zoneId': zoneId,
      'wardId': wardId,
      'date': selectedDate, // Store the date in navigation stack
      'searchText': _searchController.text,
      'selectedIds': List.from(selectedIds),
      'selectionMode': _selectionMode,
    };

    // Avoid duplicate entries
    if (_navigationStack.isEmpty ||
        _navigationStack.last['view'] != view ||
        _navigationStack.last['zoneId'] != zoneId ||
        _navigationStack.last['wardId'] != wardId) {
      _navigationStack.add(state);
    }
  }

  void _restoreState(Map<String, dynamic> state) {
    // Check if the date in the state is different from current date
    final DateTime? stateDate = state['date'];
    final bool dateChanged = stateDate != null &&
        DateFormat('yyyy-MM-dd').format(stateDate) != formattedDate;

    setState(() {
      _currentView = state['view'];
      _currentTitle = state['title'];
      _currentZone = state['zone'] ?? '';
      _currentWard = state['ward'] ?? '';
      _currentZoneId = state['zoneId'] ?? 0;
      _currentWardId = state['wardId'] ?? 0;

      // Clear existing data
      conflictsList = [];
      filteredConflictsList = [];

      // Restore UI state (but only if date hasn't changed)
      if (!dateChanged) {
        _searchController.text = state['searchText'] ?? '';
        selectedIds = List.from(state['selectedIds'] ?? []);
        _selectionMode = state['selectionMode'] ?? false;
      } else {
        // Clear search and selections if date changed
        _searchController.clear();
        selectedIds.clear();
        _selectionMode = false;
      }
    });

    // Fetch fresh data based on restored view and current date
    if (_currentView == 'zone') {
      _fetchZones();
    } else if (_currentView == 'ward') {
      if (_currentZoneId != 0) {
        _fetchZoneWards(_currentZoneId, _currentZone);
      }
    } else if (_currentView == 'attendance') {
      if (_currentWardId != 0) {
        _fetchZoneWards(_currentZoneId, _currentZone);
      //  _fetchWardConflicts(_currentWardId, _currentWard);
      }
    }
  }

  void _navigateBack() {
    if (_navigationStack.isNotEmpty) {
      final previousState = _navigationStack.removeLast();
      _restoreState(previousState);
    } else {
      // If no navigation stack, go to initial data with current date
      _loadInitialData();
    }
  }

  // This method should be called after resolving conflicts
  void _handleConflictResolved() {
    // Refresh the current data
    _refreshCurrentData();

    // Show a message to indicate successful resolution
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conflict resolved successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _shouldShowBackButton() {
    // Show back button only if we're not at the root level
    if (_currentView == 'zone' && _navigationStack.isEmpty) {
      return false;
    }
    return _navigationStack.isNotEmpty || _selectionMode || _isSearching;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });

      // Clear navigation stack when date changes
      _navigationStack.clear();

      // Clear selections
      selectedIds.clear();
      _selectionMode = false;

      // Navigate to zone level with new date
      setState(() {
        _currentView = 'zone';
        _currentTitle = 'Zones';
        _currentZone = '';
        _currentWard = '';
        _currentZoneId = 0;
        _currentWardId = 0;
      });

      // Fetch zones with new date
      await _fetchZones();

      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Date changed to ${DateFormat('MMMM dd, yyyy').format(selectedDate)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        filteredConflictsList = conflictsList;
      });
    } else {
      setState(() {
        if (_currentView == 'zone') {
          filteredConflictsList = conflictsList.where((item) {
            final zoneCode = item['zone_code']?.toString().toLowerCase() ?? '';
            return zoneCode.contains(query);
          }).toList();
        } else if (_currentView == 'ward') {
          filteredConflictsList = conflictsList.where((item) {
            final wardCode = item['ward_code']?.toString().toLowerCase() ?? '';
            return wardCode.contains(query);
          }).toList();
        } else if (_currentView == 'attendance') {
          filteredConflictsList = conflictsList.where((item) {
            final code = item['essl_code']?.toString().toLowerCase() ?? '';
            final name = item['employee_name']?.toString().toLowerCase() ?? '';
            return code.contains(query) || name.contains(query);
          }).toList();
        }
      });
    }
  }

  void _startSearch() {
    ModalRoute.of(context)?.addLocalHistoryEntry(
      LocalHistoryEntry(onRemove: _stopSearching),
    );
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearching() {
    _clearSearchQuery();
    setState(() {
      _isSearching = false;
    });
  }

  void _clearSearchQuery() {
    setState(() {
      _searchController.clear();
      filteredConflictsList = conflictsList;
      _isSearching = false;
    });
  }

  void _toggleSelectionMode(bool enabled) {
    setState(() {
      _selectionMode = enabled;
      if (!enabled) {
        conflictsList = conflictsList.map((item) {
          return {...item, 'isSelected': false};
        }).toList();
        filteredConflictsList = filteredConflictsList.map((item) {
          return {...item, 'isSelected': false};
        }).toList();
        selectedIds.clear();
      }
    });
  }

  void _toggleItemSelection(int id, bool selected) {
    setState(() {
      if (selected) {
        selectedIds.add(id);
      } else {
        selectedIds.remove(id);
      }

      conflictsList = conflictsList.map((item) {
        if (item['id'] == id) {
          return {...item, 'isSelected': selected};
        }
        return item;
      }).toList();

      filteredConflictsList = filteredConflictsList.map((item) {
        if (item['id'] == id) {
          return {...item, 'isSelected': selected};
        }
        return item;
      }).toList();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _currentView == 'attendance' ? Icons.confirmation_number : Icons.info_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _getEmptyStateMessage(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyStateSubtitle(),
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (_currentView == 'zone' || _currentView == 'ward') ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _selectDate(context),
              child: const Text('Select Different Date'),
            ),
          ],
        ],
      ),
    );
  }

  String _getEmptyStateMessage() {
    switch (_currentView) {
      case 'zone':
        return 'No zones found';
      case 'ward':
        return 'No wards found';
      case 'attendance':
        return 'No conflicts found';
      default:
        return 'No data found';
    }
  }

  String _getEmptyStateSubtitle() {
    switch (_currentView) {
      case 'zone':
        return 'No zone data available for ${DateFormat('MMMM dd, yyyy').format(selectedDate)}';
      case 'ward':
        return 'No ward data available for $_currentZone on ${DateFormat('MMMM dd, yyyy').format(selectedDate)}';
      case 'attendance':
        return 'No conflict records for $_currentWard';
      default:
        return '';
    }
  }

  Widget _buildZoneCard(dynamic item) {
    final zoneCode = item['zone_code']?.toString() ?? 'N/A';
    final zoneId = item['zone_id'] ?? 0;
    final strength = item['strength']?.toString() ?? '0';
    final esslPresent = item['essl_present']?.toString() ?? '0';
    final manualPresent = item['manual_present_count']?.toString() ?? '0';
    final conflicts = item['conflicts']?.toString() ?? '0';
    final resolved = item['resolved']?.toString() ?? '0';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: () => _fetchZoneWards(zoneId, zoneCode),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      zoneCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Conflicts: $conflicts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('Strength', strength, Colors.blue),
                  _buildStatColumn('ESSL', esslPresent, Colors.green),
                  _buildStatColumn('Manual', manualPresent, Colors.purple),
                  _buildStatColumn('Resolved', resolved, Colors.teal),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWardCard(dynamic item) {
    final wardCode = item['ward_code']?.toString() ?? 'N/A';
    final wardId = item['ward_id'] ?? 0;
    final strength = item['strength']?.toString() ?? '0';
    final esslPresent = item['essl_present']?.toString() ?? '0';
    final manualPresent = item['manual_present_count']?.toString() ?? '0';
    final conflicts = item['conflicts']?.toString() ?? '0';
    final resolved = item['resolved']?.toString() ?? '0';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: () => _fetchWardConflicts(wardId, wardCode),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      wardCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Conflicts: $conflicts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('Strength', strength, Colors.blue),
                  _buildStatColumn('ESSL', esslPresent, Colors.green),
                  _buildStatColumn('Manual', manualPresent, Colors.purple),
                  _buildStatColumn('Resolved', resolved, Colors.teal),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return const LoginPage();
    }
    return WillPopScope(
      onWillPop: () async {
        _navigateBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: _getSearchHint(),
              hintStyle: const TextStyle(color: Colors.white70),
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white),
                onPressed: _clearSearchQuery,
              ),
            ),
            style: const TextStyle(color: Colors.white),
          )
              : _selectionMode
              ? Text('${selectedIds.length} selected', style: const TextStyle(color: Colors.white))
              : Text(_currentTitle, style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          )),
          leading: _shouldShowBackButton()
              ? IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _navigateBack,
            tooltip: 'Back',
          )
              : null,
          actions: [
            if (!_isSearching && !_selectionMode)
              const NotificationBellWidget(),
            // Show date picker only at zone level or ward level
            if (!_isSearching && !_selectionMode && (_currentView == 'zone' || _currentView == 'ward'))
              IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.white),
                onPressed: () => _selectDate(context),
                tooltip: 'Select Date',
              ),
            if (!_isSearching && !_selectionMode && _currentView == 'attendance')
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: _startSearch,
              ),
            if (_selectionMode)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => _toggleSelectionMode(false),
              ),
          ],
          bottom: _currentView != 'initial' ? PreferredSize(
            preferredSize: const Size.fromHeight(40.0),
            child: Container(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _getDateDisplayText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ) : null,
        ),
        drawer: (_selectionMode || _isSearching) ? null : const AppDrawer(),
        body: Column(
          children: [
            if (_isSearching && _searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '${filteredConflictsList.length} results found',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshCurrentData,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredConflictsList.isEmpty
                    ? _buildEmptyState()
                    : _buildCurrentView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDateDisplayText() {
    if (_currentView == 'zone') {
      return 'Date: ${DateFormat('MMMM dd, yyyy').format(selectedDate)}';
    } else if (_currentView == 'ward') {
      return 'Zone: $_currentZone | Date: ${DateFormat('MMMM dd, yyyy').format(selectedDate)}';
    } else if (_currentView == 'attendance') {
      return 'Ward: $_currentWard';
    }
    return '';
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case 'zone':
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredConflictsList.length,
          itemBuilder: (context, index) {
            final item = filteredConflictsList[index];
            return _buildZoneCard(item);
          },
        );
      case 'ward':
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredConflictsList.length,
          itemBuilder: (context, index) {
            final item = filteredConflictsList[index];
            return _buildWardCard(item);
          },
        );
      case 'attendance':
        return ConflictsListBuilder(
          conflictsList: _isSearching ? filteredConflictsList : conflictsList,
          onConflictResolved: _handleConflictResolved, // Use the new handler
          selectionMode: _selectionMode,
          onSelectionModeChanged: _toggleSelectionMode,
          onItemSelected: _toggleItemSelection,
        );
      default:
        return const Center(child: CircularProgressIndicator());
    }
  }

  String _getSearchHint() {
    switch (_currentView) {
      case 'zone':
        return 'Search zones...';
      case 'ward':
        return 'Search wards...';
      case 'attendance':
        return 'Search by code or name...';
      default:
        return 'Search...';
    }
  }
}

class ConflictsListBuilder extends StatefulWidget {
  final List<dynamic> conflictsList;
  final VoidCallback onConflictResolved;
  final bool selectionMode;
  final Function(bool)? onSelectionModeChanged;
  final Function(int, bool)? onItemSelected;

  const ConflictsListBuilder({
    super.key,
    required this.conflictsList,
    required this.onConflictResolved,
    this.selectionMode = false,
    this.onSelectionModeChanged,
    this.onItemSelected,
  });

  @override
  State<ConflictsListBuilder> createState() => _ConflictsListBuilderState();
}

class _ConflictsListBuilderState extends State<ConflictsListBuilder>
    with SingleTickerProviderStateMixin {
  late final SlidableController controller = SlidableController(this);
  bool isLoading = false;
  String? username;
  String? password;
  final String baseUrl = AppConfig.apiUrl;

  // Status choices for conflict resolution
  final List<String> _statusChoices = ['unmarked', 'present', 'absent'];
  String? _selectedStatus;

  Future<void> _resolveConflict({
    required int id,
    required String remark,
    required String status,
  }) async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      username = prefs.getString('username');
      password = prefs.getString('password');

      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final response = await http.post(
        Uri.parse("$baseUrl/hr/drf_list_ward_att_by_query/"),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
        body: jsonEncode({
          "id": id,
          "zonalmanager_remark": remark,
          "zonalmanager_att": status,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);

        // Close any open dialogs
        Navigator.pop(context);

        // Show success message
        _showSuccessMessage(result['message'] ?? 'Conflict resolved successfully');

        // Call the callback to refresh data
        widget.onConflictResolved();
      } else {
        final result = jsonDecode(response.body);
        _showError(result['error'] ?? 'Failed to resolve conflict');
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showResolveDialog({
    required BuildContext context,
    required int id,
    required String employeeName,
    required String employeeCode,
  }) {
    final remarkController = TextEditingController();
    final focusNode = FocusNode();
    _selectedStatus = 'unmarked'; // Default value

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber, size: 28, color: Colors.orange),
                      const SizedBox(width: 12),
                      const Text(
                        'Resolve Conflict',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          employeeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: $employeeCode',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Select Status',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    items: _statusChoices.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedStatus = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: remarkController,
                    focusNode: focusNode,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter remarks...',
                      labelText: 'Remarks',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          final remark = remarkController.text.trim();
                          if (remark.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter remarks')),
                            );
                            focusNode.requestFocus();
                            return;
                          }
                          if (_selectedStatus == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select a status')),
                            );
                            return;
                          }

                          // Don't pop here - let _resolveConflict handle it
                          _resolveConflict(
                            id: id,
                            remark: remark,
                            status: _selectedStatus!,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Text('Resolve'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConflictCard(dynamic item, BuildContext context) {
    final employeeId = item['id']?.toString() ?? 'N/A';
    final employeeCode = item['essl_code']?.toString() ?? 'N/A';
    final employeeName = item['employee_name']?.toString() ?? 'N/A';
    final color = item['color_code']?.toString() ?? '#4a4d52';
    final esslStatus = item['essl_status'] ?? false;
    final manualPresent = item['manual_present'] ?? false;
    final designation = item['designation']?.toString() ?? 'N/A';
    final zone = item['zone']?.toString() ?? 'N/A';
    final ward = item['ward']?.toString() ?? 'N/A';
    final remark = item['att_remark']?.toString() ?? 'N/A';

    // Convert hex color to Color
    Color cardColor;
    try {
      cardColor = Color(int.parse(color.replaceAll('#', '0xFF')));
    } catch (e) {
      cardColor = Colors.grey[300]!;
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: InkWell(
        onLongPress: () {
          if (widget.onSelectionModeChanged != null) {
            widget.onSelectionModeChanged!(true);
            if (widget.onItemSelected != null) {
              widget.onItemSelected!(item['id'], true);
            }
          }
        },
        child: Row(
          children: [
            if (widget.selectionMode)
              Checkbox(
                value: item['isSelected'] ?? false,
                onChanged: (value) {
                  if (widget.onItemSelected != null) {
                    widget.onItemSelected!(
                        item['id'],
                        value ?? false
                    );
                  }
                },
              ),
            Expanded(
              child: Slidable(
                key: Key(item['id'].toString()),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (context) {
                        _showResolveDialog(
                          context: context,
                          id: item['id'],
                          employeeName: employeeName,
                          employeeCode: employeeCode,
                        );
                      },
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orange,
                      borderRadius: BorderRadius.circular(15),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      icon: Icons.check_circle,
                      label: 'Resolve',
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        employeeCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Conflict',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employeeName),
                      Text('ID: $employeeId'),
                      Text('Designation: $designation'),
                      Text('Zone: $zone | Ward: $ward'),
                      Text('ESSL: ${esslStatus ? 'Present' : 'Absent'}'),
                      Text('Manual: ${manualPresent ? 'Present' : 'Absent'}'),
                      Text('Remark: $remark'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.conflictsList.length,
      itemBuilder: (context, index) {
        final item = widget.conflictsList[index];
        return _buildConflictCard(item, context);
      },
    );
  }
}