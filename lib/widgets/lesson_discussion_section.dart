import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/lesson_discussion_realtime.dart';
import '../theme/app_theme.dart';
import '../utils/time_ago.dart';
import 'app_snackbar.dart';
import 'discussion/discussion_common.dart';
import 'error_state.dart' show friendlyErrorMessage;

class LessonDiscussionSection extends StatefulWidget {
  final ApiClient client;
  final int lessonId;
  final List<Map<String, dynamic>> initialDiscussions;

  const LessonDiscussionSection({
    super.key,
    required this.client,
    required this.lessonId,
    required this.initialDiscussions,
  });

  @override
  State<LessonDiscussionSection> createState() => _LessonDiscussionSectionState();
}

class _LessonDiscussionSectionState extends State<LessonDiscussionSection> {
  final _msgCtrl = TextEditingController();
  final _picker = ImagePicker();
  late List<Map<String, dynamic>> _posts;
  final List<XFile> _pendingImages = [];
  bool _posting = false;
  LessonDiscussionRealtime? _realtime;

  @override
  void initState() {
    super.initState();
    _posts = widget.initialDiscussions.map(clonePost).toList();
    _realtime = LessonDiscussionRealtime(
      client: widget.client,
      lessonId: widget.lessonId,
      onUpdate: (discussion) {
        if (!mounted) return;
        setState(() => _posts = discussion.map(clonePost).toList());
      },
    )..start();
  }

  @override
  void dispose() {
    _realtime?.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;
    setState(() => _pendingImages.addAll(images));
  }

