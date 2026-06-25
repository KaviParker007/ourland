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

class PendingAttendance extends StatefulWidget {
  const PendingAttendance({super.key});

  @override
  State<PendingAttendance> createState() => _PendingAttendanceState();
}

class _PendingAttendanceState extends State<PendingAttendance> {
  bool isLoading = false;
  bool isLoggedIn = false;
  String? username;
  String? password;
  String? usertype;
  List<dynamic> attendanceList = [];
  List<dynamic> filteredAttendanceList = [];
  DateTime selectedDate = DateTime.now();
  final String baseUrl = AppConfig.apiUrl;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _selectionMode = false;
  List<int> selectedIds = [];

  List<Map<String, dynamic>> _navigationStack = [];

  String _currentView = 'initial';
  String _currentTitle = 'Pending Attendance';
  String _currentProject = '';
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

    print('========================================');
    print('[AUTH] usertype: $usertype');
    print('[AUTH] username: $username');
    print('========================================');

    if (username != null && password != null) {
      setState(() => isLoggedIn = true);
      await _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      isLoading = true;
      _currentView = 'initial';
      _currentTitle = 'Pending Attendance';
      _navigationStack.clear();
      selectedIds.clear();
      _selectionMode = false;
    });

    if (usertype == 'Supervisor' || usertype == 'Vehicle Incharge') {
      await _fetchSupervisorAttendance();
    } else {
      await _fetchProjects();
    }
  }

  Future<void> _refreshCurrentData() async {
    setState(() => isLoading = true);

    try {
      switch (_currentView) {
        case 'initial':
          await _loadInitialData();
          break;
        case 'project':
          await _fetchProjects();
          break;
        case 'zone':
          await _fetchProjectZones(_currentProject);
          break;
        case 'ward':
          await _fetchZoneWards(_currentZoneId, _currentZone);
          break;
        case 'attendance':
          if (usertype == 'Supervisor' || usertype == 'Vehicle Incharge') {
            await _fetchSupervisorAttendance();
          } else if (_currentWardId != 0) {
            await _fetchWardAttendance(_currentWardId, _currentWard);
          }
          break;
      }
    } catch (e) {
      _showError("Error refreshing data: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchSupervisorAttendance() async {
    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final url = "$baseUrl/hr/drf_unmarked_list/?attendance_date=$formattedDate";

      print('========================================');
      print('[API] _fetchSupervisorAttendance');
      print('[URL] GET $url');
      print('========================================');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );

      print('[RESPONSE] Status: ${response.statusCode}');
      print('[RESPONSE] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          attendanceList = data['result'].map((item) {
            return {...item, 'isSelected': false};
          }).toList();
          filteredAttendanceList = attendanceList;
          _currentView = 'attendance';
          _currentTitle = 'Pending Attendance';
        });
      } else {
        _showError("Failed to load attendance: ${response.statusCode}");
      }
    } catch (e) {
      print('[ERROR] _fetchSupervisorAttendance: $e');
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchProjects() async {
    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final url = "$baseUrl/hr/drf_unmarked_dash/?attendance_date=$formattedDate";

      print('========================================');
      print('[API] _fetchProjects');
      print('[URL] GET $url');
      print('========================================');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );

      print('[RESPONSE] Status: ${response.statusCode}');
      print('[RESPONSE] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          attendanceList = data['result'];
          filteredAttendanceList = attendanceList;
          _currentView = 'project';
          _currentTitle = 'Projects';
          _currentZone = '';
          _currentWard = '';
          _currentZoneId = 0;
          _currentWardId = 0;
        });
      } else {
        _showError("Failed to load projects: ${response.statusCode}");
      }
    } catch (e) {
      print('[ERROR] _fetchProjects: $e');
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchProjectZones(String project) async {
    setState(() {
      isLoading = true;
      _navigationStack.add(_getCurrentState());
    });

    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final url = "$baseUrl/hr/drf_unmarked_dash_project/?project=$project&attendance_date=$formattedDate";

      print('========================================');
      print('[API] _fetchProjectZones');
      print('[URL] GET $url');
      print('[PARAM] project: $project');
      print('[PARAM] attendance_date: $formattedDate');
      print('========================================');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );

      print('[RESPONSE] Status: ${response.statusCode}');
      print('[RESPONSE] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          attendanceList = data['result'];
          filteredAttendanceList = attendanceList;
          _currentView = 'zone';
          _currentTitle = 'Zones - $project';
          _currentProject = project;
          _currentZone = '';
          _currentWard = '';
          _currentZoneId = 0;
          _currentWardId = 0;
        });
      } else {
        _showError("Failed to load zones: ${response.statusCode}");
      }
    } catch (e) {
      print('[ERROR] _fetchProjectZones: $e');
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchZoneWards(int zoneId, String zoneName) async {
    setState(() {
      isLoading = true;
      _navigationStack.add(_getCurrentState());
    });

    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final url = "$baseUrl/hr/drf_unmarked_dash_zone/?zone_id=$zoneId&attendance_date=$formattedDate";

      print('========================================');
      print('[API] _fetchZoneWards');
      print('[URL] GET $url');
      print('[PARAM] zone_id: $zoneId');
      print('[PARAM] zone_name: $zoneName');
      print('[PARAM] attendance_date: $formattedDate');
      print('========================================');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );

      print('[RESPONSE] Status: ${response.statusCode}');
      print('[RESPONSE] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          attendanceList = data['result'];
          filteredAttendanceList = attendanceList;
          _currentView = 'ward';
          _currentTitle = 'Wards - $zoneName';
          _currentZone = zoneName;
          _currentZoneId = zoneId;
          _currentWard = '';
          _currentWardId = 0;
        });
      } else {
        _showError("Failed to load wards: ${response.statusCode}");
      }
    } catch (e) {
      print('[ERROR] _fetchZoneWards: $e');
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchWardAttendance(int wardId, String wardName) async {
    setState(() {
      isLoading = true;
      _navigationStack.add(_getCurrentState());
    });

    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final url = "$baseUrl/hr/drf_unmarked_dash_ward/?ward_id=$wardId&attendance_date=$formattedDate";

      print('========================================');
      print('[API] _fetchWardAttendance');
      print('[URL] GET $url');
      print('[PARAM] ward_id: $wardId');
      print('[PARAM] ward_name: $wardName');
      print('[PARAM] attendance_date: $formattedDate');
      print('========================================');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );

      print('[RESPONSE] Status: ${response.statusCode}');
      print('[RESPONSE] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          attendanceList = data['result'].map((item) {
            return {...item, 'isSelected': false};
          }).toList();
          filteredAttendanceList = attendanceList;
          _currentView = 'attendance';
          _currentTitle = 'Attendance - $wardName';
          _currentWard = wardName;
          _currentWardId = wardId;
        });
      } else {
        _showError("Failed to load attendance: ${response.statusCode}");
      }
    } catch (e) {
      print('[ERROR] _fetchWardAttendance: $e');
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Map<String, dynamic> _getCurrentState() {
    return {
      'view': _currentView,
      'title': _currentTitle,
      'project': _currentProject,
      'zone': _currentZone,
      'ward': _currentWard,
      'zoneId': _currentZoneId,
      'wardId': _currentWardId,
      'data': List.from(attendanceList),
      'searchText': _searchController.text,
      'selectedIds': List.from(selectedIds),
      'selectionMode': _selectionMode,
    };
  }

  void _restoreState(Map<String, dynamic> state) {
    setState(() {
      _currentView = state['view'];
      _currentTitle = state['title'];
      _currentProject = state['project'] ?? '';
      _currentZone = state['zone'] ?? '';
      _currentWard = state['ward'] ?? '';
      _currentZoneId = state['zoneId'] ?? 0;
      _currentWardId = state['wardId'] ?? 0;
      attendanceList = state['data'];
      filteredAttendanceList = attendanceList;
      _searchController.text = state['searchText'] ?? '';
      selectedIds = List.from(state['selectedIds'] ?? []);
      _selectionMode = state['selectionMode'] ?? false;
    });
  }

  void _navigateBack() {
    if (_navigationStack.isNotEmpty) {
      final previousState = _navigationStack.removeLast();
      _restoreState(previousState);
    } else {
      _loadInitialData();
    }
  }

  bool _shouldShowBackButton() {
    if (usertype == 'Supervisor' || usertype == 'Vehicle Incharge' || _currentView == 'project') {
      return _selectionMode || _isSearching;
    }
    return _navigationStack.isNotEmpty || _currentView != 'initial';
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
      await _refreshCurrentData();
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        filteredAttendanceList = attendanceList;
      });
    } else {
      setState(() {
        if (_currentView == 'project') {
          filteredAttendanceList = attendanceList.where((item) {
            final project = item['project']?.toString().toLowerCase() ?? '';
            return project.contains(query);
          }).toList();
        } else if (_currentView == 'zone') {
          filteredAttendanceList = attendanceList.where((item) {
            final zone = item['zone']?.toString().toLowerCase() ?? '';
            return zone.contains(query);
          }).toList();
        } else if (_currentView == 'ward') {
          filteredAttendanceList = attendanceList.where((item) {
            final ward = item['ward']?.toString().toLowerCase() ?? '';
            return ward.contains(query);
          }).toList();
        } else if (_currentView == 'attendance') {
          filteredAttendanceList = attendanceList.where((item) {
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
      filteredAttendanceList = attendanceList;
      _isSearching = false;
    });
  }

  void _toggleSelectionMode(bool enabled) {
    setState(() {
      _selectionMode = enabled;
      if (!enabled) {
        attendanceList = attendanceList.map((item) {
          return {...item, 'isSelected': false};
        }).toList();
        filteredAttendanceList = filteredAttendanceList.map((item) {
          return {...item, 'isSelected': false};
        }).toList();
        selectedIds.clear();
      }
    });
  }

  void _showLockedCardMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('This card is locked and cannot be modified'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _toggleItemSelection(int id, bool selected) {
    final item = attendanceList.firstWhere((item) => item['id'] == id, orElse: () => {});
    final bool isLocked = item['lock_card'] ?? false;

    if (isLocked) {
      _showLockedCardMessage(context);
      return;
    }

    setState(() {
      if (selected) {
        selectedIds.add(id);
      } else {
        selectedIds.remove(id);
      }

      attendanceList = attendanceList.map((item) {
        if (item['id'] == id) {
          return {...item, 'isSelected': selected};
        }
        return item;
      }).toList();

      filteredAttendanceList = filteredAttendanceList.map((item) {
        if (item['id'] == id) {
          return {...item, 'isSelected': selected};
        }
        return item;
      }).toList();
    });
  }

  Future<void> _submitBulkAttendance() async {
    if (selectedIds.isEmpty) {
      _showError("Please select at least one attendance record");
      return;
    }

    final List<int> lockedIds = [];
    for (var id in selectedIds) {
      final item = attendanceList.firstWhere((item) => item['id'] == id, orElse: () => {});
      if (item['lock_card'] == true) {
        lockedIds.add(id);
      }
    }

    if (lockedIds.isNotEmpty) {
      _showError("Cannot process locked cards: ${lockedIds.join(', ')}");
      return;
    }

    setState(() => isLoading = true);

    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final url = "$baseUrl/hr/drf_list_n_write_att/";
      final body = {"ma_ids": selectedIds, "confirmation": 1};

      print('========================================');
      print('[API] _submitBulkAttendance');
      print('[URL] POST $url');
      print('[BODY] ${jsonEncode(body)}');
      print('========================================');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
        body: jsonEncode(body),
      );

      print('[RESPONSE] Status: ${response.statusCode}');
      print('[RESPONSE] Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Bulk update successful'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshCurrentData();
      } else {
        _showError("Failed to update attendance: ${response.statusCode}");
      }
    } catch (e) {
      print('[ERROR] _submitBulkAttendance: $e');
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
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
          const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No data found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No records available for ${DateFormat('MMMM dd, yyyy').format(selectedDate)}',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _selectDate(context),
            child: const Text('Select Different Date'),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(dynamic item) {
    final project = item['project']?.toString() ?? 'N/A';
    final unmarked = item['unmarked']?.toString() ?? '0';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            unmarked,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          project,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text('$unmarked unmarked attendance'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _fetchProjectZones(project),
      ),
    );
  }

  Widget _buildZoneCard(dynamic item) {
    final zone = item['zone']?.toString() ?? 'N/A';
    final zoneId = item['zone_id'] ?? 0;
    final unmarked = item['unmarked']?.toString() ?? '0';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green,
          child: Text(
            unmarked,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          zone,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text('$unmarked unmarked attendance'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _fetchZoneWards(zoneId, zone),
      ),
    );
  }

  Widget _buildWardCard(dynamic item) {
    final ward = item['ward']?.toString() ?? 'N/A';
    final wardId = item['ward_id'] ?? 0;
    final unmarked = item['unmarked']?.toString() ?? '0';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange,
          child: Text(
            unmarked,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          ward,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text('$unmarked unmarked attendance'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _fetchWardAttendance(wardId, ward),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return const LoginPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _getSearchHint(),
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSearchQuery,
            ),
          ),
          style: const TextStyle(color: Colors.white),
        )
            : _selectionMode
            ? Text('${selectedIds.length} selected')
            : Text(_currentTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            )),
        leading: _shouldShowBackButton()
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
          tooltip: 'Back',
        )
            : null,
        actions: [
          if (!_isSearching && !_selectionMode)
            const NotificationBellWidget(),
          if (!_isSearching && !_selectionMode)
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _selectDate(context),
              tooltip: 'Select Date',
            ),
          if (!_isSearching && !_selectionMode && _currentView == 'attendance')
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _startSearch,
            ),
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _toggleSelectionMode(false),
            ),
        ],
        bottom: _currentView == 'attendance'
            ? PreferredSize(
          preferredSize: const Size.fromHeight(40.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              DateFormat('MMMM dd, yyyy').format(selectedDate),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        )
            : null,
      ),
      drawer: (_selectionMode || _isSearching) ? null : const AppDrawer(),
      body: Column(
        children: [
          if (_isSearching && _searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '${filteredAttendanceList.length} results found',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshCurrentData,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredAttendanceList.isEmpty
                  ? _buildEmptyState()
                  : _buildCurrentView(),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectionMode &&
          selectedIds.isNotEmpty &&
          _currentView == 'attendance'
          ? FloatingActionButton.extended(
        onPressed: _hasLockedSelectedCards() ? null : _submitBulkAttendance,
        icon: const Icon(Icons.check),
        label: const Text('Confirm Selection'),
        tooltip: _hasLockedSelectedCards() ? 'Selected contains locked cards' : null,
      )
          : null,
    );
  }

  Widget _buildBreadcrumb() {
    List<Widget> breadcrumbItems = [];

    breadcrumbItems.add(
      GestureDetector(
        onTap: _loadInitialData,
        child: Text(
          'Home',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    if (_currentProject.isNotEmpty) {
      breadcrumbItems.add(const Text(' > '));
      breadcrumbItems.add(
        GestureDetector(
          onTap: () {
            while (_navigationStack.isNotEmpty && _currentView != 'project') {
              _navigateBack();
            }
          },
          child: Text(
            _currentProject,
            style: TextStyle(
              color: _currentView == 'project' ? Colors.grey : Colors.blue[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (_currentZone.isNotEmpty) {
      breadcrumbItems.add(const Text(' > '));
      breadcrumbItems.add(
        GestureDetector(
          onTap: () {
            while (_navigationStack.isNotEmpty && _currentView != 'zone') {
              _navigateBack();
            }
          },
          child: Text(
            _currentZone,
            style: TextStyle(
              color: _currentView == 'zone' ? Colors.grey : Colors.blue[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (_currentWard.isNotEmpty) {
      breadcrumbItems.add(const Text(' > '));
      breadcrumbItems.add(
        Text(
          _currentWard,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: breadcrumbItems),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case 'project':
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredAttendanceList.length,
          itemBuilder: (context, index) {
            final item = filteredAttendanceList[index];
            return _buildProjectCard(item);
          },
        );
      case 'zone':
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredAttendanceList.length,
          itemBuilder: (context, index) {
            final item = filteredAttendanceList[index];
            return _buildZoneCard(item);
          },
        );
      case 'ward':
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredAttendanceList.length,
          itemBuilder: (context, index) {
            final item = filteredAttendanceList[index];
            return _buildWardCard(item);
          },
        );
      case 'attendance':
        return AttendanceListBuilder2(
          attendanceList: _isSearching ? filteredAttendanceList : attendanceList,
          onAttendanceMarked: _refreshCurrentData,
          selectionMode: _selectionMode,
          onSelectionModeChanged: _toggleSelectionMode,
          onItemSelected: _toggleItemSelection,
          currentPage: 1,
          totalPages: 1,
          nextPageUrl: null,
          previousPageUrl: null,
          onPageChanged: (page) {},
          isManager: false,
        );
      default:
        return const Center(child: CircularProgressIndicator());
    }
  }

  String _getSearchHint() {
    switch (_currentView) {
      case 'project':
        return 'Search projects...';
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

  bool _hasLockedSelectedCards() {
    for (var id in selectedIds) {
      final item = attendanceList.firstWhere((item) => item['id'] == id, orElse: () => {});
      if (item['lock_card'] == true) {
        return true;
      }
    }
    return false;
  }
}

class AttendanceListBuilder2 extends StatefulWidget {
  final List<dynamic> attendanceList;
  final VoidCallback onAttendanceMarked;
  final bool selectionMode;
  final Function(bool)? onSelectionModeChanged;
  final Function(int, bool)? onItemSelected;
  final int currentPage;
  final int? totalPages;
  final String? nextPageUrl;
  final String? previousPageUrl;
  final Function(int) onPageChanged;
  final bool isManager;

  const AttendanceListBuilder2({
    super.key,
    required this.attendanceList,
    required this.onAttendanceMarked,
    this.selectionMode = false,
    this.onSelectionModeChanged,
    this.onItemSelected,
    required this.currentPage,
    this.totalPages,
    this.nextPageUrl,
    this.previousPageUrl,
    required this.onPageChanged,
    required this.isManager,
  });

  @override
  State<AttendanceListBuilder2> createState() => _AttendanceListBuilder2State();
}

class _AttendanceListBuilder2State extends State<AttendanceListBuilder2>
    with SingleTickerProviderStateMixin {
  late final SlidableController controller = SlidableController(this);
  bool isLoading = false;
  bool isLoggedIn = false;
  String? username;
  String? password;
  final String baseUrl = AppConfig.apiUrl;

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username');
    password = prefs.getString('password');

    return {
      'Content-Type': 'application/json',
      'authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}'
    };
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

  Future<void> _markAttendance({
    required int id,
    required String code,
    required String remark,
    required int manualStatus,
  }) async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      username = prefs.getString('username');
      password = prefs.getString('password');

      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final url = "$baseUrl/hr/drf_list_n_write_att/";
      final body = {
        "ma_id": id,
        "manual_present": manualStatus,
        "att_remark": remark,
      };

      print('========================================');
      print('[API] _markAttendance (Single)');
      print('[URL] POST $url');
      print('[PARAM] id: $id | code: $code | manualStatus: $manualStatus | remark: $remark');
      print('[BODY] ${jsonEncode(body)}');
      print('========================================');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
        body: jsonEncode(body),
      );

      print('[RESPONSE] Status: ${response.statusCode}');
      print('[RESPONSE] Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _showSuccessPopup(context, result['message']);
      } else {
        _showError("Failed to update attendance: ${response.statusCode}");
      }
    } catch (e) {
      print('[ERROR] _markAttendance: $e');
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSuccessPopup(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Attendance marked successfully',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onAttendanceMarked();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRemarkDialog({
    required BuildContext context,
    required int id,
    required String code,
    required Function(int, String, String) onSave,
    required String dialogTitle,
  }) {
    final remarkController = TextEditingController();
    final focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note, size: 28, color: Colors.deepPurple),
                  const SizedBox(width: 12),
                  Text(
                    dialogTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: remarkController,
                focusNode: focusNode,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Write your remarks here...',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 1.5,
                    ),
                  ),
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
                          const SnackBar(content: Text('Please write remarks')),
                        );
                        focusNode.requestFocus();
                        return;
                      }
                      Navigator.pop(context);
                      onSave(id, code, remark);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.previousPageUrl != null)
            ElevatedButton(
              onPressed: () {
                final prevPage = _extractPageFromUrl(widget.previousPageUrl);
                widget.onPageChanged(prevPage);
              },
              child: const Text('Prev'),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Page ${widget.currentPage} of ${widget.totalPages ?? 1}',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (widget.nextPageUrl != null)
            ElevatedButton(
              onPressed: () {
                final nextPage = _extractPageFromUrl(widget.nextPageUrl) ?? widget.currentPage + 1;
                widget.onPageChanged(nextPage);
              },
              child: const Text('Next'),
            ),
        ],
      ),
    );
  }

  int _extractPageFromUrl(String? url) {
    if (url == null) return 1;
    try {
      Uri uri = Uri.parse(url);
      String pageString = uri.queryParameters['page'] ?? '1';
      return int.tryParse(pageString) ?? 1;
    } catch (e) {
      return 1;
    }
  }

  Widget _buildSupervisorCard(dynamic item, BuildContext context) {
    final employeeId = item['id']?.toString() ?? 'N/A';
    final employeeCode = item['essl_code']?.toString() ?? 'N/A';
    final employeeName = item['employee_name']?.toString() ?? 'N/A';
    final color = item['color_code']?.toString() ?? '#4a4d52';
    final esslStatus = item['essl_status'] ?? false;
    final esslWritten = item['essl_written'] ?? false;
    final manualPresent = item['manual_present'] ?? false;
    final isConflicted = item['is_conflicted'] ?? false;
    final lockCard = item['lock_card'] ?? false;
    final designation = item['designation']?.toString() ?? 'N/A';
    final zone = item['zone']?.toString() ?? 'N/A';
    final ward = item['ward']?.toString() ?? 'N/A';

    Color cardColor;
    try {
      cardColor = Color(int.parse(color.replaceAll('#', '0xFF')));
    } catch (e) {
      cardColor = Colors.grey[300]!;
    }
    final textColor = _contrastColor(cardColor);

    final esslInTime = item['essl_intime'];
    final esslInMethod = item['essl_in_method'];
    final esslOutTime = item['essl_out_time'];
    final esslOutMethod = item['essl_out_method'];
    final IdNum = item['id']?.toString() ?? 'N/A';
    final employeeIdNum = item['employee_id']?.toString() ?? 'N/A';

    return !lockCard
        ? Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: InkWell(
        onLongPress: () {
          if (lockCard) {
            _showLockedCardMessage(context);
            return;
          }
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
                onChanged: lockCard
                    ? null
                    : (value) {
                  if (widget.onItemSelected != null) {
                    widget.onItemSelected!(item['id'], value ?? false);
                  }
                },
              ),
            Expanded(
              child: Slidable(
                key: Key(item['id'].toString()),
                enabled: !lockCard,
                startActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (context) {
                        final haveBiometric = item['have_biometric'] ?? false; // 👈 Get the flag

                        if (!haveBiometric) {
                          // ✅ No biometric — mark directly without remark dialog
                          _markAttendance(
                            id: item['id'],
                            code: employeeCode,
                            remark: '',
                            manualStatus: 0,
                          );
                        } else if (esslStatus || manualPresent) {
                          // ✅ Has biometric AND already marked — show remark dialog
                          _showRemarkDialog(
                            context: context,
                            id: item['id'],
                            code: employeeCode,
                            onSave: (id, code, remark) => _markAttendance(
                              id: id,
                              code: code,
                              remark: remark,
                              manualStatus: 0,
                            ),
                            dialogTitle: 'Mark as Absent',
                          );
                        } else {
                          // ✅ Has biometric, not yet marked — mark directly
                          _markAttendance(
                            id: item['id'],
                            code: employeeCode,
                            remark: '',
                            manualStatus: 0,
                          );
                        }
                      },
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      borderRadius: BorderRadius.circular(15),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      icon: Icons.cancel,
                      label: 'Absent',
                    ),
                  ],
                ),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (context) {
                        final haveBiometric = item['have_biometric'] ?? false; // 👈 Get the flag

                        if (!haveBiometric) {
                          // ✅ No biometric — mark directly without remark dialog
                          _markAttendance(
                            id: item['id'],
                            code: employeeCode,
                            remark: '',
                            manualStatus: 1,
                          );
                        } else if (!esslStatus && !manualPresent) {
                          // ✅ Has biometric AND not yet marked — show remark dialog
                          _showRemarkDialog(
                            context: context,
                            id: item['id'],
                            code: employeeCode,
                            onSave: (id, code, remark) => _markAttendance(
                              id: id,
                              code: code,
                              remark: remark,
                              manualStatus: 1,
                            ),
                            dialogTitle: 'Mark as Present',
                          );
                        } else {
                          // ✅ Has biometric, already marked — mark directly
                          _markAttendance(
                            id: item['id'],
                            code: employeeCode,
                            remark: '',
                            manualStatus: 1,
                          );
                        }
                      },
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green,
                      borderRadius: BorderRadius.circular(15),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      icon: Icons.check_circle,
                      label: 'Present',
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              employeeName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          if (lockCard)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(Icons.lock,
                                  size: 16,
                                  color: textColor.withOpacity(0.7)),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '#$IdNum',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Divider(color: textColor.withOpacity(0.3), height: 1),
                      const SizedBox(height: 8),
                      _buildInfoRow('EMPLOYEE CODE', employeeIdNum, textColor),
                      _buildInfoRow('WARD', ward, textColor),
                      _buildInfoRow('ESSL', employeeCode, textColor),
                      _buildTimeMethodGroup('LOGIN', esslInTime, esslInMethod, textColor),
                      _buildTimeMethodGroup('LOGOUT', esslOutTime, esslOutMethod, textColor),
                      _buildInfoRow('DESIGNATION', designation, textColor),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        : Container();
  }

  Color _contrastColor(Color bg) =>
      bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

  String _safeVal(dynamic value) {
    if (value == null) return 'N/A';
    final s = value.toString();
    return (s.isEmpty || s.toLowerCase() == 'null') ? 'N/A' : s;
  }

  Widget _buildTimeMethodGroup(
      String title, dynamic time, dynamic method, Color textColor) {
    final timeVal = _safeVal(time);
    final methodVal = _safeVal(method);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$title:',
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        'TIME:',
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        timeVal,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        'METHOD:',
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        methodVal,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLockedCardMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('This card is locked and cannot be modified'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.attendanceList.length,
            itemBuilder: (context, index) {
              final item = widget.attendanceList[index];
              print('item___check');
              print(item);
              return _buildSupervisorCard(item, context);
            },
          ),
        ),
        if (widget.totalPages != null && widget.totalPages! > 1)
          _buildPaginationControls(),
      ],
    );
  }
}