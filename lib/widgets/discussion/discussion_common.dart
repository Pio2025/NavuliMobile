import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_ago.dart';
import '../app_snackbar.dart';
import '../error_state.dart' show friendlyErrorMessage;

int asInt(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

int wordCount(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
}

/// Post/comment/reply body text, truncated to [maxChars] characters with a
/// "Show more"/"Show less" toggle when it overflows that limit.
class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxChars;

  const ExpandableText(this.text, {super.key, this.style, this.maxChars = 200});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    if (text.length <= widget.maxChars) {
      return Text(text, style: widget.style);
    }
    final shown = _expanded ? text : '${text.substring(0, widget.maxChars).trimRight()}…';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(shown, style: widget.style),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _expanded ? 'Show less' : 'Show more',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small "· Edited" marker shown next to a post/comment/reply timestamp.
class EditedBadge extends StatelessWidget {
  const EditedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      ' · Edited',
      style: TextStyle(
        fontSize: 11,
        fontStyle: FontStyle.italic,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Flag icon + pending-report count; tapping it opens the report detail/vote sheet.
class ReportFlagBadge extends StatelessWidget {
  final int reportCount;
  final Future<List<Map<String, dynamic>>> Function() loadReports;
  final Future<Map<String, dynamic>> Function(int reportId, String type) onVote;

  const ReportFlagBadge({
    super.key,
    required this.reportCount,
    required this.loadReports,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    if (reportCount <= 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ReportsSheet(loader: loadReports, onVote: onVote),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag, size: 13, color: AppColors.danger),
          const SizedBox(width: 3),
          Text('$reportCount', style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class ReportsSheet extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() loader;
  final Future<Map<String, dynamic>> Function(int reportId, String type) onVote;

  const ReportsSheet({super.key, required this.loader, required this.onVote});

  @override
  State<ReportsSheet> createState() => _ReportsSheetState();
}

class _ReportsSheetState extends State<ReportsSheet> {
  List<Map<String, dynamic>>? _reports;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reports = await widget.loader();
      if (!mounted) return;
      setState(() => _reports = reports);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _vote(Map<String, dynamic> report, String type) async {
    final reportId = asInt(report['report_id']);
    try {
      final result = await widget.onVote(reportId, type);
      if (!mounted) return;
      setState(() {
        report['my_vote'] = result['my_vote'];
        report['support_count'] = result['support_count'];
        report['oppose_count'] = result['oppose_count'];
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Text('Reports', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Flexible(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('$_error', style: TextStyle(color: scheme.error))),
                    )
                  : _reports == null
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _reports!.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(child: Text('No reports.', style: TextStyle(color: scheme.onSurfaceVariant))),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              itemCount: _reports!.length,
                              separatorBuilder: (_, _) => const Divider(height: 20),
                              itemBuilder: (context, i) {
                                final r = _reports![i];
                                final myVote = r['my_vote'];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                          backgroundImage: '${r['reporter_photo'] ?? ''}'.isNotEmpty
                                              ? NetworkImage(ApiConfig.photoUrl('${r['reporter_photo']}'))
                                              : null,
                                          child: '${r['reporter_photo'] ?? ''}'.isEmpty
                                              ? const Icon(Icons.person, size: 14, color: AppColors.primary)
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text('${r['reporter_name'] ?? ''}',
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                        ),
                                        Text('${r['report_status'] ?? ''}', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('${r['reason'] ?? ''}', style: const TextStyle(fontSize: 13)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _vote(r, 'support'),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            Icon(Icons.thumb_up,
                                                size: 14, color: myVote == 'support' ? AppColors.primary : scheme.onSurfaceVariant),
                                            const SizedBox(width: 4),
                                            Text('${r['support_count'] ?? 0}',
                                                style: TextStyle(
                                                    fontSize: 12, color: myVote == 'support' ? AppColors.primary : scheme.onSurfaceVariant)),
                                          ]),
                                        ),
                                        const SizedBox(width: 18),
                                        GestureDetector(
                                          onTap: () => _vote(r, 'oppose'),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            Icon(Icons.thumb_down,
                                                size: 14, color: myVote == 'oppose' ? AppColors.danger : scheme.onSurfaceVariant),
                                            const SizedBox(width: 4),
                                            Text('${r['oppose_count'] ?? 0}',
                                                style: TextStyle(
                                                    fontSize: 12, color: myVote == 'oppose' ? AppColors.danger : scheme.onSurfaceVariant)),
                                          ]),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// "Deleted post/comment/reply" placeholder shown in place of moderator-removed content.
class DeletedContentTile extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? removal;

  const DeletedContentTile({super.key, required this.label, this.removal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: removal == null ? null : () => showDialog(context: context, builder: (_) => _RemovalDetailDialog(removal: removal!)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: scheme.onSurfaceVariant,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemovalDetailDialog extends StatelessWidget {
  final Map<String, dynamic> removal;
  const _RemovalDetailDialog({required this.removal});

  @override
  Widget build(BuildContext context) {
    final reports = List<Map<String, dynamic>>.from(removal['reports'] as List? ?? []);
    final history = Map<String, dynamic>.from(removal['author_history'] as Map? ?? {});
    return AlertDialog(
      title: const Text('Removed for policy violation'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (removal['resolved_by'] != null)
              Text('Reviewed by ${removal['resolved_by']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (removal['resolved_at'] != null) Text(timeAgo('${removal['resolved_at']}'), style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 10),
            const Text('Report reasons:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            for (final r in reports)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• ${r['reporter_name'] ?? 'Someone'}: ${r['reason'] ?? ''}', style: const TextStyle(fontSize: 12)),
              ),
            const SizedBox(height: 12),
            Text(
              'This author has ${history['total_reported'] ?? 0} report(s) total, ${history['total_actioned'] ?? 0} actioned.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}

/// Edit / Delete / Report menu shown on a post/comment/reply the caller has some access to.
class DiscussionActionMenu extends StatelessWidget {
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  const DiscussionActionMenu({
    super.key,
    this.canEdit = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final showMenu = canEdit || canDelete || onReport != null;
    if (!showMenu) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 26,
      height: 22,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_vert, size: 17, color: scheme.onSurfaceVariant),
        onSelected: (value) {
          switch (value) {
            case 'edit':
              onEdit?.call();
              break;
            case 'delete':
              onDelete?.call();
              break;
            case 'report':
              onReport?.call();
              break;
          }
        },
        itemBuilder: (context) => [
          if (canEdit)
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit')]),
            ),
          if (canDelete)
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: AppColors.danger)),
              ]),
            ),
          if (onReport != null)
            const PopupMenuItem(
              value: 'report',
              child: Row(children: [Icon(Icons.flag_outlined, size: 16), SizedBox(width: 8), Text('Report')]),
            ),
        ],
      ),
    );
  }
}

Future<bool> confirmDiscussionDelete(BuildContext context, String label) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Delete $label?'),
      content: Text('This $label will be removed.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  return confirmed == true;
}

Future<void> showDiscussionEditDialog(
  BuildContext context, {
  required String initialText,
  required Future<void> Function(String message) onSubmit,
}) async {
  final ctrl = TextEditingController(text: initialText);
  var submitting = false;
  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Edit'),
          content: TextField(
            controller: ctrl,
            maxLines: 5,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Update your message...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final text = ctrl.text.trim();
                      if (text.isEmpty) return;
                      setState(() => submitting = true);
                      try {
                        await onSubmit(text);
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                      } catch (e) {
                        setState(() => submitting = false);
                        if (dialogContext.mounted) AppSnackbar.error(dialogContext, friendlyErrorMessage(e));
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> showDiscussionReportDialog(
  BuildContext context, {
  required Future<void> Function(String description) onSubmit,
}) async {
  final ctrl = TextEditingController();
  var submitting = false;
  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final count = wordCount(ctrl.text);
        final overLimit = count > 250;
        return AlertDialog(
          title: const Text('Report content'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                maxLines: 5,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Describe why you are reporting this (max 250 words)...'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              Text(
                '$count / 250 words',
                style: TextStyle(fontSize: 11, color: overLimit ? AppColors.danger : Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: (submitting || overLimit || ctrl.text.trim().isEmpty)
                  ? null
                  : () async {
                      setState(() => submitting = true);
                      try {
                        await onSubmit(ctrl.text.trim());
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                      } catch (e) {
                        setState(() => submitting = false);
                        if (dialogContext.mounted) AppSnackbar.error(dialogContext, friendlyErrorMessage(e));
                      }
                    },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    ),
  );
}

void showReactionsSheet(BuildContext context, Future<List<Map<String, dynamic>>> Function() loader) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReactionsSheet(loader: loader),
  );
}

class ReactionsSheet extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> Function() loader;

  const ReactionsSheet({super.key, required this.loader});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const Text('Reactions', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Flexible(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: loader(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('${snapshot.error}', style: TextStyle(color: scheme.error))),
                  );
                }
                final reactions = snapshot.data ?? [];
                if (reactions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No reactions yet.', style: TextStyle(color: scheme.onSurfaceVariant))),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: reactions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = reactions[i];
                    final isLike = '${r['type']}' == 'like';
                    final photo = '${r['photo'] ?? ''}';
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        backgroundImage: photo.isNotEmpty ? NetworkImage(ApiConfig.photoUrl(photo)) : null,
                        child: photo.isEmpty ? const Icon(Icons.person, color: AppColors.primary, size: 16) : null,
                      ),
                      title: Text('${r['name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: Icon(
                        isLike ? Icons.thumb_up : Icons.thumb_down,
                        size: 16,
                        color: isLike ? AppColors.primary : AppColors.danger,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        ),
      ),
    );
  }
}

Map<String, dynamic> cloneReply(Map<String, dynamic> r) => {
      ...Map<String, dynamic>.from(r),
      'replies': List<Map<String, dynamic>>.from(
          (r['replies'] as List? ?? []).map((x) => cloneReply(Map<String, dynamic>.from(x)))),
    };

Map<String, dynamic> cloneComment(Map<String, dynamic> c) => {
      ...Map<String, dynamic>.from(c),
      'replies': List<Map<String, dynamic>>.from(
          (c['replies'] as List? ?? []).map((r) => cloneReply(Map<String, dynamic>.from(r)))),
    };

Map<String, dynamic> clonePost(Map<String, dynamic> p) => {
      ...Map<String, dynamic>.from(p),
      'photos': List<Map<String, dynamic>>.from(
          (p['photos'] as List? ?? []).map((x) => Map<String, dynamic>.from(x))),
      'comments': List<Map<String, dynamic>>.from(
          (p['comments'] as List? ?? []).map((c) => cloneComment(Map<String, dynamic>.from(c)))),
    };

class ImageViewerScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const ImageViewerScreen({super.key, required this.urls, required this.initialIndex});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pageCtrl = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_index + 1} / ${widget.urls.length}'),
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          child: Center(
            child: Image.network(
              widget.urls[i],
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stack) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
