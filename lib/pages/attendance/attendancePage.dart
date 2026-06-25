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

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool isLoading = false;
  bool isLoggedIn = false;
  String? username;
  String? password;
  List<dynamic> attendanceList = [];
  List<dynamic> filteredAttendanceList = [];
  DateTime selectedDate = DateTime.now();
  final String baseUrl = AppConfig.apiUrl;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _selectionMode = false;
  List<int> selectedIds = [];
  bool _isManager = false;
  bool _isZoneView = false;
  bool _isWardView = false; // New flag for ward view
  String _currentZoneName = '';
  int _currentZoneId = 0;
  String _currentWardName = ''; // New variable for current ward name
  int _currentWardId = 0; // New variable for current ward ID
  bool _isFromAllView = false;
  // Pagination variables
  int currentPage = 1;
  int? totalPages;
  int? totalItems;
  String? nextPageUrl;
  String? previousPageUrl;

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
    if (username != null && password != null) {
      setState(() => isLoggedIn = true);
      await _fetchAttendance(currentPage);
    }
  }

  Future<void> _fetchAttendance(int page) async {
    setState(() {
      isLoading = true;
      currentPage = page;
      selectedIds.clear();
      _selectionMode = false;
      _isZoneView = false;
      _isWardView = false; // Reset ward view
      _currentZoneName = '';
      _currentZoneId = 0;
      _currentWardName = ''; // Reset ward name
      _currentWardId = 0; // Reset ward ID
    });

    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final response = await http.get(
        Uri.parse(
            "$baseUrl/hr/drf_list_n_write_att/?attendance_date=$formattedDate"),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );
      print('checkkkk__1');
      print("$baseUrl/hr/drf_list_n_write_att/?attendance_date=$formattedDate");
      print(response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final format = data['format'];

        setState(() {
          print('checkkkk__3');
          _isManager = format == 'zones';
          attendanceList = data['result'].map((item) {
            print('checkkkk__4');
            return {...item, 'isSelected': false};
          }).toList();
          print('checkkkk__5');
          filteredAttendanceList = attendanceList;
          print('checkkkk__6');
          if (!_isManager) {
            print('checkkkk__7');
            totalItems = data['result'].length;
            totalPages = 1;
          }
          print('checkkkk__8');
        });
      } else {
        _showError("Failed to load attendancej: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchZoneAttendance(int zoneId, String zoneName) async {
    setState(() {
      isLoading = true;
      _isZoneView = true;
      _isWardView = false; // Not in ward view yet
      _currentZoneName = zoneName;
      _currentZoneId = zoneId;
      _currentWardName = ''; // Reset ward name
      _currentWardId = 0; // Reset ward ID
    });

    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final response = await http.get(
        Uri.parse(
            "$baseUrl/hr/drf_list_zonal_wards/?attendance_date=$formattedDate&zone_id=$zoneId"),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );
      print('checkkkk__23');
      print(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          attendanceList = data['result'].map((item) {
            return {...item, 'isSelected': false};
          }).toList();
          filteredAttendanceList = attendanceList;
          totalItems = data['result'].length;
          totalPages = 1;
        });
      } else {
        _showError("Failed to load zone attendance: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // New method to fetch ward attendance
  Future<void> _fetchWardAttendance(int wardId, String wardName) async {
    setState(() {
      isLoading = true;
      _isWardView = true;
      _isFromAllView = false;
      _currentWardName = wardName;
      _currentWardId = wardId;
    });

    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final response = await http.get(
        Uri.parse(
            "$baseUrl/hr/drf_list_zone_n_ward_att/?attendance_date=$formattedDate&ward_id=$wardId"),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );
      print('response.statusCode');

      print(
          "$baseUrl/hr/drf_list_zone_n_ward_att/?attendance_date=$formattedDate&ward_id=$wardId");
      print(response.statusCode);
      print(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          attendanceList = data['result'].map((item) {
            return {...item, 'isSelected': false};
          }).toList();
          filteredAttendanceList = attendanceList;
          totalItems = data['result'].length;
          totalPages = 1;
        });
      } else {
        _showError("Failed to load ward attendance: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchZoneAttendanceAll(int wardId, String wardName) async {
    setState(() {
      isLoading = true;
      _isWardView = true;
      _isFromAllView = true;
      _currentWardName = wardName;
      _currentWardId = wardId;
    });

    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final response = await http.get(
        Uri.parse(
            "$baseUrl/hr/drf_list_zone_n_ward_att/?attendance_date=$formattedDate&zone_id=$wardId"),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
        //body: jsonEncode({"zone": wardId})
      );
      print('response.statusCodellll');
      print(_isFromAllView);
      print(
          "$baseUrl/hr/drf_list_zone_n_ward_att/?attendance_date=$formattedDate&zone_id=$wardId");
      print(wardId);
      print(response.statusCode);
      print(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          attendanceList = data['result'].map((item) {
            return {...item, 'isSelected': false};
          }).toList();
          filteredAttendanceList = attendanceList;
          totalItems = data['result'].length;
          totalPages = 1;
        });
      } else {
        _showError("Failed to load ward attendance: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
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
      if (_isWardView && !_isFromAllView) {
        await _fetchWardAttendance(_currentWardId, _currentWardName);
      } else if (_isZoneView && _isFromAllView) {
        await _fetchZoneAttendance(_currentZoneId, _currentZoneName);
      } else {
        await _fetchAttendance(1);
      }
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
        filteredAttendanceList = attendanceList.where((item) {
          if (_isManager && !_isZoneView && !_isWardView) {
            final zoneCode = item['zone_code']?.toString().toLowerCase() ?? '';
            final zoneName = item['zone_name']?.toString().toLowerCase() ?? '';
            return zoneCode.contains(query) || zoneName.contains(query);
          } else if (_isZoneView && !_isWardView) {
            final wardCode = item['ward_code']?.toString().toLowerCase() ?? '';
            return wardCode.contains(query);
          } else {
            final code = item['essl_code']?.toString().toLowerCase() ?? '';
            final name = item['employee_name']?.toString().toLowerCase() ?? '';
            return code.contains(query) || name.contains(query);
          }
        }).toList();
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
    final item =
        attendanceList.firstWhere((item) => item['id'] == id, orElse: () => {});
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
      final item = attendanceList.firstWhere((item) => item['id'] == id,
          orElse: () => {});
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
      final response = await http.post(
        Uri.parse("$baseUrl/hr/drf_list_n_write_att/"),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
        body: jsonEncode({
          "ma_ids": selectedIds,
          "confirmation": 1,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Bulk update successful'),
            backgroundColor: Colors.green,
          ),
        );
        if (_isWardView) {
          await _fetchWardAttendance(_currentWardId, _currentWardName);
        } else if (_isZoneView) {
          await _fetchZoneAttendance(_currentZoneId, _currentZoneName);
        } else {
          _fetchAttendance(currentPage);
        }
      } else {
        _showError("Failed to update attendance: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showBulkActionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Action'),
        content: const Text('Mark all selected as present or absent?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _submitBulkAttendance();
            },
            child: const Text('Absent', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _submitBulkAttendance();
            },
            child: const Text('Present', style: TextStyle(color: Colors.green)),
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
            'No attendance data found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _isWardView
                ? 'No records available for $_currentWardName on ${DateFormat('MMMM dd, yyyy').format(selectedDate)}'
                : _isZoneView
                    ? 'No records available for $_currentZoneName on ${DateFormat('MMMM dd, yyyy').format(selectedDate)}'
                    : 'No records available for ${DateFormat('MMMM dd, yyyy').format(selectedDate)}',
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

  Widget _buildManagerCard(dynamic item) {
    final zoneName = item['zone_name']?.toString() ?? 'N/A';
    final zoneCode = item['zone_code']?.toString() ?? 'N/A';
    final isActive = item['is_active'] ?? false;
    final zoneId = item['id'] ?? 0;

    return Card(
      color: Colors.grey[800],
      child: ListTile(
        title: Text(
          zoneCode,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(zoneName),
            Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: isActive ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _fetchZoneAttendance(zoneId, zoneName),
      ),
    );
  }

  Widget _buildDummyCard() {
    return Card(
      color: Colors.blue[200],
      child: ListTile(
        title: Text(
          'ALL',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _fetchZoneAttendanceAll(
          _currentZoneId,
          'ALL',
        ),
      ),
    );
  }

  // New method to build ward card
  Widget _buildWardCard(dynamic item) {
    final wardCode = item['ward_code']?.toString() ?? 'N/A';
    final zoneCode = item['zone_code']?.toString() ?? 'N/A';
    final supervisorId = item['supervisor']?.toString() ?? 'No Supervisor';
    final wardId = item['id'] ?? 0;

    return Card(
      color: Colors.grey[700],
      child: ListTile(
        title: Text(
          wardCode,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Zone: $zoneCode'),
            Text('Supervisor ID: $supervisorId'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _fetchWardAttendance(wardId, wardCode),
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
                  hintText: _isManager && !_isZoneView && !_isWardView
                      ? 'Search by zone...'
                      : _isZoneView && !_isWardView
                          ? 'Search by ward...'
                          : 'Search by code or name...',
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
                : Text(
                    _isWardView
                        ? _currentWardName
                        : _isZoneView
                            ? _currentZoneName
                            : _isManager
                                ? 'Zones'
                                : 'Attendance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
        actions: [
          if (_isWardView)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _isWardView = false;
                  _currentWardName = '';
                  _currentWardId = 0;
                });
                _fetchZoneAttendance(_currentZoneId, _currentZoneName);
              },
              tooltip: 'Back to Wards',
            ),
          if (_isZoneView && !_isWardView)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _isZoneView = false;
                  _currentZoneName = '';
                  _currentZoneId = 0;
                });
                _fetchAttendance(1);
              },
              tooltip: 'Back to Zones',
            ),
          if (!_isSearching && !_selectionMode)
            const NotificationBellWidget(),
          if (!_isSearching && !_selectionMode)
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _selectDate(context),
              tooltip: 'Select Date',
            ),
          if (!_isSearching && !_selectionMode)
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
        bottom: PreferredSize(
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
        ),
      ),
      drawer: _selectionMode ? null : const AppDrawer(),
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
              onRefresh: () => _isWardView
                  ? _fetchWardAttendance(_currentWardId, _currentWardName)
                  : _isZoneView
                      ? _fetchZoneAttendance(_currentZoneId, _currentZoneName)
                      : _fetchAttendance(currentPage),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredAttendanceList.isEmpty
                      ? _buildEmptyState()
                      : _isManager && !_isZoneView && !_isWardView
                          ? ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: filteredAttendanceList.length,
                              itemBuilder: (context, index) {
                                final item = filteredAttendanceList[index];
                                return _buildManagerCard(item);
                              },
                            )
                          : _isZoneView && !_isWardView
                              ? ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  itemCount: _isManager
                                      ? filteredAttendanceList.length +
                                          1 // add 1 for dummy card
                                      : filteredAttendanceList.length,
                                  itemBuilder: (context, index) {
                                    // Check if this is the dummy card index

                                    if (_isManager && index == 0) {
                                      return _buildDummyCard(); // Create your dummy card widget here
                                    }

                                    // If manager is logged in, adjust index for actual list data
                                    final item = _isManager
                                        ? filteredAttendanceList[index - 1]
                                        : filteredAttendanceList[index];

                                    return _buildWardCard(item);
                                  },
                                )
                              : AttendanceListBuilder(
                                  attendanceList: _isSearching
                                      ? filteredAttendanceList
                                      : attendanceList,
                                  onAttendanceMarked: () {
                                    // Determine which fetch method to call
                                    if (_isWardView && _isFromAllView) {
                                      _fetchZoneAttendanceAll(
                                          _currentWardId, _currentWardName);
                                    } else if (_isWardView && !_isFromAllView) {
                                      _fetchWardAttendance(
                                          _currentWardId, _currentWardName);
                                    } else if (_isZoneView) {
                                      _fetchZoneAttendance(
                                          _currentZoneId, _currentZoneName);
                                    } else {
                                      _fetchAttendance(currentPage);
                                    }
                                  },
                                  selectionMode: _selectionMode,
                                  onSelectionModeChanged: _toggleSelectionMode,
                                  onItemSelected: _toggleItemSelection,
                                  currentPage: currentPage,
                                  totalPages: totalPages,
                                  nextPageUrl: nextPageUrl,
                                  previousPageUrl: previousPageUrl,
                                  onPageChanged: (page) => _isWardView
                                      ? _fetchWardAttendance(
                                          _currentWardId, _currentWardName)
                                      : _isZoneView
                                          ? _fetchZoneAttendance(
                                              _currentZoneId, _currentZoneName)
                                          : _fetchAttendance(page),
                                  isManager: false,
                                  isFromAllView:
                                      _isFromAllView, // Pass the flag
                                  currentWardId:
                                      _currentWardId, // Pass current ward ID
                                  formattedDate: formattedDate,
                                ),
            ),
          ),
        ],
      ),
      floatingActionButton:
          _selectionMode && selectedIds.isNotEmpty && !_isManager
              ? FloatingActionButton.extended(
                  onPressed:
                      _hasLockedSelectedCards() ? null : _submitBulkAttendance,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm Selection'),
                  tooltip: _hasLockedSelectedCards()
                      ? 'Selected contains locked cards'
                      : null,
                )
              : null,
    );
  }

  bool _hasLockedSelectedCards() {
    for (var id in selectedIds) {
      final item = attendanceList.firstWhere((item) => item['id'] == id,
          orElse: () => {});
      if (item['lock_card'] == true) {
        return true;
      }
    }
    return false;
  }
}

