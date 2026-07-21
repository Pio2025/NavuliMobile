import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/school_tab_bar.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
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
    final result = await _client.getNotices(schoolId: _schoolId);
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
        title: const Text('Notice Board'),
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
                  Center(child: Text('Failed to load notices: ${snapshot.error}')),
                ],
              );
            }
            final result = snapshot.data!;
            final notices = result.items;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SchoolTabBar(
                  schools: result.schools,
                  activeSchoolId: result.activeSchoolId,
                  onSelected: _switchSchool,
                ),
                if (notices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Center(child: Text('No notices right now.')),
                  )
                else
                  for (final n in notices) ...[
                    _NoticeCard(notice: n),
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

class _NoticeCard extends StatelessWidget {
  final Map<String, dynamic> notice;

  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    final pinned = notice['isPinned'] == true || notice['isPinned'] == 1;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (pinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.push_pin,
                        size: 16, color: AppColors.primary),
                  ),
                Expanded(
                  child: Text(
                    '${notice['title'] ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${notice['content'] ?? ''}'),
            const SizedBox(height: 8),
            Text(
              '${notice['postedBy'] ?? ''} · ${notice['createdAt'] ?? ''}',
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
