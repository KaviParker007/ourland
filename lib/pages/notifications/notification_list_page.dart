import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/config.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class AppNotification {
  final int id;
  final String title;
  final String message;
  final String sender;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.sender,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      sender: json['sender'] as String? ?? 'System',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class NotificationListPage extends StatefulWidget {
  final String model;
  final String label;
  final String? username;
  final String? password;

  const NotificationListPage({
    super.key,
    required this.model,
    required this.label,
    this.username,
    this.password,
  });

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _errorMsg;
  String? _username;
  String? _password;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _resolveCredentials();
  }

  Future<void> _resolveCredentials() async {
    if (widget.username != null && widget.password != null) {
      _username = widget.username;
      _password = widget.password;
    } else {
      final prefs = await SharedPreferences.getInstance();
      _username = prefs.getString('username');
      _password = prefs.getString('password');
    }
    await _fetchNotifications();
  }

  String get _authHeader =>
      'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.apiUrl}/drf_notifications/?unread=true&model=${widget.model}',
      );

      print('Notifications URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'authorization': _authHeader,
        },
      );

      print('Response Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> data = body['notifications'] as List<dynamic>;

        final notifications = data
            .map((e) => AppNotification.fromJson(
            e as Map<String, dynamic>))
            .toList();

        setState(() {
          _notifications = notifications;
          _unreadCount =
              notifications.where((n) => !n.isRead).length;
        });
      } else {
        setState(() {
          _errorMsg = 'Server error (${response.statusCode})';
        });
      }
    } catch (e, stackTrace) {
      print('Error: $e');
      print('StackTrace: $stackTrace');

      setState(() {
        _errorMsg = 'Connection error. Please try again.';
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _markAsRead(AppNotification notification) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/drf_mark_notifications_read/'),
        headers: {
          'Content-Type': 'application/json',
          'authorization': _authHeader,
        },
        body: jsonEncode({'ids': [notification.id]}),
      );

      if (response.statusCode == 200) {
        setState(() {
          notification.isRead = true;
          _notifications.removeWhere((n) => n.id == notification.id);
          _unreadCount = _notifications.where((n) => !n.isRead).length;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Marked as read'),
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _showError('Failed to mark as read. Please try again.');
      }
    } catch (_) {
      _showError('Connection error. Please try again.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label),
            if (_unreadCount > 0)
              Text(
                '$_unreadCount unread',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: theme.colorScheme.error.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMsg!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchNotifications,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 64,
              color: theme.colorScheme.tertiary.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'All caught up!',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No unread notifications for ${widget.label}.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _SwipeHint(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchNotifications,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                return _NotificationCard(
                  notification: notif,
                  onMarkRead: () => _markAsRead(notif),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Swipe Hint Banner ────────────────────────────────────────────────────────

class _SwipeHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
      child: Row(
        children: [
          Icon(
            Icons.swipe_left_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Swipe left to mark as read',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notification Card ────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onMarkRead;

  const _NotificationCard({
    required this.notification,
    required this.onMarkRead,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey(notification.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.28,
          children: [
            SlidableAction(
              onPressed: (_) => onMarkRead(),
              backgroundColor: theme.colorScheme.tertiary,
              foregroundColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              icon: Icons.done_all_rounded,
              label: 'Read',
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isUnread
                ? theme.colorScheme.tertiary.withOpacity(0.08)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnread
                  ? theme.colorScheme.tertiary.withOpacity(0.35)
                  : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnread
                        ? theme.colorScheme.tertiary
                        : Colors.transparent,
                    border: Border.all(
                      color: isUnread
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.onSurface.withOpacity(0.2),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(
              notification.title,
              style: TextStyle(
                fontWeight:
                    isUnread ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Text(
                  notification.message,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.75),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color:
                          theme.colorScheme.onSurface.withOpacity(0.45),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        notification.sender,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.45),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color:
                          theme.colorScheme.onSurface.withOpacity(0.45),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _formatDate(notification.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
