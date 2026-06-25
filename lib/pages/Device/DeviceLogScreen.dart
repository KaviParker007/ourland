import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config.dart';

class DeviceLogScreen extends StatefulWidget {
  final int deviceId;
  final String deviceName;

  const DeviceLogScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<DeviceLogScreen> createState() => _DeviceLogScreenState();
}

class _DeviceLogScreenState extends State<DeviceLogScreen> {
  List deviceLogs = [];
  List filteredLogs = [];
  bool isLoading = true;
  String? username;
  String? password;
  String baseUrl = AppConfig.apiUrl;
  bool isSearching = false;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCredentialsAndFetchLogs();
  }

  Future<void> _loadCredentialsAndFetchLogs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username');
      password = prefs.getString('password');
    });
    await _fetchDeviceLogs();
  }

  Future<void> _fetchDeviceLogs() async {
    setState(() {
      isLoading = true;
    });

    try {
      // ✅ Updated endpoint
      var uri = Uri.parse("$baseUrl/drf_device_logs_v2/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      var headers = {'Content-Type': 'application/json', 'authorization': auth};
      var body = jsonEncode({'deviceid': widget.deviceId});

      var response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        setState(() {
          deviceLogs = jsonDecode(response.body);
          filteredLogs = List.from(deviceLogs);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load logs: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterLogs(String query) {
    setState(() {
      filteredLogs = deviceLogs.where((log) {
        final name = log['name'].toString().toLowerCase();
        final userId = log['userid'].toString().toLowerCase();
        final searchLower = query.toLowerCase();
        return name.contains(searchLower) || userId.contains(searchLower);
      }).toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      if (isSearching) {
        searchController.clear();
        filteredLogs = List.from(deviceLogs);
      }
      isSearching = !isSearching;
    });
  }

  /// ✅ Parses hex color string like "#98FF98" into a Flutter Color
  Color _parseColor(String? hexColor, {Color fallback = Colors.white}) {
    if (hexColor == null || hexColor.isEmpty) return fallback;
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  /// ✅ Returns a contrasting text color (dark/light) based on background brightness
  Color _contrastColor(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  /// ✅ Safely handles "null" string or actual null values from API
  String _safeValue(dynamic value, {String fallback = 'N/A'}) {
    if (value == null) return fallback;
    final str = value.toString();
    if (str.isEmpty || str.toLowerCase() == 'null' || str.toLowerCase() == 'nat') {
      return fallback;
    }
    return str;
  }

  /// ✅ Formats duration from seconds to human-readable "Xh Ym"
  String _formatDuration(dynamic value) {
    final raw = _safeValue(value);
    if (raw == 'N/A') return 'N/A';
    try {
      final seconds = double.parse(raw).toInt();
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    } catch (_) {
      return 'N/A';
    }
  }

  /// ✅ Formats ISO datetime "2026-04-25T05:09:19" to "25 Apr 2026, 05:09 AM"
  String _formatDateTime(dynamic value) {
    final raw = _safeValue(value);
    if (raw == 'N/A') return 'N/A';
    try {
      final dt = DateTime.parse(raw);
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $period';
    } catch (_) {
      return raw;
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
          controller: searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by name or employee code...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: _filterLogs,
        )
            : Text('${widget.deviceName} Logs'),
        actions: [
          if (isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleSearch,
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _toggleSearch,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDeviceLogs,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredLogs.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No matching logs found' : 'No logs available',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (isSearching)
              TextButton(
                onPressed: _toggleSearch,
                child: const Text('Clear search'),
              ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredLogs.length,
        itemBuilder: (context, index) {
          final log = filteredLogs[index];

          // ✅ Parse the color_code from the response
          final cardColor = _parseColor(log['color_code']);
          final textColor = _contrastColor(cardColor);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            // ✅ Apply color_code as the card background
            color: cardColor,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: Name + punch count badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _safeValue(log['name']),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: textColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_safeValue(log['total_punches'])} punches',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(color: textColor.withOpacity(0.3), height: 1),
                  const SizedBox(height: 10),

                  // ✅ Updated field names matching the new API response
                  _buildLogRow('EMPLOYEE CODE', _safeValue(log['userid']), textColor),
                  _buildLogRow('LOGIN TIME', _formatDateTime(log['login_time']), textColor),
                  _buildLogRow('LOGIN METHOD', _safeValue(log['login_method']), textColor),
                  _buildLogRow('LOGOUT TIME', _formatDateTime(log['logout_time']), textColor),
                  _buildLogRow('LOGOUT METHOD', _safeValue(log['logout_method']), textColor),
                  _buildLogRow('DURATION', _formatDuration(log['duration']), textColor),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.37,
            child: Text(
              '$label:',
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}