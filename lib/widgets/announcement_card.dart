import 'package:flutter/material.dart';

import '../utils/time_ago.dart';

class _PriorityStyle {
  final Color color;
  final Color bg;
  const _PriorityStyle(this.color, this.bg);
}

const _announcementPriorityStyles = {
  'Critical': _PriorityStyle(Color(0xFFF1416C), Color(0xFFFFF5F8)),
  'Important': _PriorityStyle(Color(0xFFFF9500), Color(0xFFFFF8DD)),
  'Info': _PriorityStyle(Color(0xFF009EF7), Color(0xFFF1FAFF)),
};

class AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> announcement;
  final VoidCallback? onTap;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool compact;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.onTap,
    this.canEdit = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final priority = '${announcement['priority'] ?? 'Info'}';
    final style = _announcementPriorityStyles[priority] ??
        _announcementPriorityStyles['Info']!;
    final postedBy = '${announcement['postedBy'] ?? ''}'.trim();
    final initial = postedBy.isNotEmpty ? postedBy[0].toUpperCase() : '?';
    final showMenu = canEdit || canDelete;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ?? scheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                decoration: BoxDecoration(
                  color: style.bg,
                  border: Border(
                    bottom: BorderSide(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.campaign_outlined, size: 18, color: style.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${announcement['title'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: style.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        priority,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
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
                            if (canDelete)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete_outline,
                                      size: 18, color: Color(0xFFF1416C)),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Color(0xFFF1416C))),
                                ]),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${announcement['content'] ?? ''}',
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
                            postedBy.isEmpty ? 'School Admin' : postedBy,
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
                          timeAgo(announcement['createdAt']),
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
            ],
          ),
        ),
      ),
    );
  }
}
