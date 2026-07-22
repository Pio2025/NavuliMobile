import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';

class SubjectDetailScreen extends StatelessWidget {
  final Map<String, dynamic> subject;

  const SubjectDetailScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final teacherName = subject['teacher_name'] as String?;
    final photo = subject['teacher_photo'] as String?;
    return Scaffold(
      appBar: AppBar(title: Text('${subject['subject_name'] ?? 'Subject'}')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? scheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: (photo != null && photo.isNotEmpty)
                        ? NetworkImage(ApiConfig.photoUrl(photo))
                        : null,
                    child: (photo == null || photo.isEmpty)
                        ? const Icon(Icons.person, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${subject['subject_name'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          teacherName != null && teacherName.isNotEmpty
                              ? teacherName
                              : 'Not assigned',
                          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Lessons and assignments for this subject are coming soon.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
