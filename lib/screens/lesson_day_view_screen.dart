import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdayNames = {1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday'};

String _formatFullDate(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return isoDate;
  final weekday = _weekdayNames[d.weekday] ?? '';
  return '$weekday, ${_monthNames[d.month - 1]} ${d.day}';
}

class LessonDayViewScreen extends StatelessWidget {
  final Map<String, dynamic> subject;
  final String? classroomName;
  final String date;
  final int weekNum;
  final String termLabel;
  final bool isHoliday;
  final String? holidayName;
  final List<Map<String, dynamic>> lessons;

  const LessonDayViewScreen({
    super.key,
    required this.subject,
    required this.classroomName,
    required this.date,
    required this.weekNum,
    required this.termLabel,
    required this.isHoliday,
    required this.holidayName,
    required this.lessons,
  });

  Widget _banner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subjectName = '${subject['subject_name'] ?? 'Subject'}';
    final parts = [if ((classroomName ?? '').isNotEmpty) classroomName!, subjectName, '$termLabel · Week $weekNum'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parts.join(' · '),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            _formatFullDate(date),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _countChip(BuildContext context, IconData icon, int count, String label) {
    if (count == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text('$count $label', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _lessonTile(BuildContext context, Map<String, dynamic> l) {
    final scheme = Theme.of(context).colorScheme;
    final fileCount = (l['fileCount'] as num?)?.toInt() ?? 0;
    final videoCount = (l['videoCount'] as num?)?.toInt() ?? 0;
    final linkCount = (l['linkCount'] as num?)?.toInt() ?? 0;
    final assessmentCount = (l['assessmentCount'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${l['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          if ((l['desc'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${l['desc']}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 8),
          Wrap(
            children: [
              _countChip(context, Icons.attach_file, fileCount, 'file${fileCount == 1 ? '' : 's'}'),
              _countChip(context, Icons.videocam_outlined, videoCount, 'video${videoCount == 1 ? '' : 's'}'),
              _countChip(context, Icons.link, linkCount, 'link${linkCount == 1 ? '' : 's'}'),
              _countChip(context, Icons.quiz_outlined, assessmentCount, 'assessment${assessmentCount == 1 ? '' : 's'}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (isHoliday) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.beach_access_outlined, size: 48, color: AppColors.warning),
          const SizedBox(height: 12),
          Center(
            child: Text(
              (holidayName != null && holidayName!.isNotEmpty) ? holidayName! : 'Public Holiday',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    if (lessons.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 100),
          Center(child: Text('No lessons for this day.', style: TextStyle(color: scheme.onSurfaceVariant))),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [for (final l in lessons) _lessonTile(context, l)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _banner(context),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }
}
