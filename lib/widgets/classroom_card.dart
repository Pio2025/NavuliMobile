import 'package:flutter/material.dart';

class _StatusStyle {
  final Color color;
  final Color bg;
  const _StatusStyle(this.color, this.bg);
}

const _classroomStatusStyles = {
  'Active': _StatusStyle(Color(0xFF50CD89), Color(0xFFEEFAF4)),
  'Inactive': _StatusStyle(Color(0xFFFFC700), Color(0xFFFFF8DD)),
  'Archived': _StatusStyle(Color(0xFF9A9AB2), Color(0xFFF5F5FA)),
};

class ClassroomCard extends StatelessWidget {
  final Map<String, dynamic> classroom;
  final VoidCallback? onTap;
  final bool dense;

  const ClassroomCard({
    super.key,
    required this.classroom,
    this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = '${classroom['status'] ?? 'Active'}';
    final style = _classroomStatusStyles[status] ?? _classroomStatusStyles['Active']!;
    final name = '${classroom['name'] ?? ''}';
    final year = '${classroom['year'] ?? ''}';
    final streamName = classroom['streamName'] as String?;
    final schoolName = classroom['schoolName'] as String?;
    final classTeacher = classroom['classTeacher'] as String?;
    final studentCount = classroom['studentCount'] ?? 0;
    final childName = classroom['childName'] as String?;

    final subtitleParts = <String>[
      if (streamName != null && streamName.isNotEmpty) streamName,
      if (schoolName != null && schoolName.isNotEmpty) schoolName,
    ];

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: style.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: style.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  year,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                if (subtitleParts.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitleParts.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
                if (childName != null && childName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.child_care, size: 13, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          childName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
                if (!dense) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.groups_outlined, size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '$studentCount students',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                      if (classTeacher != null && classTeacher.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.person_outline, size: 15, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            classTeacher,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
