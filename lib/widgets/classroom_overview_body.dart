import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../utils/time_ago.dart';

/// Shared classroom overview card used by both the read-only "Classroom
/// Listing" detail screen and the richer "My Classroom" / "My Child
/// Classroom" detail screen — the two screens differ only in their
/// AppBar icons/navigation, not in this body content.
class ClassroomOverviewBody extends StatelessWidget {
  final Map<String, dynamic> classroom;
  final Map<String, dynamic> staff;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ClassroomOverviewBody({
    super.key,
    required this.classroom,
    required this.staff,
    this.canEdit = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
  });

  Widget _statTile(BuildContext context, IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _staffRoleTile(BuildContext context, String role, String label) {
    final scheme = Theme.of(context).colorScheme;
    final entry = staff[role] is Map ? Map<String, dynamic>.from(staff[role]) : null;
    final name = entry != null ? '${entry['name'] ?? ''}' : '';
    final photo = entry != null ? '${entry['photo'] ?? ''}' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: photo.isNotEmpty ? NetworkImage(ApiConfig.photoUrl(photo)) : null,
            child: photo.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                Text(
                  name.isNotEmpty ? name : 'Not assigned',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: name.isNotEmpty ? null : scheme.onSurfaceVariant,
                  ),
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
    final c = classroom;
    final scheme = Theme.of(context).colorScheme;
    final schoolLogo = '${c['schoolLogo'] ?? ''}';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${c['name'] ?? ''}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${c['status'] ?? ''}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              if (canEdit || canDelete)
                PopupMenuButton<String>(
                  icon: Icon(Icons.arrow_drop_down_circle_outlined, color: scheme.onSurfaceVariant),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (canEdit)
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (canDelete)
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Color(0xFFF1416C)),
                          title: Text('Delete', style: TextStyle(color: Color(0xFFF1416C))),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: schoolLogo.isNotEmpty
                      ? Image.network(
                          ApiConfig.schoolLogoUrl(schoolLogo),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Image.asset(
                            'assets/images/icon.png',
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/icon.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${c['schoolName'] ?? ''}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(height: 1.2, width: 40, color: AppColors.primary.withValues(alpha: 0.4)),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                    Container(height: 1.2, width: 40, color: AppColors.primary.withValues(alpha: 0.4)),
                  ],
                ),
              ],
            ),
          ),
          if (staff.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _staffRoleTile(context, 'Class Teacher', 'Class Teacher'),
            _staffRoleTile(context, 'Assistant Class Teacher', 'Assistant Class Teacher'),
            _staffRoleTile(context, 'Class Captain', 'Class Captain'),
            _staffRoleTile(context, 'Assistant Class Captain', 'Assistant Class Captain'),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statTile(context, Icons.calendar_today_outlined, 'Year', '${c['year'] ?? ''}'),
              _statTile(context, Icons.stream_outlined, 'Stream', '${c['streamName'] ?? '—'}'),
              _statTile(context, Icons.layers_outlined, 'Level', '${c['levelName'] ?? '—'}'),
              _statTile(context, Icons.menu_book_outlined, 'Subjects', '${c['subjectCount'] ?? 0}'),
              _statTile(context, Icons.groups_outlined, 'Students', '${c['studentCount'] ?? 0}'),
              _statTile(context, Icons.play_lesson_outlined, 'Lessons', '${c['lessonCount'] ?? 0}'),
            ],
          ),
          if ((c['createdAt'] ?? '').toString().isNotEmpty ||
              (c['updatedAt'] ?? '').toString().isNotEmpty) ...[
            const Divider(height: 28),
            if ((c['createdAt'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  'Created by ${c['createdBy'] ?? ''} · ${timeAgo(c['createdAt'])}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            if ((c['updatedAt'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  'Updated by ${c['updatedBy'] ?? ''} · ${timeAgo(c['updatedAt'])}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
