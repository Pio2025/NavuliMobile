import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/time_ago.dart';

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

class NoticeCard extends StatelessWidget {
  final Map<String, dynamic> notice;
  final VoidCallback? onTap;
  final bool canEdit;
  final bool canPin;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onTogglePin;
  final VoidCallback? onDelete;
  final bool compact;

  const NoticeCard({
    super.key,
    required this.notice,
    this.onTap,
    this.canEdit = false,
    this.canPin = false,
    this.canDelete = false,
    this.onEdit,
    this.onTogglePin,
    this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final pinned = notice['isPinned'] == true || notice['isPinned'] == 1;
    final scheme = Theme.of(context).colorScheme;
    final priority = '${notice['priority'] ?? 'Normal'}';
    final style = _noticePriorityStyles[priority] ??
        _noticePriorityStyles['Normal']!;
    final postedBy = '${notice['postedBy'] ?? ''}'.trim();
    final initial = postedBy.isNotEmpty ? postedBy[0].toUpperCase() : '?';
    final showMenu = canEdit || canPin || canDelete;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
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
                    padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${notice['title'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                            if (showMenu)
                              SizedBox(
                                width: 28,
                                height: 24,
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(Icons.keyboard_arrow_down,
                                      size: 20, color: scheme.onSurfaceVariant),
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
                                          Icon(
                                              pinned
                                                  ? Icons.push_pin
                                                  : Icons.push_pin_outlined,
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Text(pinned ? 'Unpin' : 'Pin'),
                                        ]),
                                      ),
                                    if (canDelete)
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(children: [
                                          Icon(Icons.delete_outline,
                                              size: 18, color: Color(0xFFF1416C)),
                                          SizedBox(width: 8),
                                          Text('Delete',
                                              style: TextStyle(
                                                  color: Color(0xFFF1416C))),
                                        ]),
                                      ),
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
                          maxLines: compact ? 1 : 2,
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
                              backgroundColor:
                                  style.color.withValues(alpha: 0.15),
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
        ),
      ),
    );
  }
}
