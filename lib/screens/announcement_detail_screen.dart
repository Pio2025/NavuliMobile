import 'package:flutter/material.dart';

import '../utils/time_ago.dart';

class _PriorityStyle {
  final Color color;
  final Color bg;
  const _PriorityStyle(this.color, this.bg);
}

const _priorityStyles = {
  'Critical': _PriorityStyle(Color(0xFFF1416C), Color(0xFFFFF5F8)),
  'Important': _PriorityStyle(Color(0xFFFF9500), Color(0xFFFFF8DD)),
  'Info': _PriorityStyle(Color(0xFF009EF7), Color(0xFFF1FAFF)),
};

class AnnouncementDetailScreen extends StatelessWidget {
  final Map<String, dynamic> announcement;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AnnouncementDetailScreen({
    super.key,
    required this.announcement,
    this.canEdit = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final priority = '${announcement['priority'] ?? 'Info'}';
    final style = _priorityStyles[priority] ?? _priorityStyles['Info']!;
    final postedBy = '${announcement['postedBy'] ?? ''}'.trim();
    final showMenu = canEdit || canDelete;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement'),
        actions: [
          if (showMenu)
            PopupMenuButton<String>(
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
                  Icon(Icons.campaign_outlined, size: 20, color: style.color),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: style.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      priority,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${announcement['title'] ?? ''}',
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
                      postedBy.isEmpty ? 'School Admin' : postedBy,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    timeAgo(announcement['createdAt']),
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text(
                '${announcement['content'] ?? ''}',
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