  Future<void> _submitPost() async {
    final message = _msgCtrl.text.trim();
    if (message.isEmpty && _pendingImages.isEmpty) return;
    setState(() => _posting = true);
    try {
      final photoFiles = <http.MultipartFile>[];
      for (final img in _pendingImages) {
        final bytes = await img.readAsBytes();
        photoFiles.add(http.MultipartFile.fromBytes('photos[]', bytes, filename: img.name));
      }
      final post = await widget.client.postLessonDiscussion(
        widget.lessonId,
        message: message,
        photos: photoFiles.isEmpty ? null : photoFiles,
      );
      setState(() {
        _posts.insert(0, clonePost(post));
        _msgCtrl.clear();
        _pendingImages.clear();
        _posting = false;
      });
    } catch (e) {
      setState(() => _posting = false);
      if (!mounted) return;
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  Future<void> _reactToPost(Map<String, dynamic> post, String type) async {
    final discussionId = asInt(post['lesson_discussion_id']);
    try {
      final result = await widget.client.likeLessonDiscussion(discussionId, type: type);
      setState(() {
        post['user_reaction'] = result['reaction'];
        post['like_count'] = result['likes'];
        post['dislike_count'] = result['dislikes'];
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  void _openComments(Map<String, dynamic> post) {
    final discussionId = asInt(post['lesson_discussion_id']);
    final comments = List<Map<String, dynamic>>.from(post['comments'] as List);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        client: widget.client,
        discussionId: discussionId,
        comments: comments,
        onCommentAdded: () {
          setState(() {
            post['comments'] = comments;
            post['comment_count'] = asInt(post['comment_count']) + 1;
          });
        },
      ),
    );
  }

  void _openPhotos(List<Map<String, dynamic>> photos, int initialIndex) {
    final urls = photos.map((p) => ApiConfig.lessonDiscussionPhotoUrl('${p['photo_path'] ?? ''}')).toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(urls: urls, initialIndex: initialIndex),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _composer(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _msgCtrl,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Ask a question or share something about this lesson...',
              border: InputBorder.none,
            ),
          ),
          if (_pendingImages.isNotEmpty)
            SizedBox(
              height: 66,
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
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Post'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _authorRow(String name, String photo, String createdAt, {double radius = 16}) {
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
              Text(timeAgo(createdAt), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final scheme = Theme.of(context).colorScheme;
    final photos = List<Map<String, dynamic>>.from(post['photos'] as List? ?? []);
    final reaction = post['user_reaction'];
    final discussionId = asInt(post['lesson_discussion_id']);
    final totalReactions = asInt(post['like_count']) + asInt(post['dislike_count']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _authorRow('${post['author_name'] ?? ''}', '${post['author_photo'] ?? ''}', '${post['created_at'] ?? ''}'),
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
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _openPhotos(photos, i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      ApiConfig.lessonDiscussionPhotoUrl('${photos[i]['photo_path'] ?? ''}'),
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
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _reactToPost(post, 'like'),
                icon: Icon(
                  reaction == 'like' ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 16,
                  color: reaction == 'like' ? AppColors.primary : scheme.onSurfaceVariant,
                ),
                label: Text(
                  '${post['like_count'] ?? 0}',
                  style: TextStyle(fontSize: 12, color: reaction == 'like' ? AppColors.primary : scheme.onSurfaceVariant),
                ),
              ),
              TextButton.icon(
                onPressed: () => _reactToPost(post, 'dislike'),
                icon: Icon(
                  reaction == 'dislike' ? Icons.thumb_down : Icons.thumb_down_outlined,
                  size: 16,
                  color: reaction == 'dislike' ? AppColors.danger : scheme.onSurfaceVariant,
                ),
                label: Text(
                  '${post['dislike_count'] ?? 0}',
                  style: TextStyle(fontSize: 12, color: reaction == 'dislike' ? AppColors.danger : scheme.onSurfaceVariant),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openComments(post),
                icon: Icon(Icons.mode_comment_outlined, size: 16, color: scheme.onSurfaceVariant),
                label: Text('${post['comment_count'] ?? 0}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
              if (totalReactions > 0)
                TextButton.icon(
                  onPressed: () => showReactionsSheet(context, () => widget.client.getLessonDiscussionReactions(discussionId)),
                  icon: Icon(Icons.people_outline, size: 15, color: scheme.onSurfaceVariant),
                  label: Text('$totalReactions', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
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
    return Container(
      width: double.infinity,
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
              const Text('Lesson Discussion', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${_posts.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _composer(scheme),
          const SizedBox(height: 12),
          if (_posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No discussion yet. Start the conversation!', style: TextStyle(color: scheme.onSurfaceVariant))),
            )
          else
            for (final post in _posts) _postCard(post),
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
                  ? Image.memory(snapshot.data!, width: 60, height: 60, fit: BoxFit.cover)
                  : Container(width: 60, height: 60, color: Colors.black12),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: const CircleAvatar(
                  radius: 9,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 11, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}


class _CommentsSheet extends StatefulWidget {
  final ApiClient client;
  final int discussionId;
  final List<Map<String, dynamic>> comments;
  final VoidCallback onCommentAdded;

  const _CommentsSheet({
    required this.client,
    required this.discussionId,
    required this.comments,
    required this.onCommentAdded,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentCtrl = TextEditingController();
  final Map<String, TextEditingController> _replyCtrls = {};
  String? _replyingToKey;
  bool _sendingComment = false;
  bool _sendingReply = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    for (final c in _replyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingComment = true);
    try {
      final comment = await widget.client.commentLessonDiscussion(widget.discussionId, text);
      setState(() {
        widget.comments.add(cloneComment(comment));
        _commentCtrl.clear();
        _sendingComment = false;
      });
      widget.onCommentAdded();
    } catch (e) {
      setState(() => _sendingComment = false);
      if (!mounted) return;
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  Future<void> _sendReply(Map<String, dynamic> comment) async {
    final commentId = asInt(comment['comment_id']);
    final key = 'c$commentId';
    final ctrl = _replyCtrls[key];
    final text = ctrl?.text.trim() ?? '';
    if (text.isEmpty) return;
    setState(() => _sendingReply = true);
    try {
      final reply = await widget.client.replyLessonDiscussionComment(commentId, text);
      setState(() {
        (comment['replies'] as List<Map<String, dynamic>>).add(cloneReply(reply));
        ctrl?.clear();
        _replyingToKey = null;
        _sendingReply = false;
      });
    } catch (e) {
      setState(() => _sendingReply = false);
      if (!mounted) return;
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  Future<void> _sendNestedReply(Map<String, dynamic> parentReply) async {
    final parentReplyId = asInt(parentReply['reply_id']);
    final key = 'r$parentReplyId';
    final ctrl = _replyCtrls[key];
    final text = ctrl?.text.trim() ?? '';
    if (text.isEmpty) return;
    setState(() => _sendingReply = true);
    try {
      final reply = await widget.client.replyToLessonDiscussionReply(parentReplyId, text);
      setState(() {
        (parentReply['replies'] as List<Map<String, dynamic>>).add(cloneReply(reply));
        ctrl?.clear();
        _replyingToKey = null;
        _sendingReply = false;
      });
    } catch (e) {
      setState(() => _sendingReply = false);
      if (!mounted) return;
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  Future<void> _reactToComment(Map<String, dynamic> comment, String type) async {
    final commentId = asInt(comment['comment_id']);
    try {
      final result = await widget.client.likeLessonDiscussionComment(commentId, type: type);
      setState(() {
        comment['user_reaction'] = result['reaction'];
        comment['like_count'] = result['likes'];
        comment['dislike_count'] = result['dislikes'];
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  Future<void> _reactToReply(Map<String, dynamic> reply, String type) async {
    final replyId = asInt(reply['reply_id']);
    try {
      final result = await widget.client.likeLessonDiscussionReply(replyId, type: type);
      setState(() {
        reply['user_reaction'] = result['reaction'];
        reply['like_count'] = result['likes'];
        reply['dislike_count'] = result['dislikes'];
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  Widget _authorRow(String name, String photo, String createdAt, {double radius = 14}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundImage: photo.isNotEmpty ? NetworkImage(ApiConfig.photoUrl(photo)) : null,
          child: photo.isEmpty ? Icon(Icons.person, color: AppColors.primary, size: radius) : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              Text(timeAgo(createdAt), style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reactionRow(
    Map<String, dynamic> target,
    Future<void> Function(Map<String, dynamic>, String) onReact, {
    VoidCallback? onReply,
    Future<List<Map<String, dynamic>>> Function()? fetchReactions,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final reaction = target['user_reaction'];
    final totalReactions = asInt(target['like_count']) + asInt(target['dislike_count']);
    return Row(
      children: [
        GestureDetector(
          onTap: () => onReact(target, 'like'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(reaction == 'like' ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 13, color: reaction == 'like' ? AppColors.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 3),
              Text('${target['like_count'] ?? 0}',
                  style: TextStyle(fontSize: 11, color: reaction == 'like' ? AppColors.primary : scheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: () => onReact(target, 'dislike'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(reaction == 'dislike' ? Icons.thumb_down : Icons.thumb_down_outlined,
                  size: 13, color: reaction == 'dislike' ? AppColors.danger : scheme.onSurfaceVariant),
              const SizedBox(width: 3),
              Text('${target['dislike_count'] ?? 0}',
                  style: TextStyle(fontSize: 11, color: reaction == 'dislike' ? AppColors.danger : scheme.onSurfaceVariant)),
            ],
          ),
        ),
        if (totalReactions > 0 && fetchReactions != null) ...[
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () => showReactionsSheet(context, fetchReactions),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, size: 13, color: scheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text('$totalReactions', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
        if (onReply != null) ...[
          const SizedBox(width: 14),
          GestureDetector(
            onTap: onReply,
            child: Text('Reply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
          ),
        ],
      ],
    );
  }

  Widget _replyTile(Map<String, dynamic> r, {int depth = 0}) {
    final replyId = asInt(r['reply_id']);
    final key = 'r$replyId';
    final nested = List<Map<String, dynamic>>.from(r['replies'] as List? ?? []);
    final ctrl = _replyCtrls.putIfAbsent(key, () => TextEditingController());
    final indent = 26.0 + (depth * 20).clamp(0, 60);
    return Padding(
      padding: EdgeInsets.only(top: 10, left: indent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _authorRow('${r['author_name'] ?? ''}', '${r['author_photo'] ?? ''}', '${r['created_at'] ?? ''}', radius: 11),
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 3),
            child: Text('${r['reply'] ?? ''}', style: const TextStyle(fontSize: 12)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 3),
            child: _reactionRow(
              r,
              _reactToReply,
              onReply: () => setState(() => _replyingToKey = _replyingToKey == key ? null : key),
              fetchReactions: () => widget.client.getLessonDiscussionReplyReactions(replyId),
            ),
          ),
          if (_replyingToKey == key)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(hintText: 'Write a reply...', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: _sendingReply
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send, size: 18, color: AppColors.primary),
                    onPressed: _sendingReply ? null : () => _sendNestedReply(r),
                  ),
                ],
              ),
            ),
          for (final nr in nested) _replyTile(nr, depth: depth + 1),
        ],
      ),
    );
  }

  Widget _commentTile(Map<String, dynamic> c) {
    final commentId = asInt(c['comment_id']);
    final key = 'c$commentId';
    final replies = List<Map<String, dynamic>>.from(c['replies'] as List? ?? []);
    final ctrl = _replyCtrls.putIfAbsent(key, () => TextEditingController());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _authorRow('${c['author_name'] ?? ''}', '${c['author_photo'] ?? ''}', '${c['created_at'] ?? ''}'),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 4),
            child: Text('${c['comment'] ?? ''}', style: const TextStyle(fontSize: 13)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 4),
            child: _reactionRow(
              c,
              _reactToComment,
              onReply: () => setState(() => _replyingToKey = _replyingToKey == key ? null : key),
              fetchReactions: () => widget.client.getLessonDiscussionCommentReactions(commentId),
            ),
          ),
          for (final r in replies) _replyTile(r),
          if (_replyingToKey == key)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(hintText: 'Write a reply...', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: _sendingReply
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send, size: 18, color: AppColors.primary),
                    onPressed: _sendingReply ? null : () => _sendReply(c),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
              child: widget.comments.isEmpty
                  ? Center(child: Text('No comments yet.', style: TextStyle(color: scheme.onSurfaceVariant)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: widget.comments.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => _commentTile(widget.comments[i]),
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
                        controller: _commentCtrl,
                        decoration: const InputDecoration(hintText: 'Write a comment...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _sendingComment
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, color: AppColors.primary),
                      onPressed: _sendingComment ? null : _sendComment,
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
