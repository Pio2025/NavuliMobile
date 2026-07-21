import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../utils/time_ago.dart';
import '../widgets/school_tab_bar.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  late ApiClient _client;
  late Future<SchoolScopedList> _future;
  int? _schoolId;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    _future = _load();
  }

  Future<SchoolScopedList> _load() async {
    final result = await _client.getAnnouncements(schoolId: _schoolId);
    _schoolId = result.activeSchoolId;
    return result;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _switchSchool(int schId) {
    setState(() {
      _schoolId = schId;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<SchoolScopedList>(
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
                    Center(
                      child: Text(
                          'Failed to load announcements: ${snapshot.error}'),
                    ),
                  ],
                );
              }
              final result = snapshot.data!;
              final items = result.items;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SchoolTabBar(
                    schools: result.schools,
                    activeSchoolId: result.activeSchoolId,
                    onSelected: _switchSchool,
                  ),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(child: Text('No announcements right now.')),
                    )
                  else
                    for (final a in items) ...[
                      _AnnouncementCard(announcement: a),
                      const SizedBox(height: 12),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PriorityStyle {
  final Color color;
  final Color bg;
  const _PriorityStyle(this.color, this.bg);
}

const _announcementPriorityStyles = {
  'Critical': _PriorityStyle(Color(0xFFF1416C), Color(0xFFFFF5F8)),
  'Important': _PriorityStyle(Color(0xFFFF9500), Color(0xFFFFF8DD)),
  'Info': _PriorityStyle(Color(0xFF009EF7), Color(0xFFF1FAFF)),
};

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> announcement;

  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final priority = '${announcement['priority'] ?? 'Info'}';
    final style = _announcementPriorityStyles[priority] ??
        _announcementPriorityStyles['Info']!;
    final postedBy = '${announcement['postedBy'] ?? ''}'.trim();
    final initial = postedBy.isNotEmpty ? postedBy[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: style.bg,
              border: Border(
                bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.campaign_outlined, size: 18, color: style.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${announcement['title'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: style.color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    priority,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${announcement['content'] ?? ''}',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: style.color.withValues(alpha: 0.15),
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: style.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        postedBy.isEmpty ? 'School Admin' : postedBy,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      timeAgo(announcement['createdAt']),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
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
}
