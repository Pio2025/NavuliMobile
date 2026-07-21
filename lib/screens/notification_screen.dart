import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class NotificationScreen extends StatefulWidget {
  final ValueChanged<int>? onUnreadCountChanged;

  const NotificationScreen({super.key, this.onUnreadCountChanged});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late ApiClient _client;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _client = ApiClient(context.read<AuthService>());
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final data = await _client.getNotifications();
    widget.onUnreadCountChanged?.call(data['unreadCount'] ?? 0);
    return data;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _markAllRead() async {
    try {
      await _client.markNotificationsRead();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text(
              'Mark all read',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Alerts'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final alerts =
              List<Map<String, dynamic>>.from(data['alerts'] ?? []);
          final activities =
              List<Map<String, dynamic>>.from(data['activities'] ?? []);

          return TabBarView(
            controller: _tabController,
            children: [
              _NotificationList(
                items: alerts,
                emptyText: 'No alerts right now.',
                onRefresh: _refresh,
              ),
              _NotificationList(
                items: activities,
                emptyText: 'No recent activity.',
                onRefresh: _refresh,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String emptyText;
  final Future<void> Function() onRefresh;

  const _NotificationList({
    required this.items,
    required this.emptyText,
    required this.onRefresh,
  });

  Color _themeColor(String theme) {
    switch (theme) {
      case 'success':
        return const Color(0xFF17A672);
      case 'danger':
        return const Color(0xFFE53935);
      case 'warning':
        return const Color(0xFFF5A623);
      case 'info':
        return const Color(0xFF00AEEF);
      default:
        return AppColors.secondary;
    }
  }

  IconData _themeIcon(String theme) {
    switch (theme) {
      case 'success':
        return Icons.check_circle_outline;
      case 'danger':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 100),
                Center(
                  child: Text(
                    emptyText,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = items[i];
                final theme = '${item['theme'] ?? 'primary'}';
                final isUnread = '${item['status'] ?? 'Read'}' == 'Unread';
                final color = _themeColor(theme);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: isUnread
                        ? Border.all(color: color.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_themeIcon(theme), color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item['title'] ?? ''}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (isUnread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item['desc'] ?? ''}',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item['age'] ?? ''}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
