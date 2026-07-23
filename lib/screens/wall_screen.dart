import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/wall_post.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/error_state.dart';
import '../widgets/school_tab_bar.dart';

class WallScreen extends StatefulWidget {
  const WallScreen({super.key});

  @override
  State<WallScreen> createState() => _WallScreenState();
}

class _WallScreenState extends State<WallScreen> {
  final _contentCtrl = TextEditingController();
  final _picker = ImagePicker();

  late ApiClient _client;
  final List<WallPost> _posts = [];
  final List<XFile> _pendingImages = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _posting = false;
  bool _hasMore = false;
  String? _error;
  int? _schoolId;
  List<Map<String, dynamic>> _schools = [];

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    _loadFirstPage();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _client.getWallFeed(offset: 0, schoolId: _schoolId);
      setState(() {
        _posts
          ..clear()
          ..addAll(result.posts);
        _hasMore = result.hasMore;
        _schools = result.schools;
        _schoolId = result.activeSchoolId;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _client.getWallFeed(
        offset: _posts.length,
        schoolId: _schoolId,
      );
      setState(() {
        _posts.addAll(result.posts);
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  void _switchSchool(int schId) {
    setState(() => _schoolId = schId);
    _loadFirstPage();
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;
    setState(() => _pendingImages.addAll(images));
  }

  Future<void> _submitPost() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty && _pendingImages.isEmpty) return;

    setState(() => _posting = true);
    try {
      final mediaFiles = <http.MultipartFile>[];
      for (final img in _pendingImages) {
        final bytes = await img.readAsBytes();
        mediaFiles.add(http.MultipartFile.fromBytes(
          'media[]',
          bytes,
          filename: img.name,
        ));
      }

      final post = await _client.createWallPost(
        content: content,
        mediaFiles: mediaFiles.isEmpty ? null : mediaFiles,
        schoolId: _schoolId,
      );

      setState(() {
        _posts.insert(0, post);
        _contentCtrl.clear();
        _pendingImages.clear();
        _posting = false;
      });
    } catch (e) {
      setState(() => _posting = false);
      if (!mounted) return;
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  Future<void> _toggleLike(WallPost post) async {
    try {
      final reactions = await _client.react(
        targetType: 'post',
        targetId: post.wallPostId,
        emoji: '👍',
      );
      final index = _posts.indexWhere((p) => p.wallPostId == post.wallPostId);
      if (index == -1) return;
      setState(() {
        _posts[index] = WallPost(
          wallPostId: post.wallPostId,
          userId: post.userId,
          content: post.content,
          age: post.age,
          createdAt: post.createdAt,
          authorName: post.authorName,
          authorPhoto: post.authorPhoto,
          authorRole: post.authorRole,
          commentCount: post.commentCount,
          reactionCount: reactions.total,
          reactions: reactions,
          media: post.media,
          isMine: post.isMine,
        );
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  void _openComments(WallPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        client: _client,
        post: post,
        onCommentAdded: () {
          final index =
              _posts.indexWhere((p) => p.wallPostId == post.wallPostId);
          if (index == -1) return;
          setState(() {
            final p = _posts[index];
            _posts[index] = WallPost(
              wallPostId: p.wallPostId,
              userId: p.userId,
              content: p.content,
              age: p.age,
              createdAt: p.createdAt,
              authorName: p.authorName,
              authorPhoto: p.authorPhoto,
              authorRole: p.authorRole,
              commentCount: p.commentCount + 1,
              reactionCount: p.reactionCount,
              reactions: p.reactions,
              media: p.media,
              isMine: p.isMine,
            );
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wall'),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorState(error: _error!, onRetry: _loadFirstPage)
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels >=
                          n.metrics.maxScrollExtent - 200) {
                        _loadMore();
                      }
                      return false;
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        SchoolTabBar(
                          schools: _schools,
                          activeSchoolId: _schoolId ?? 0,
                          onSelected: _switchSchool,
                        ),
                        _buildComposer(scheme),
                        const SizedBox(height: 16),
                        if (_posts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'No posts yet. Be the first to share something!',
                                style:
                                    TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          )
                        else
                          for (final post in _posts)
                            _WallPostCard(
                              post: post,
                              onLike: () => _toggleLike(post),
                              onComment: () => _openComments(post),
                            ),
                        if (_loadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildComposer(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _contentCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: "What's on your mind?",
              border: InputBorder.none,
            ),
          ),
          if (_pendingImages.isNotEmpty)
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingImages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _PendingImageThumb(
                  file: _pendingImages[i],
                  onRemove: () => setState(() => _pendingImages.removeAt(i)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image_outlined, color: AppColors.primary),
                onPressed: _posting ? null : _pickImages,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _posting ? null : _submitPost,
                child: _posting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Post'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingImageThumb extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;

  const _PendingImageThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: snapshot.hasData
                  ? Image.memory(snapshot.data!,
                      width: 70, height: 70, fit: BoxFit.cover)
                  : Container(width: 70, height: 70, color: Colors.black12),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WallPostCard extends StatelessWidget {
  final WallPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const _WallPostCard({
    required this.post,
    required this.onLike,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final liked = post.reactions.myEmoji != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: post.authorPhoto.isNotEmpty
                    ? NetworkImage(post.authorPhoto)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      [
                        if (post.authorRole != null) post.authorRole!,
                        post.age,
                      ].join(' · '),
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(post.content),
          ],
          if (post.media.isNotEmpty) ...[
            const SizedBox(height: 10),
            _MediaGrid(media: post.media),
          ],
          const Divider(height: 20),
          Row(
            children: [
              TextButton.icon(
                onPressed: onLike,
                icon: Icon(
                  liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 18,
                  color: liked ? AppColors.primary : scheme.onSurfaceVariant,
                ),
                label: Text(
                  post.reactionCount > 0 ? '${post.reactionCount}' : 'Like',
                  style: TextStyle(
                    color: liked ? AppColors.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onComment,
                icon: Icon(Icons.mode_comment_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                label: Text(
                  post.commentCount > 0 ? '${post.commentCount}' : 'Comment',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  final List<WallMedia> media;

  const _MediaGrid({required this.media});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: media.map((m) {
        if (m.isVideoUrl) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    m.fileSrc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          );
        }
        if (m.isImage) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              m.fileSrc,
              width: 110,
              height: 110,
              fit: BoxFit.cover,
            ),
          );
        }
        return Chip(
          avatar: const Icon(Icons.insert_drive_file_outlined, size: 16),
          label: Text(m.fileName, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final ApiClient client;
  final WallPost post;
  final VoidCallback onCommentAdded;

  const _CommentsSheet({
    required this.client,
    required this.post,
    required this.onCommentAdded,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  late Future<List<WallComment>> _future;
  final List<WallComment> _comments = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<WallComment>> _load() async {
    final comments = await widget.client.getComments(widget.post.wallPostId);
    setState(() {
      _comments
        ..clear()
        ..addAll(comments);
    });
    return comments;
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final comment =
          await widget.client.addComment(widget.post.wallPostId, text);
      setState(() {
        _comments.add(comment);
        _ctrl.clear();
        _sending = false;
      });
      widget.onCommentAdded();
    } catch (e) {
      setState(() => _sending = false);
      if (!mounted) return;
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Comments', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<WallComment>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ErrorState(
                      error: snapshot.error!,
                      onRetry: () => setState(() => _future = _load()),
                    );
                  }
                  if (_comments.isEmpty) {
                    return Center(
                      child: Text('No comments yet.',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _comments.length,
                    itemBuilder: (context, i) {
                      final c = _comments[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: c.authorPhoto.isNotEmpty
                                  ? NetworkImage(c.authorPhoto)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.authorName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(c.content),
                                    const SizedBox(height: 4),
                                    Text(c.age,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: scheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: AppColors.primary),
                      onPressed: _sending ? null : _send,
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
