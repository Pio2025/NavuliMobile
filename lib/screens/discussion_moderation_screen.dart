import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/time_ago.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/error_state.dart' show ErrorState, friendlyErrorMessage;

String _contentTypeLabel(String type) {
  switch (type) {
    case 'class_post':
      return 'Classroom post';
    case 'class_comment':
      return 'Classroom comment';
    case 'class_reply':
      return 'Classroom reply';
    case 'lesson_post':
      return 'Lesson post';
    case 'lesson_comment':
      return 'Lesson comment';
    case 'lesson_reply':
      return 'Lesson reply';
    default:
      return type;
  }
}

int _asInt(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

class DiscussionModerationScreen extends StatefulWidget {
  final ApiClient client;
  final int classId;

  const DiscussionModerationScreen({super.key, required this.client, required this.classId});

  @override
  State<DiscussionModerationScreen> createState() => _DiscussionModerationScreenState();
}

class _DiscussionModerationScreenState extends State<DiscussionModerationScreen> {
  bool _loading = true;
  String? _error;
  List<List<Map<String, dynamic>>> _groups = [];
  final Set<String> _busyKeys = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _groupKey(Map<String, dynamic> r) => '${r['content_type']}:${r['content_id']}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await widget.client.discussionModerationQueue(widget.classId);
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final r in reports) {
        grouped.putIfAbsent(_groupKey(r), () => []).add(r);
      }
      setState(() {
        _groups = grouped.values.toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _decide(List<Map<String, dynamic>> group, String decision) async {
    final key = _groupKey(group.first);
    setState(() => _busyKeys.add(key));
    try {
      final reportId = _asInt(group.first['report_id']);
      await widget.client.discussionReportDecision(reportId, decision: decision);
      if (!mounted) return;
      setState(() {
        _groups.removeWhere((g) => _groupKey(g.first) == key);
        _busyKeys.remove(key);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyKeys.remove(key));
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  void _openAuthorHistory(int authorId, String authorName) {
    showDialog(
      context: context,
      builder: (_) => _AuthorHistoryDialog(client: widget.client, userId: authorId, authorName: authorName),
    );
  }

  Widget _groupCard(List<Map<String, dynamic>> group) {
    final scheme = Theme.of(context).colorScheme;
    final first = group.first;
    final key = _groupKey(first);
    final busy = _busyKeys.contains(key);
    final authorId = _asInt(first['content_author_id']);
    final authorName = '${first['content_author_name'] ?? 'Unknown'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _contentTypeLabel('${first['content_type']}'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openAuthorHistory(authorId, authorName),
                  child: Text(
                    'By $authorName',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history, size: 18),
                tooltip: 'Author report history',
                onPressed: () => _openAuthorHistory(authorId, authorName),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final r in group)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${r['reporter_name'] ?? 'Someone'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(timeAgo('${r['created_at'] ?? ''}'), style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${r['reason'] ?? ''}', style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => _decide(group, 'dismiss'),
                  child: const Text('Remove flag'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: busy ? null : () => _decide(group, 'delete'),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Delete content'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Moderation queue')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _groups.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          children: [
                            Center(
                              child: Text('Nothing pending review.', style: TextStyle(color: scheme.onSurfaceVariant)),
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [for (final g in _groups) _groupCard(g)],
                        ),
                ),
    );
  }
}

class _AuthorHistoryDialog extends StatefulWidget {
  final ApiClient client;
  final int userId;
  final String authorName;

  const _AuthorHistoryDialog({required this.client, required this.userId, required this.authorName});

  @override
  State<_AuthorHistoryDialog> createState() => _AuthorHistoryDialogState();
}

class _AuthorHistoryDialogState extends State<_AuthorHistoryDialog> {
  bool _loading = true;
  Object? _error;
  Map<String, dynamic>? _history;
  String _postingStatus = 'Active';
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final body = await widget.client.discussionUserReportHistory(widget.userId);
      if (!mounted) return;
      setState(() {
        _history = Map<String, dynamic>.from(body['history'] ?? {});
        _postingStatus = '${body['posting_status'] ?? 'Active'}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _toggleSuspend(bool suspend) async {
    setState(() => _updating = true);
    try {
      final result = await widget.client.discussionUserSuspend(widget.userId, suspended: suspend);
      if (!mounted) return;
      setState(() {
        _postingStatus = '${result['posting_status'] ?? (suspend ? 'Suspended' : 'Active')}';
        _updating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final suspended = _postingStatus == 'Suspended';
    return AlertDialog(
      title: Text(widget.authorName),
      content: _loading
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? Text('$_error')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total reported: ${_history?['total_reported'] ?? 0}'),
                    Text('Total actioned: ${_history?['total_actioned'] ?? 0}'),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: Text(suspended ? 'Discussion posting suspended' : 'Discussion posting allowed')),
                        _updating
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Switch(
                                value: suspended,
                                activeThumbColor: AppColors.danger,
                                onChanged: (v) => _toggleSuspend(v),
                              ),
                      ],
                    ),
                  ],
                ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
