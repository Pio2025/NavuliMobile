import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/time_ago.dart';

class _PriorityStyle {
  final Color color;
  final Color bg;
  const _PriorityStyle(this.color, this.bg);
}

const _priorityStyles = {
  'Urgent': _PriorityStyle(Color(0xFFF1416C), Color(0xFFFFF5F8)),
  'Important': _PriorityStyle(Color(0xFFFFC700), Color(0xFFFFF8DD)),
  'Normal': _PriorityStyle(Color(0xFF009EF7), Color(0xFFF1FAFF)),
};

/// Returns null if the sheet should just close with no action, otherwise
/// one of: 'edit', 'pin', 'delete'.
class NoticeDetailScreen extends StatelessWidget {
  final Map<String, dynamic> notice;
  final bool canEdit;
  final bool canPin;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onTogglePin;
  final VoidCallback? onDelete;

  const NoticeDetailScreen({
    super.key,
    required this.notice,
    this.canEdit = false,
    this.canPin = false,
    this.canDelete = false,
    this.onEdit,
    this.onTogglePin,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pinned = notice['isPinned'] == true || notice['isPinned'] == 1;
    final priority = '${notice['priority'] ?? 'Normal'}';
    final style = _priorityStyles[priority] ?? _priorityStyles['Normal']!;
    final postedBy = '${notice['postedBy'] ?? ''}'.trim();
    final audience = '${notice['audience'] ?? 'All'}';
    final showMenu = canEdit || canPin || canDelete;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice'),
        actions: [
          if (showMenu)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit?.call();
                    break;
                  case 'pin':
                    onTogglePin?.call();
                    break;
                  case 'delete':
                    onDelete?.call();
                    break;
                }
              },
              itemBuilder: (context) => [
                if (canEdit)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ]),
                  ),
                if (canPin)
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(children: [
                      Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined,
                          size: 18),
                      const SizedBox(width: 8),
                      Text(pinned ? 'Unpin' : 'Pin'),
                    ]),
                  ),
                if (canDelete)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 18, color: Color(0xFFF1416C)),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Color(0xFFF1416C))),
                    ]),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: style.bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      priority,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: style.color,
                      ),
                    ),
                  ),
                  if (pinned) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('PINNED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              )),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${notice['title'] ?? ''}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: style.color.withValues(alpha: 0.15),
                    child: Text(
                      postedBy.isNotEmpty ? postedBy[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: style.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      postedBy.isEmpty ? 'Staff' : postedBy,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    timeAgo(notice['createdAt']),
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Audience: $audience',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const Divider(height: 32),
              Text(
                '${notice['content'] ?? ''}',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
