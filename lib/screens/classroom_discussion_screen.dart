import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_ago.dart';
import '../widgets/error_state.dart';

class ClassroomDiscussionScreen extends StatefulWidget {
  final int classId;

  const ClassroomDiscussionScreen({super.key, required this.classId});

  @override
  State<ClassroomDiscussionScreen> createState() => _ClassroomDiscussionScreenState();
}

class _ClassroomDiscussionScreenState extends State<ClassroomDiscussionScreen> {
  late ApiClient _client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await _client.getClassroomDiscussion(widget.classId);
      setState(() {
        _posts = List<Map<String, dynamic>>.from(body['posts'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Widget _authorRow(String name, String photo, String roleName, String createdAt, {double radius = 16}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundImage: photo.isNotEmpty ? NetworkImage(ApiConfig.photoUrl(photo)) : null,
          child: photo.isEmpty ? Icon(Icons.person, color: AppColors.primary, size: radius) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text(
                [if (roleName.isNotEmpty) roleName, timeAgo(createdAt)].join(' · '),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _replyTile(Map<String, dynamic> r) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _authorRow(
            '${r['author_name'] ?? ''}',
            '${r['author_photo'] ?? ''}',
            '${r['author_role_cat_name'] ?? ''}',
            '${r['created_at'] ?? ''}',
            radius: 12,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child: Text('${r['reply'] ?? ''}', style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _commentTile(Map<String, dynamic> c) {
    final replies = List<Map<String, dynamic>>.from(c['replies'] ?? []);
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _authorRow(
            '${c['author_name'] ?? ''}',
            '${c['author_photo'] ?? ''}',
            '${c['author_role_cat_name'] ?? ''}',
            '${c['created_at'] ?? ''}',
            radius: 13,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 4),
            child: Text('${c['comment'] ?? ''}', style: const TextStyle(fontSize: 13)),
          ),
          for (final r in replies) _replyTile(r),
        ],
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final scheme = Theme.of(context).colorScheme;
    final photos = List<Map<String, dynamic>>.from(post['photos'] ?? []);
    final comments = List<Map<String, dynamic>>.from(post['comments'] ?? []);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _authorRow(
            '${post['author_name'] ?? ''}',
            '${post['author_photo'] ?? ''}',
            '${post['author_role_cat_name'] ?? ''}',
            '${post['created_at'] ?? ''}',
          ),
          if ((post['message'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('${post['message']}', style: const TextStyle(fontSize: 14)),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (context, i) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    ApiConfig.discussionPhotoUrl('${photos[i]['photo_path'] ?? ''}'),
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      width: 90,
                      height: 90,
                      color: scheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.thumb_up_alt_outlined, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${post['like_count'] ?? 0}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 14),
              Icon(Icons.thumb_down_alt_outlined, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${post['dislike_count'] ?? 0}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 14),
              Icon(Icons.mode_comment_outlined, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${post['comment_count'] ?? 0}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
          if (comments.isNotEmpty) ...[
            const Divider(height: 24),
            for (final c in comments) _commentTile(c),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discussion')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorState(error: _error!, onRetry: _load)
                : _posts.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('No posts yet.')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [for (final p in _posts) _postCard(p)],
                        ),
                      ),
      ),
    );
  }
}