class AttendanceListBuilder extends StatefulWidget {
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
  final bool isFromAllView; // New parameter
  final int currentWardId; // New parameter
  final String formattedDate; // New parameter

  const AttendanceListBuilder({
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
    required this.isFromAllView,
    required this.currentWardId,
    required this.formattedDate,
  });

  @override
  State<AttendanceListBuilder> createState() => _AttendanceListBuilderState();
}

class _AttendanceListBuilderState extends State<AttendanceListBuilder>
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
      'authorization':
          'Basic ${base64Encode(utf8.encode('$username:$password'))}'
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
      final response = await http.post(
        Uri.parse("$baseUrl/hr/drf_list_n_write_att/"),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
        body: jsonEncode({
          "ma_id": id,
          "manual_present": manualStatus,
          "att_remark": remark,
        }),
      );
      print('attendance_check');
      print('$baseUrl/hr/drf_list_n_write_att/');
      print(id);
      print(manualStatus);
      print(remark);
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _showSuccessPopup(context, result['message']);
      } else {
        _showError("Failed to update attendance: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSuccessPopup(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
            onPressed: () async {
              Navigator.pop(context);
              widget.onAttendanceMarked();
              // await _refreshAttendanceData();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAttendanceData() async {
    setState(() => isLoading = true);

    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      // Determine which API to call based on context
      String apiUrl;

      if (widget.isFromAllView) {
        // User came from ALL view - use zone_id parameter
        apiUrl =
            "$baseUrl/hr/drf_list_zone_n_ward_att/?attendance_date=${widget.formattedDate}&zone_id=${widget.currentWardId}";
      } else {
        // User came from specific ward - use ward_id parameter
        apiUrl =
            "$baseUrl/hr/drf_list_zone_n_ward_att/?attendance_date=${widget.formattedDate}&ward_id=${widget.currentWardId}";
      }
      print('apiUrl____check');
      print(widget.isFromAllView);
      print(apiUrl);

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Update the parent widget through callback
        widget.onAttendanceMarked();
      } else {
        _showError("Failed to refresh data: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error refreshing data: $e");
    } finally {
      setState(() => isLoading = false);
    }
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
                  const Icon(Icons.edit_note,
                      size: 28, color: Colors.deepPurple),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
      child: isSmallScreen
          ? _buildVerticalPagination()
          : _buildHorizontalPagination(),
    );
  }

  Widget _buildHorizontalPagination() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.previousPageUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(80, 36),
                ),
                onPressed: () {
                  final prevPage = _extractPageFromUrl(widget.previousPageUrl);
                  widget.onPageChanged(prevPage);
                },
                child: const Text('Prev'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Page ${widget.currentPage} of ${widget.totalPages ?? 1}',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (widget.nextPageUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(80, 36),
                ),
                onPressed: () {
                  final nextPage = _extractPageFromUrl(widget.nextPageUrl) ??
                      widget.currentPage + 1;
                  widget.onPageChanged(nextPage);
                },
                child: const Text('Next'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerticalPagination() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.previousPageUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(80, 36),
                  ),
                  onPressed: () {
                    final prevPage =
                        _extractPageFromUrl(widget.previousPageUrl);
                    widget.onPageChanged(prevPage);
                  },
                  child: const Text('Prev'),
                ),
              ),
            if (widget.nextPageUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(80, 36),
                  ),
                  onPressed: () {
                    final nextPage = _extractPageFromUrl(widget.nextPageUrl) ??
                        widget.currentPage + 1;
                    widget.onPageChanged(nextPage);
                  },
                  child: const Text('Next'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Page ${widget.currentPage} of ${widget.totalPages ?? 1}',
          style: const TextStyle(fontSize: 14),
        ),
      ],
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

  Widget _buildManagerCard(dynamic item, Function(int, String) onZoneTap) {
    final zoneName = item['zone_name']?.toString() ?? 'N/A';
    final zoneCode = item['zone_code']?.toString() ?? 'N/A';
    final isActive = item['is_active'] ?? false;
    final zoneId = item['id'] ?? 0;

    return Card(
      color: Colors.grey[800],
      child: ListTile(
        title: Text(
          zoneCode,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(zoneName),
            Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: isActive ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => onZoneTap(zoneId, zoneName),
      ),
    );
  }

  Color _hexToColor(final String hexColor) {
    try {
      // Handle cases where hex might or might not start with #
      final hexCode =
          hexColor.startsWith('#') ? hexColor.substring(1) : hexColor;
      return Color(int.parse('FF$hexCode', radix: 16));
    } catch (e) {
      // Fallback color if parsing fails
      return Colors.grey;
    }
  }

  Color _contrastColor(Color bg) =>
      bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

  String _safeVal(dynamic value) {
    if (value == null) return 'N/A';
    final s = value.toString();
    return (s.isEmpty || s.toLowerCase() == 'null') ? 'N/A' : s;
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

  Widget _buildSupervisorCard(dynamic item, BuildContext context) {
    final employeeCode = item['essl_code']?.toString() ?? 'N/A';
    final employeeName = item['employee_name']?.toString() ?? 'N/A';
    final color = item['color_code']?.toString() ?? '#4a4d52';
    final lockCard = item['lock_card'] ?? false;
    final designation = item['designation']?.toString() ?? 'N/A';
    final ward = item['ward']?.toString() ?? 'N/A';
    final esslInTime = item['essl_intime'];
    final esslInMethod = item['essl_in_method'];
    final esslOutTime = item['essl_out_time'];
    final esslOutMethod = item['essl_out_method'];
    final idNum = item['id']?.toString() ?? 'N/A';
    final employeeIdNum = item['employee_id']?.toString() ?? 'N/A';

    final cardColor = _hexToColor(color);
    final textColor = _contrastColor(cardColor);

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: InkWell(
        onLongPress: () {
          /*if (lockCard) {
            _showLockedCardMessage(context);
            return;
          }
          if (widget.onSelectionModeChanged != null) {
            widget.onSelectionModeChanged!(true);
            if (widget.onItemSelected != null) {
              widget.onItemSelected!(item['id'], true);
            }
          }*/
        },
        child: Row(
          children: [
            /*if (widget.selectionMode)
              Checkbox(
                value: item['isSelected'] ?? false,
                onChanged: lockCard
                    ? null
                    : (value) {
                        if (widget.onItemSelected != null) {
                          widget.onItemSelected!(item['id'], value ?? false);
                        }
                      },
              ),*/
            Expanded(
              child: Slidable(
                key: Key(item['id'].toString()),
                // enabled: !lockCard,
                /*startActionPane: ...*/
                /*endActionPane: ...*/
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
                              '#$idNum',
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.attendanceList.length,
            itemBuilder: (context, index) {
              final item = widget.attendanceList[index];

              if (widget.isManager) {
                return _buildManagerCard(item, (zoneId, zoneName) {
                  // This will be handled by the parent widget
                  if (widget.onSelectionModeChanged != null) {
                    widget.onSelectionModeChanged!(false);
                  }
                });
              } else {
                return _buildSupervisorCard(item, context);
              }
            },
          ),
        ),
        _buildPaginationControls(),
        const SizedBox(height: 40),
      ],
    );
  }
}
