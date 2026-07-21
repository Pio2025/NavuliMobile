import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'menu_screen.dart';
import 'notification_screen.dart';
import 'placeholder_screen.dart';
import 'wall_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final client = ApiClient(context.read<AuthService>());
      final data = await client.getNotifications();
      if (!mounted) return;
      setState(() => _unreadCount = data['unreadCount'] ?? 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final photoUrl = user != null ? ApiConfig.photoUrl(user.photo) : '';

    final screens = [
      const HomeScreen(),
      const PlaceholderScreen(title: 'Classroom', icon: Icons.class_outlined),
      const PlaceholderScreen(title: 'Intake', icon: Icons.how_to_reg_outlined),
      const WallScreen(),
      NotificationScreen(
        onUnreadCountChanged: (count) {
          if (!mounted) return;
          setState(() => _unreadCount = count);
        },
      ),
      const MenuScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        showUnselectedLabels: true,
        onTap: (i) => setState(() => _index = i),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.class_outlined),
            label: 'Classroom',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.how_to_reg_outlined),
            label: 'Intake',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.dynamic_feed_outlined),
            label: 'Wall',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.notifications),
            ),
            label: 'Notification',
          ),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? const Icon(Icons.person, size: 14, color: AppColors.primary)
                  : null,
            ),
            activeIcon: CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.primary,
              backgroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? const Icon(Icons.person, size: 14, color: Colors.white)
                  : null,
            ),
            label: 'Menu',
          ),
        ],
      ),
    );
  }
}
