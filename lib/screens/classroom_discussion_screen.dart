import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_ago.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/discussion/discussion_common.dart';
import '../widgets/discussion/media_embed.dart';
import '../widgets/discussion/photo_grid.dart';
import '../widgets/error_state.dart' show ErrorState, friendlyErrorMessage;
import 'discussion_moderation_screen.dart';

class ClassroomDiscussionScreen extends StatefulWidget {
  final int classId;

  const ClassroomDiscussionScreen({super.key, required this.classId});

  @override
  State<ClassroomDiscussionScreen> createState() => _ClassroomDiscussionScreenState();
}

class _ClassroomDiscussionScreenState extends State<ClassroomDiscussionScreen> {
  late ApiClient _client;
  final _msgCtrl = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _pendingImages = [];
  bool _loading = true;
  bool _posting = false;
  String? _error;
  bool _canPost = false;
  bool _canModerate = false;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await _client.getClassroomDiscussion(widget.classId);
      setState(() {
        _canPost = body['canPost'] == true;
        _canModerate = body['canModerate'] == true;
        _posts = List<Map<String, dynamic>>.from((body['posts'] ?? []) as List).map(clonePost).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
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
      final post = await _client.postClassDiscussion(
        widget.classId,
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
    final postId = asInt(post['cd_id']);
    try {
      final result = await _client.likeClassDiscussion(postId, type: type);
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
    final postId = asInt(post['cd_id']);
    final comments = List<Map<String, dynamic>>.from(post['comments'] as List);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClassCommentsSheet(
        client: _client,
        postId: postId,
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
    final urls = photos.map((p) => ApiConfig.discussionPhotoUrl('${p['photo_path'] ?? ''}')).toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(urls: urls, initialIndex: initialIndex),
        fullscreenDialog: true,
      ),
    );
  }

  void _openModerationQueue() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DiscussionModerationScreen(client: _client, classId: widget.classId)),
    );
  }

  Future<void> _editPost(Map<String, dynamic> post) async {
    final postId = asInt(post['cd_id']);
    await showDiscussionEditDialog(
      context,
      initialText: '${post['message'] ?? ''}',
      onSubmit: (text) async {
        final result = await _client.classDiscussionEdit(postId, message: text);
        setState(() {
          post['message'] = result['message'];
          post['edited_at'] = result['edited_at'];
          post['is_edited'] = true;
        });
      },
    );
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    if (!await confirmDiscussionDelete(context, 'post')) return;
    final postId = asInt(post['cd_id']);
    try {
      await _client.classDiscussionDelete(postId);
      if (!mounted) return;
      setState(() => _posts.removeWhere((p) => p['cd_id'] == post['cd_id']));
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  Future<void> _reportPost(Map<String, dynamic> post) async {
    final postId = asInt(post['cd_id']);
    await showDiscussionReportDialog(
      context,
      onSubmit: (description) async {
        await _client.classDiscussionReport(postId, description: description);
        setState(() {
          post['is_reported'] = true;
          post['report_count'] = asInt(post['report_count']) + 1;
        });
      },
    );
  }

  Widget _composer(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _msgCtrl,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Share something with the class...',
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

  Widget _authorRow(String name, String photo, String roleName, String createdAt, {double radius = 16, bool isEdited = false}) {
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
              Row(
                children: [
                  Text(
                    [if (roleName.isNotEmpty) roleName, timeAgo(createdAt)].join(' · '),
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                  if (isEdited) const EditedBadge(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final scheme = Theme.of(context).colorScheme;
    final photos = List<Map<String, dynamic>>.from(post['photos'] as List? ?? []);
    final photoUrls = photos.map((p) => ApiConfig.discussionPhotoUrl('${p['photo_path'] ?? ''}')).toList();
    final message = '${post['message'] ?? ''}';
    final urls = extractUrls(message);
    final reaction = post['user_reaction'];
    final postId = asInt(post['cd_id']);
    final totalReactions = asInt(post['like_count']) + asInt(post['dislike_count']);
    final isRemoved = post['is_removed'] == true;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _authorRow(
                  '${post['author_name'] ?? ''}',
                  '${post['author_photo'] ?? ''}',
                  '${post['author_role_cat_name'] ?? ''}',
                  '${post['created_at'] ?? ''}',
                  isEdited: post['is_edited'] == true,
                ),
              ),
              if (!isRemoved)
                DiscussionActionMenu(
                  canEdit: post['can_edit'] == true,
                  canDelete: post['can_delete'] == true,
                  onEdit: () => _editPost(post),
                  onDelete: () => _deletePost(post),
                  onReport: post['is_mine'] == true ? null : () => _reportPost(post),
                ),
            ],
          ),
          if (isRemoved) ...[
            const SizedBox(height: 10),
            DeletedContentTile(label: 'Deleted post', removal: post['removal'] as Map<String, dynamic>?),
          ] else ...[
            if (message.isNotEmpty) ...[
              const SizedBox(height: 10),
              ExpandableText(message, style: const TextStyle(fontSize: 14)),
            ],
            if (urls.isNotEmpty) ...[
              const SizedBox(height: 10),
              DiscussionMediaEmbed(url: urls.first),
            ],
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              DiscussionPhotoGrid(
                photoUrls: photoUrls,
                onTapPhoto: (i) => _openPhotos(photos, i),
              ),
            ],
            const SizedBox(height: 10),
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
                    onPressed: () => showReactionsSheet(context, () => _client.getClassDiscussionReactions(postId)),
                    icon: Icon(Icons.people_outline, size: 15, color: scheme.onSurfaceVariant),
                    label: Text('$totalReactions', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ),
                if (post['report_count'] != null && asInt(post['report_count']) > 0) ...[
                  const SizedBox(width: 8),
                  ReportFlagBadge(
                    reportCount: asInt(post['report_count']),
                    loadReports: () => _client.classDiscussionReports(postId),
                    onVote: (reportId, type) => _client.discussionReportVote(reportId, type: type),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion'),
        actions: [
          if (_canModerate) IconButton(icon: const Icon(Icons.shield_outlined), onPressed: _openModerationQueue),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorState(error: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_canPost) _composer(scheme),
                        if (_posts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Center(
                              child: Text('No posts yet.', style: TextStyle(color: scheme.onSurfaceVariant)),
                            ),
                          )
                        else
                          for (final post in _posts) _postCard(post),
                      ],
                    ),
                  ),
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

class _ClassCommentsSheet extends StatefulWidget {
  final ApiClient client;
  final int postId;
  final List<Map<String, dynamic>> comments;
  final VoidCallback onCommentAdded;

  const _ClassCommentsSheet({
    required this.client,
    required this.postId,
    required this.comments,
    required this.onCommentAdded,
  });

  @override
  State<_ClassCommentsSheet> createState() => _ClassCommentsSheetState();
}

class _ClassCommentsSheetState extends State<_ClassCommentsSheet> {
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
      final comment = await widget.client.commentClassDiscussion(widget.postId, text);
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
    final commentId = asInt(comment['cdc_id']);
    final key = 'c$commentId';
    final ctrl = _replyCtrls[key];
    final text = ctrl?.text.trim() ?? '';
    if (text.isEmpty) return;
    setState(() => _sendingReply = true);
    try {
      final reply = await widget.client.replyClassDiscussionComment(commentId, text);
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
    final parentReplyId = asInt(parentReply['cdcr_id']);
    final key = 'r$parentReplyId';
    final ctrl = _replyCtrls[key];
    final text = ctrl?.text.trim() ?? '';
    if (text.isEmpty) return;
    setState(() => _sendingReply = true);
    try {
      final reply = await widget.client.replyToClassDiscussionReply(parentReplyId, text);
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
    final commentId = asInt(comment['cdc_id']);
    try {
      final result = await widget.client.likeClassDiscussionComment(commentId, type: type);
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
    final replyId = asInt(reply['cdcr_id']);
    try {
      final result = await widget.client.likeClassDiscussionReply(replyId, type: type);
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

  Future<void> _editComment(Map<String, dynamic> comment) async {
    final commentId = asInt(comment['cdc_id']);
    await showDiscussionEditDialog(
      context,
      initialText: '${comment['comment'] ?? ''}',
      onSubmit: (text) async {
        final result = await widget.client.classDiscussionCommentEdit(commentId, message: text);
        setState(() {
          comment['comment'] = result['message'];
          comment['edited_at'] = result['edited_at'];
          comment['is_edited'] = true;
        });
      },
    );
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    if (!await confirmDiscussionDelete(context, 'comment')) return;
    final commentId = asInt(comment['cdc_id']);
    try {
      await widget.client.classDiscussionCommentDelete(commentId);
      if (!mounted) return;
      setState(() => widget.comments.removeWhere((c) => c['cdc_id'] == comment['cdc_id']));
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  Future<void> _reportComment(Map<String, dynamic> comment) async {
    final commentId = asInt(comment['cdc_id']);
    await showDiscussionReportDialog(
      context,
      onSubmit: (description) async {
        await widget.client.classDiscussionCommentReport(commentId, description: description);
        setState(() {
          comment['is_reported'] = true;
          comment['report_count'] = asInt(comment['report_count']) + 1;
        });
      },
    );
  }

  Future<void> _editReply(Map<String, dynamic> reply) async {
    final replyId = asInt(reply['cdcr_id']);
    await showDiscussionEditDialog(
      context,
      initialText: '${reply['reply'] ?? ''}',
      onSubmit: (text) async {
        final result = await widget.client.classDiscussionReplyEdit(replyId, message: text);
        setState(() {
          reply['reply'] = result['message'];
          reply['edited_at'] = result['edited_at'];
          reply['is_edited'] = true;
        });
      },
    );
  }

  bool _removeReplyRecursive(List<Map<String, dynamic>> list, int replyId) {
    final before = list.length;
    list.removeWhere((r) => asInt(r['cdcr_id']) == replyId);
    if (list.length != before) return true;
    for (final r in list) {
      final nested = r['replies'] as List<Map<String, dynamic>>?;
      if (nested != null && _removeReplyRecursive(nested, replyId)) return true;
    }
    return false;
  }

  Future<void> _deleteReply(Map<String, dynamic> reply) async {
    if (!await confirmDiscussionDelete(context, 'reply')) return;
    final replyId = asInt(reply['cdcr_id']);
    try {
      await widget.client.classDiscussionReplyDelete(replyId);
      if (!mounted) return;
      setState(() {
        for (final c in widget.comments) {
          final replies = c['replies'] as List<Map<String, dynamic>>?;
          if (replies != null && _removeReplyRecursive(replies, replyId)) break;
        }
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, friendlyErrorMessage(e));
    }
  }

  Future<void> _reportReply(Map<String, dynamic> reply) async {
    final replyId = asInt(reply['cdcr_id']);
    await showDiscussionReportDialog(
      context,
      onSubmit: (description) async {
        await widget.client.classDiscussionReplyReport(replyId, description: description);
        setState(() {
          reply['is_reported'] = true;
          reply['report_count'] = asInt(reply['report_count']) + 1;
        });
      },
    );
  }

  Widget _authorRow(String name, String photo, String roleName, String createdAt, {double radius = 14, bool isEdited = false}) {
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
              Row(
                children: [
                  Text(
                    [if (roleName.isNotEmpty) roleName, timeAgo(createdAt)].join(' · '),
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                  ),
                  if (isEdited) const EditedBadge(),
                ],
              ),
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
    final replyId = asInt(r['cdcr_id']);
    final key = 'r$replyId';
    final nested = List<Map<String, dynamic>>.from(r['replies'] as List? ?? []);
    final ctrl = _replyCtrls.putIfAbsent(key, () => TextEditingController());
    final indent = 26.0 + (depth * 20).clamp(0, 60);
    final isRemoved = r['is_removed'] == true;
    return Padding(
      padding: EdgeInsets.only(top: 10, left: indent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _authorRow(
                  '${r['author_name'] ?? ''}',
                  '${r['author_photo'] ?? ''}',
                  '${r['author_role_cat_name'] ?? ''}',
                  '${r['created_at'] ?? ''}',
                  radius: 11,
                  isEdited: r['is_edited'] == true,
                ),
              ),
              if (!isRemoved)
                DiscussionActionMenu(
                  canEdit: r['can_edit'] == true,
                  canDelete: r['can_delete'] == true,
                  onEdit: () => _editReply(r),
                  onDelete: () => _deleteReply(r),
                  onReport: r['is_mine'] == true ? null : () => _reportReply(r),
                ),
            ],
          ),
          if (isRemoved)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 3),
              child: DeletedContentTile(label: 'Deleted reply', removal: r['removal'] as Map<String, dynamic>?),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 3),
              child: ExpandableText('${r['reply'] ?? ''}', style: const TextStyle(fontSize: 12)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 3),
              child: Row(
                children: [
                  _reactionRow(
                    r,
                    _reactToReply,
                    onReply: () => setState(() => _replyingToKey = _replyingToKey == key ? null : key),
                    fetchReactions: () => widget.client.getClassDiscussionReplyReactions(replyId),
                  ),
                  if (asInt(r['report_count']) > 0) ...[
                    const SizedBox(width: 10),
                    ReportFlagBadge(
                      reportCount: asInt(r['report_count']),
                      loadReports: () => widget.client.classDiscussionReplyReports(replyId),
                      onVote: (reportId, type) => widget.client.discussionReportVote(reportId, type: type),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
    final commentId = asInt(c['cdc_id']);
    final key = 'c$commentId';
    final replies = List<Map<String, dynamic>>.from(c['replies'] as List? ?? []);
    final ctrl = _replyCtrls.putIfAbsent(key, () => TextEditingController());
    final isRemoved = c['is_removed'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _authorRow(
                  '${c['author_name'] ?? ''}',
                  '${c['author_photo'] ?? ''}',
                  '${c['author_role_cat_name'] ?? ''}',
                  '${c['created_at'] ?? ''}',
                  isEdited: c['is_edited'] == true,
                ),
              ),
              if (!isRemoved)
                DiscussionActionMenu(
                  canEdit: c['can_edit'] == true,
                  canDelete: c['can_delete'] == true,
                  onEdit: () => _editComment(c),
                  onDelete: () => _deleteComment(c),
                  onReport: c['is_mine'] == true ? null : () => _reportComment(c),
                ),
            ],
          ),
          if (isRemoved)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: DeletedContentTile(label: 'Deleted comment', removal: c['removal'] as Map<String, dynamic>?),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: ExpandableText('${c['comment'] ?? ''}', style: const TextStyle(fontSize: 13)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: Row(
                children: [
                  _reactionRow(
                    c,
                    _reactToComment,
                    onReply: () => setState(() => _replyingToKey = _replyingToKey == key ? null : key),
                    fetchReactions: () => widget.client.getClassDiscussionCommentReactions(commentId),
                  ),
                  if (asInt(c['report_count']) > 0) ...[
                    const SizedBox(width: 10),
                    ReportFlagBadge(
                      reportCount: asInt(c['report_count']),
                      loadReports: () => widget.client.classDiscussionCommentReports(commentId),
                      onVote: (reportId, type) => widget.client.discussionReportVote(reportId, type: type),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
