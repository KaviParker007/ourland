import 'dart:convert';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/config.dart';
import 'package:ourlandnew/pages/notifications/notification_list_page.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class NotificationCategory {
  final String model;
  final String label;
  final int count;

  const NotificationCategory({
    required this.model,
    required this.label,
    required this.count,
  });

  factory NotificationCategory.fromJson(Map<String, dynamic> json) {
    return NotificationCategory(
      model: json['model'] as String? ?? '',
      label: json['label'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

// ─── Bell Widget ──────────────────────────────────────────────────────────────

class NotificationBellWidget extends StatefulWidget {
  const NotificationBellWidget({super.key});

  @override
  State<NotificationBellWidget> createState() => _NotificationBellWidgetState();
}

class _NotificationBellWidgetState extends State<NotificationBellWidget> {
  int _totalCount = 0;
  List<NotificationCategory> _categories = [];
  String? _username;
  String? _password;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('username');
    _password = prefs.getString('password');
    if (_username != null && _password != null) {
      await _fetchCounts();
    }
  }

  Future<void> _fetchCounts() async {
    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/drf_notification_counts/'),
        headers: {
          'Content-Type': 'application/json',
          'authorization': auth,
        },
      );
      print('[GET] ${response.request?.url}');
      print('[GET] status: ${response.statusCode}');
      print('[GET] body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _totalCount = data['total'] as int? ?? 0;
            _categories = (data['groups'] as List<dynamic>? ?? [])
                .map((e) =>
                    NotificationCategory.fromJson(e as Map<String, dynamic>))
                .toList();
          });
        }
      }
    } catch (_) {
      // Silent fail — bell stays as-is if network is unavailable
    }
  }

  void _openCategoryPanel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationCategorySheet(
        categories: _categories,
        username: _username,
        password: _password,
        onCountChanged: () {
          if (mounted) _fetchCounts();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: _openCategoryPanel,
      icon: badges.Badge(
        showBadge: _totalCount > 0,
        badgeContent: Text(
          _totalCount > 99 ? '99+' : _totalCount.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        badgeStyle: badges.BadgeStyle(
          badgeColor: Theme.of(context).colorScheme.error,
          padding: const EdgeInsets.all(4),
        ),
        position: badges.BadgePosition.topEnd(top: -4, end: -4),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

// ─── Category Bottom Sheet ────────────────────────────────────────────────────

class _NotificationCategorySheet extends StatelessWidget {
  final List<NotificationCategory> categories;
  final String? username;
  final String? password;
  final VoidCallback onCountChanged;

  const _NotificationCategorySheet({
    required this.categories,
    required this.username,
    required this.password,
    required this.onCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.notifications,
                        color: theme.colorScheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Notifications',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Category list
              Expanded(
                child: categories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 52,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No new notifications',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: categories.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          return _CategoryTile(
                            category: cat,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NotificationListPage(
                                    model: cat.model,
                                    label: cat.label,
                                    username: username,
                                    password: password,
                                  ),
                                ),
                              ).then((_) => onCountChanged());
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Category Tile ────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final NotificationCategory category;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.onTap});

  IconData _iconForModel(String model) {
    switch (model.toLowerCase()) {
      case 'jobcard':
        return Icons.car_repair_rounded;
      case 'fuelmaster':
        return Icons.local_gas_station_rounded;
      case 'vehicle':
        return Icons.directions_car;
      case 'attendance':
        return Icons.co_present_outlined;
      default:
        return Icons.inbox_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
        child: Icon(
          _iconForModel(category.model),
          color: theme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        category.label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          category.count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
