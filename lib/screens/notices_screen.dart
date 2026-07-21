import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_ago.dart';
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
      ),
    );
  }
}

class _PriorityStyle {
  final Color color;
  final Color bg;
  const _PriorityStyle(this.color, this.bg);
}

const _noticePriorityStyles = {
  'Urgent': _PriorityStyle(Color(0xFFF1416C), Color(0xFFFFF5F8)),
  'Important': _PriorityStyle(Color(0xFFFFC700), Color(0xFFFFF8DD)),
  'Normal': _PriorityStyle(Color(0xFF009EF7), Color(0xFFF1FAFF)),
};

class _NoticeCard extends StatelessWidget {
  final Map<String, dynamic> notice;

  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    final pinned = notice['isPinned'] == true || notice['isPinned'] == 1;
    final scheme = Theme.of(context).colorScheme;
    final priority = '${notice['priority'] ?? 'Normal'}';
    final style = _noticePriorityStyles[priority] ??
        _noticePriorityStyles['Normal']!;
    final postedBy = '${notice['postedBy'] ?? ''}'.trim();
    final initial = postedBy.isNotEmpty ? postedBy[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: pinned
            ? Border.all(color: style.color.withValues(alpha: 0.35))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: style.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${notice['title'] ?? ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        if (pinned)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin,
                                    size: 10, color: Colors.white),
                                SizedBox(width: 3),
                                Text('PINNED',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.4,
                                    )),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: style.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        priority,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: style.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${notice['content'] ?? ''}',
                      maxLines: 3,
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
                            postedBy.isEmpty ? 'Staff' : postedBy,
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
                          timeAgo(notice['createdAt']),
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
            ),
          ],
        ),
      ),
    );
  }
}
