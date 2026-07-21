import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/announcement_card.dart';
import '../widgets/notice_card.dart';
import '../widgets/stat_card.dart';
import 'announcement_detail_screen.dart';
import 'announcements_screen.dart';
import 'dashboard_screen.dart';
import 'notice_detail_screen.dart';
import 'notices_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;
  int _selectedTab = -1; // -1 = "My Dashboard", else index into childStats

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final auth = context.read<AuthService>();
    final client = ApiClient(auth);
    final results = await Future.wait([
      client.getNotices(),
      client.getAnnouncements(),
    ]);
    Map<String, dynamic>? dashboard;
    try {
      dashboard = await client.getDashboard();
    } catch (_) {
      dashboard = null;
    }
    return _HomeData(
      notices: results[0].items,
      announcements: results[1].items,
      dashboard: dashboard,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
      _selectedTab = -1;
    });
    await _future;
  }

  void _openDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _openNotices() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NoticesScreen()));
  }

  void _openAnnouncements() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AnnouncementsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Image.asset(
          'assets/images/navuli_logo_small_color.png',
          height: 34,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            tooltip: 'Dashboard',
            icon: const Icon(Icons.dashboard_outlined, color: AppColors.primary),
            onPressed: _openDashboard,
          ),
          IconButton(
            tooltip: 'Notices',
            icon: const Icon(Icons.campaign_outlined, color: AppColors.primary),
            onPressed: _openNotices,
          ),
          IconButton(
            tooltip: 'Announcements',
            icon: const Icon(Icons.notifications_none, color: AppColors.primary),
            onPressed: _openAnnouncements,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('Failed to load: ${snapshot.error}')),
                ],
              );
            }

            final data = snapshot.data!;
            final childStats =
                (data.dashboard?['childStats'] as List<dynamic>? ?? [])
                    .cast<Map<String, dynamic>>();
            if (_selectedTab >= childStats.length) _selectedTab = -1;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${auth.user?.name.split(' ').first ?? ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              auth.user?.roleCatName ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.school_outlined,
                          color: Colors.white, size: 36),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (childStats.isNotEmpty) ...[
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _tabChip(
                          context,
                          label: 'My Dashboard',
                          selected: _selectedTab == -1,
                          onTap: () => setState(() => _selectedTab = -1),
                        ),
                        for (var i = 0; i < childStats.length; i++)
                          _tabChip(
                            context,
                            label: '${childStats[i]['name'] ?? 'Child'}',
                            selected: _selectedTab == i,
                            onTap: () => setState(() => _selectedTab = i),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ..._buildStatsGrid(
                  _selectedTab == -1
                      ? (data.dashboard?['stats'] as Map<String, dynamic>? ?? {})
                      : (childStats[_selectedTab]['stats']
                              as Map<String, dynamic>? ??
                          {}),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openDashboard,
                    icon: const Icon(Icons.bar_chart_outlined, size: 18),
                    label: const Text('View full dashboard'),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionHeader(context, 'Notices', onSeeAll: _openNotices),
                const SizedBox(height: 8),
                _buildNoticePreview(data.notices),
                const SizedBox(height: 20),
                _sectionHeader(context, 'Announcements',
                    onSeeAll: _openAnnouncements),
                const SizedBox(height: 8),
                _buildAnnouncementPreview(data.announcements),
              ],
            );
          },
        ),
        ),
      ),
    );
  }

  Widget _tabChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: Theme.of(context).cardTheme.color ?? scheme.surface,
        labelStyle: TextStyle(
          color: selected ? Colors.white : scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
      ),
    );
  }

  // Home shows a condensed summary only; the full breakdown (and charts)
  // lives in DashboardScreen, opened via the AppBar icon / "View full
  // dashboard" link.
  static const int _summaryStatLimit = 4;

  List<Widget> _buildStatsGrid(Map<String, dynamic> stats) {
    final entries = stats.entries
        .where((e) => _isDisplayableStat(e.key, e.value))
        .take(_summaryStatLimit)
        .toList();

    if (entries.isEmpty) {
      return [
        Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No dashboard metrics to display yet.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        // A fixed mainAxisExtent (rather than childAspectRatio) guarantees
        // enough height for StatCard's content on narrow devices, avoiding
        // "BOTTOM OVERFLOWED" errors.
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 116,
        ),
        children: entries
            .map((e) => StatCard(
                  label: _prettyLabel(e.key),
                  value: _formatValue(e.key, _asNum(e.value)),
                  icon: _iconFor(e.key),
                ))
            .toList(),
      ),
    ];
  }

  /// Backend rows from raw SQL queries can come back as numeric strings
  /// (MySQLi doesn't always cast); coerce defensively instead of `as num`.
  num _asNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isDisplayableStat(String key, dynamic value) {
    if (value is! num && num.tryParse(value?.toString() ?? '') == null) {
      return false;
    }
    if (key == 'user_id' ||
        key.endsWith('_id') ||
        key.endsWith('_id_fk') ||
        key.endsWith('_fk')) {
      return false;
    }
    return true;
  }

  String _prettyLabel(String key) {
    final stripped = key.replaceFirst(RegExp(r'^(sa_|ad_|ts_|st_)'), '');
    final words = stripped.split('_').where((w) => w.isNotEmpty);
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  String _formatValue(String key, num value) {
    if (key.endsWith('_pct')) {
      final v = value.toDouble();
      return '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}%';
    }
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'class_size':
        return Icons.groups_outlined;
      case 'conduct_positive':
        return Icons.thumb_up_alt_outlined;
      case 'conduct_negative':
        return Icons.thumb_down_alt_outlined;
      case 'conduct_resolved':
        return Icons.task_alt_outlined;
      case 'total_incidents':
        return Icons.report_outlined;
      case 'class_rank':
        return Icons.emoji_events_outlined;
      case 'overall_pct':
        return Icons.grade_outlined;
    }
    if (key.contains('school')) return Icons.school_outlined;
    if (key.contains('student')) return Icons.groups_outlined;
    if (key.contains('teacher')) return Icons.person_outline;
    if (key.contains('classroom')) return Icons.class_outlined;
    if (key.contains('attendance')) return Icons.event_available_outlined;
    if (key.contains('announcement')) return Icons.campaign_outlined;
    if (key.contains('notice')) return Icons.notifications_outlined;
    if (key.contains('conduct') || key.contains('incident')) {
      return Icons.gavel_outlined;
    }
    if (key.contains('rank')) return Icons.emoji_events_outlined;
    if (key.contains('mark') ||
        key.contains('pct') ||
        key.contains('overall')) {
      return Icons.grade_outlined;
    }
    if (key.contains('lesson')) return Icons.menu_book_outlined;
    if (key.contains('assignment')) return Icons.assignment_outlined;
    if (key.contains('user')) return Icons.people_outline;
    return Icons.insights_outlined;
  }

  Widget _sectionHeader(BuildContext context, String title,
      {required VoidCallback onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: const Text('See all'),
        ),
      ],
    );
  }

  Widget _buildNoticePreview(List<Map<String, dynamic>> notices) {
    if (notices.isEmpty) {
      return Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No notices right now.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    final notice = notices.first;
    return NoticeCard(
      notice: notice,
      compact: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: notice)),
      ),
    );
  }

  Widget _buildAnnouncementPreview(List<Map<String, dynamic>> announcements) {
    if (announcements.isEmpty) {
      return Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No announcements right now.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    final announcement = announcements.first;
    return AnnouncementCard(
      announcement: announcement,
      compact: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnnouncementDetailScreen(announcement: announcement),
        ),
      ),
    );
  }
}

class _HomeData {
  final List<Map<String, dynamic>> notices;
  final List<Map<String, dynamic>> announcements;
  final Map<String, dynamic>? dashboard;

  _HomeData({
    required this.notices,
    required this.announcements,
    required this.dashboard,
  });
}
