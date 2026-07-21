import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
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
                    child:
                        Text('Failed to load announcements: ${snapshot.error}'),
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
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> announcement;

  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${announcement['title'] ?? ''}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text('${announcement['content'] ?? ''}'),
            const SizedBox(height: 8),
            Text(
              '${announcement['postedBy'] ?? ''} · ${announcement['createdAt'] ?? ''}',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
