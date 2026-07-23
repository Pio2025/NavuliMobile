import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/lesson_detail_content.dart';

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
  final int? childId;

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
    this.childId,
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

  Widget _lessonBlock(BuildContext context, Map<String, dynamic> l, bool showDivider) {
    final lessonId = (l['lessonId'] as num?)?.toInt();
    if (lessonId == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: showDivider ? 20 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LessonDetailContent(lessonId: lessonId, classroomName: classroomName, childId: childId),
          if (showDivider) const Padding(padding: EdgeInsets.only(top: 20), child: Divider(height: 1)),
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
      children: [
        for (int i = 0; i < lessons.length; i++) _lessonBlock(context, lessons[i], i < lessons.length - 1),
      ],
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
