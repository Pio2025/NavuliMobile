import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'lesson_day_view_screen.dart';

// ── shared navigation bits ─────────────────────────────────────────────────

enum _Section { dashboard, lessons, assignments, feedback }

num _asNum(dynamic v) => (v is num) ? v : (num.tryParse('$v') ?? 0);

int _classSubIdOf(Map<String, dynamic> subject) => _asNum(subject['class_sub_id']).toInt();

void _switchSection(BuildContext context, Map<String, dynamic> subject, _Section target, {String? classroomName}) {
  Widget screen;
  switch (target) {
    case _Section.dashboard:
      screen = SubjectDashboardScreen(subject: subject, classroomName: classroomName);
      break;
    case _Section.lessons:
      screen = SubjectLessonsScreen(subject: subject, classroomName: classroomName);
      break;
    case _Section.assignments:
      screen = SubjectAssignmentsScreen(subject: subject, classroomName: classroomName);
      break;
    case _Section.feedback:
      screen = SubjectFeedbackScreen(subject: subject, classroomName: classroomName);
      break;
  }
  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => screen));
}

String _sectionLabel(_Section s) {
  switch (s) {
    case _Section.dashboard:
      return 'Dashboard';
    case _Section.lessons:
      return 'Lessons';
    case _Section.assignments:
      return 'Assignments';
    case _Section.feedback:
      return 'Feedback';
  }
}

Widget _sectionBanner(
  BuildContext context, {
  required String? classroomName,
  required Map<String, dynamic> subject,
  required _Section section,
}) {
  final scheme = Theme.of(context).colorScheme;
  final subjectName = '${subject['subject_name'] ?? 'Subject'}';
  final parts = [if ((classroomName ?? '').isNotEmpty) classroomName!, subjectName];
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            parts.join(' · '),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
          child: Text(_sectionLabel(section),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
      ],
    ),
  );
}

List<Widget> _sectionActions(BuildContext context, Map<String, dynamic> subject, _Section current, {String? classroomName}) {
  final scheme = Theme.of(context).colorScheme;
  Widget action(_Section section, IconData icon, String tooltip) {
    final active = section == current;
    return IconButton(
      icon: Icon(icon, color: active ? AppColors.primary : scheme.onSurfaceVariant),
      tooltip: tooltip,
      onPressed: active ? null : () => _switchSection(context, subject, section, classroomName: classroomName),
    );
  }

  return [
    action(_Section.dashboard, Icons.dashboard_outlined, 'Dashboard'),
    action(_Section.lessons, Icons.menu_book_outlined, 'Lessons'),
    action(_Section.assignments, Icons.assignment_outlined, 'Assignments'),
    action(_Section.feedback, Icons.rate_review_outlined, 'Feedback'),
  ];
}

Color _scoreColor(num v) {
  if (v >= 70) return AppColors.success;
  if (v >= 50) return AppColors.warning;
  return AppColors.danger;
}

Widget _sectionCard(BuildContext context, {required String title, required Widget child}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color ?? scheme.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

Widget _emptyHint(BuildContext context, String text) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.insights_outlined, size: 28, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    ),
  );
}

// ── DASHBOARD ────────────────────────────────────────────────────────────

class SubjectDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final String? classroomName;
  const SubjectDashboardScreen({super.key, required this.subject, this.classroomName});

  @override
  State<SubjectDashboardScreen> createState() => _SubjectDashboardScreenState();
}

class _SubjectDashboardScreenState extends State<SubjectDashboardScreen> {
  late ApiClient _client;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};

  int get _classSubId => _classSubIdOf(widget.subject);

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await _client.getSubjectDashboard(_classSubId);
      setState(() {
        _stats = Map<String, dynamic>.from(body['stats'] ?? {});
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, height: 1.15, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _scoreDistChart(List<dynamic> dist) {
    const labels = ['0-19%', '20-39%', '40-59%', '60-79%', '80-100%'];
    final values = List.generate(5, (i) => _asNum(i < dist.length ? dist[i] : 0).toDouble());
    final maxY = (values.fold<double>(0, (a, b) => a > b ? a : b) * 1.25).clamp(4.0, double.infinity);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[i], style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(toY: values[i], color: AppColors.primary, width: 20, borderRadius: BorderRadius.circular(4)),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _lessonsByTermChart(Map<String, dynamic> byTerm) {
    const colors = [AppColors.primary, AppColors.secondary, AppColors.warning];
    final values = [1, 2, 3].map((t) => _asNum(byTerm['$t'] ?? 0).toDouble()).toList();
    final total = values.fold<double>(0, (a, b) => a + b);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          height: 140,
          width: 140,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (var i = 0; i < values.length; i++)
                  PieChartSectionData(
                    value: values[i] <= 0 ? 0.0001 : values[i],
                    color: colors[i],
                    title: values[i] > 0 ? '${values[i].toInt()}' : '',
                    radius: 30,
                    titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('Term ${i + 1}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      const Spacer(),
                      Text('${values[i].toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              if (total <= 0) const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }

  ({String label, Color color, IconData icon}) _typeCfg(String type) {
    switch (type) {
      case 'drag_drop':
        return (label: 'Drag & Drop', color: AppColors.secondary, icon: Icons.drag_indicator_outlined);
      case 'labelling':
        return (label: 'Labelling', color: AppColors.warning, icon: Icons.label_outline);
      default:
        return (label: 'Quiz', color: AppColors.primary, icon: Icons.quiz_outlined);
    }
  }

  Widget _assessmentTable(List<Map<String, dynamic>> list) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final a in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_typeCfg('${a['type'] ?? ''}').icon, size: 15, color: _typeCfg('${a['type'] ?? ''}').color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${a['name'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(_typeCfg('${a['type'] ?? ''}').label,
                        style: TextStyle(fontSize: 11, color: _typeCfg('${a['type'] ?? ''}').color)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${a['attempt_count'] ?? 0} submissions',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    const SizedBox(width: 10),
                    if (a['avg_score'] != null)
                      Text('Avg ${a['avg_score']}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _scoreColor(_asNum(a['avg_score'])))),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_asNum(a['participation']).toDouble() / 100).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: _asNum(a['participation']) >= 70
                        ? AppColors.success
                        : (_asNum(a['participation']) >= 40 ? AppColors.warning : AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _topPerformers(List<Map<String, dynamic>> list) {
    const medals = ['🥇', '🥈', '🥉'];
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(i < 3 ? medals[i] : '${i + 1}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Text('${list[i]['student_name'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Text('${list[i]['attempts'] ?? 0} attempts',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _scoreColor(_asNum(list[i]['avg_sc'])).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${list[i]['avg_sc'] ?? 0}%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _scoreColor(_asNum(list[i]['avg_sc'])))),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _recentSubmissions(List<Map<String, dynamic>> list) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final r in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    ('${r['sname'] ?? ''}').isNotEmpty ? '${r['sname']}'[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['sname'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${r['aname'] ?? ''} · ${r['submitted_at'] ?? ''}',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text('${r['score'] ?? 0}%',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _scoreColor(_asNum(r['score'])))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Failed to load dashboard: $_error'));

    final avgScore = _stats['avg_score'];
    final needAttention = _asNum(_stats['need_attention']);
    final scoreDist = List<dynamic>.from(_stats['score_dist'] ?? [0, 0, 0, 0, 0]);
    final lessonByTermRaw = _stats['lesson_by_term'];
    final lessonByTerm = lessonByTermRaw is Map ? Map<String, dynamic>.from(lessonByTermRaw) : <String, dynamic>{};
    final assessments = List<Map<String, dynamic>>.from(_stats['assessment_list'] ?? []);
    final topStudents = List<Map<String, dynamic>>.from(_stats['top_students'] ?? []);
    final recent = List<Map<String, dynamic>>.from(_stats['recent_attempts'] ?? []);
    final scoreDistHasData = scoreDist.any((v) => _asNum(v) > 0);
    final lessonByTermHasData = lessonByTerm.values.any((v) => _asNum(v) > 0);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 112,
            ),
            children: [
              _statTile('Students Enrolled', '${_asNum(_stats['students']).toInt()}', Icons.groups_outlined, AppColors.primary),
              _statTile('Published Lessons', '${_asNum(_stats['lessons']).toInt()}', Icons.menu_book_outlined, AppColors.primary),
              _statTile('Published Assessments', '${_asNum(_stats['assessments']).toInt()}', Icons.quiz_outlined, AppColors.primary),
              _statTile('Total Submissions', '${_asNum(_stats['total_attempts']).toInt()}', Icons.fact_check_outlined, AppColors.primary),
              _statTile('Avg. Assessment Score', avgScore != null ? '$avgScore%' : '—', Icons.grade_outlined,
                  avgScore != null ? _scoreColor(_asNum(avgScore)) : AppColors.primary),
              _statTile('No Attempts Yet', '${needAttention.toInt()}', Icons.report_gmailerrorred_outlined,
                  needAttention > 0 ? AppColors.warning : AppColors.success),
            ],
          ),
          const SizedBox(height: 16),
          _sectionCard(context,
              title: 'Score Distribution',
              child: scoreDistHasData ? _scoreDistChart(scoreDist) : _emptyHint(context, 'No assessment attempts yet.')),
          const SizedBox(height: 16),
          _sectionCard(context,
              title: 'Lessons by Term',
              child: lessonByTermHasData ? _lessonsByTermChart(lessonByTerm) : _emptyHint(context, 'No published lessons yet.')),
          if (assessments.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionCard(context, title: 'Assessment Performance', child: _assessmentTable(assessments)),
          ],
          if (topStudents.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionCard(context, title: 'Top Performers', child: _topPerformers(topStudents)),
          ],
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionCard(context, title: 'Recent Submissions', child: _recentSubmissions(recent)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: _sectionActions(context, widget.subject, _Section.dashboard, classroomName: widget.classroomName),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _sectionBanner(context, classroomName: widget.classroomName, subject: widget.subject, section: _Section.dashboard),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}

// ── LESSONS ──────────────────────────────────────────────────────────────

const _monthAbbr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdayInitial = {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F'};

String _formatCardDate(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return isoDate;
  return '${_monthAbbr[d.month - 1]} ${d.day}';
}

class SubjectLessonsScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final String? classroomName;
  const SubjectLessonsScreen({super.key, required this.subject, this.classroomName});

  @override
  State<SubjectLessonsScreen> createState() => _SubjectLessonsScreenState();
}

class _SubjectLessonsScreenState extends State<SubjectLessonsScreen> {
  late ApiClient _client;
  bool _loading = true;
  String? _error;
  String _termLabel = 'Term';
  List<Map<String, dynamic>> _terms = [];
  int _selectedTerm = 0;
  List<Map<String, dynamic>> _weeks = [];

  int get _classSubId => _classSubIdOf(widget.subject);

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    _load();
  }

  Future<void> _load({int? term}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await _client.getSubjectLessonsCalendar(_classSubId, term: term);
      setState(() {
        _termLabel = '${body['termLabel'] ?? 'Term'}';
        _terms = List<Map<String, dynamic>>.from(body['terms'] ?? []);
        _selectedTerm = _asNum(body['selectedTerm']).toInt();
        _weeks = List<Map<String, dynamic>>.from(body['weeks'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _openDay(Map<String, dynamic> day, int weekNum) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonDayViewScreen(
          subject: widget.subject,
          classroomName: widget.classroomName,
          date: '${day['date'] ?? ''}',
          weekNum: weekNum,
          termLabel: '$_termLabel $_selectedTerm',
          isHoliday: day['isHoliday'] == true,
          holidayName: day['holidayName'] as String?,
          lessons: List<Map<String, dynamic>>.from(day['lessons'] ?? []),
        ),
      ),
    );
  }

  Widget _termTabs() {
    if (_terms.length <= 1) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _terms.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = _terms[i];
          final num = _asNum(t['termNum']).toInt();
          final active = num == _selectedTerm;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: active ? null : () => _load(term: num),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text('$_termLabel $num',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : scheme.onSurfaceVariant,
                  )),
            ),
          );
        },
      ),
    );
  }

  Widget _miniStat(IconData icon, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 2),
        Text('$count', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _dayCard(Map<String, dynamic> day, int weekNum) {
    final scheme = Theme.of(context).colorScheme;
    final date = '${day['date'] ?? ''}';
    final dt = DateTime.tryParse(date);
    final dayInitial = dt != null ? (_weekdayInitial[dt.weekday] ?? '') : '';
    final isHoliday = day['isHoliday'] == true;
    final holidayName = day['holidayName'] as String?;
    final lessonCount = _asNum(day['lessonCount']).toInt();
    final fileCount = _asNum(day['fileCount']).toInt();
    final videoCount = _asNum(day['videoCount']).toInt();
    final linkCount = _asNum(day['linkCount']).toInt();
    final assessmentCount = _asNum(day['assessmentCount']).toInt();
    final now = DateTime.now();
    final isToday = dt != null && now.year == dt.year && now.month == dt.month && now.day == dt.day;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openDay(day, weekNum),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isHoliday
              ? AppColors.warning.withValues(alpha: 0.10)
              : (Theme.of(context).cardTheme.color ?? scheme.surface),
          borderRadius: BorderRadius.circular(10),
          border: isToday ? Border.all(color: AppColors.primary, width: 1.4) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dayInitial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                Text(_formatCardDate(date), style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 4),
            if (isHoliday)
              Text(
                (holidayName != null && holidayName.isNotEmpty) ? holidayName : 'Holiday',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 8.5, color: AppColors.warning, fontWeight: FontWeight.w600),
              )
            else if (lessonCount == 0)
              Text('—', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant))
            else ...[
              Text('$lessonCount lesson${lessonCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary)),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniStat(Icons.attach_file, fileCount, scheme.onSurfaceVariant),
                  _miniStat(Icons.videocam_outlined, videoCount, scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniStat(Icons.link, linkCount, scheme.onSurfaceVariant),
                  _miniStat(Icons.quiz_outlined, assessmentCount, scheme.onSurfaceVariant),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _weekRow(Map<String, dynamic> week) {
    final weekNum = _asNum(week['weekNum']).toInt();
    final days = List<Map<String, dynamic>>.from(week['days'] ?? []);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Week $weekNum', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(child: _dayCard(days[i], weekNum)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Failed to load lessons: $_error'));
    if (_terms.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(term: _selectedTerm == 0 ? null : _selectedTerm),
        child: ListView(children: const [
          SizedBox(height: 100),
          Center(child: Text('Term schedule not configured for this school yet.')),
        ]),
      );
    }
    return Column(
      children: [
        _termTabs(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(term: _selectedTerm),
            child: _weeks.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 100),
                    Center(child: Text('No weeks configured for this term.')),
                  ])
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [for (final w in _weeks) _weekRow(w)],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: _sectionActions(context, widget.subject, _Section.lessons, classroomName: widget.classroomName),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _sectionBanner(context, classroomName: widget.classroomName, subject: widget.subject, section: _Section.lessons),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}

// ── ASSIGNMENTS ──────────────────────────────────────────────────────────

class SubjectAssignmentsScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final String? classroomName;
  const SubjectAssignmentsScreen({super.key, required this.subject, this.classroomName});

  @override
  State<SubjectAssignmentsScreen> createState() => _SubjectAssignmentsScreenState();
}

class _SubjectAssignmentsScreenState extends State<SubjectAssignmentsScreen> {
  late ApiClient _client;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _body = {};

  int get _classSubId => _classSubIdOf(widget.subject);

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await _client.getSubjectAssignments(_classSubId);
      setState(() {
        _body = body;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'Graded':
        color = AppColors.success;
        break;
      case 'Late':
        color = AppColors.warning;
        break;
      case 'Submitted':
        color = AppColors.primary;
        break;
      default:
        color = AppColors.danger;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(status.isEmpty ? 'Not submitted' : status,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _assignmentTile(Map<String, dynamic> a) {
    final scheme = Theme.of(context).colorScheme;
    final status = '${a['submission_status'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${a['assignment_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Due ${a['assignment_due_date'] ?? '—'} · ${a['assignment_total_score'] ?? 100} pts',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (a.containsKey('submission_id')) _statusBadge(status),
            if (a.containsKey('submitted_count'))
              Text('${a['submitted_count'] ?? 0} submitted', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _list(List<dynamic> assignments) {
    final items = List<Map<String, dynamic>>.from(assignments);
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text('No assignments published yet.')),
      );
    }
    return Column(children: [for (final a in items) _assignmentTile(a)]);
  }

  Widget _childrenSection(List<dynamic> children) {
    if (children.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text('No linked children in this classroom.')),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in List<Map<String, dynamic>>.from(children)) ...[
          Text('${child['childName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          _list(List<dynamic>.from(child['assignments'] ?? [])),
          const SizedBox(height: 22),
        ],
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Failed to load assignments: $_error'));
    final mode = '${_body['mode'] ?? ''}';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (mode == 'children')
            _childrenSection(List<dynamic>.from(_body['children'] ?? []))
          else
            _list(List<dynamic>.from(_body['assignments'] ?? [])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: _sectionActions(context, widget.subject, _Section.assignments, classroomName: widget.classroomName),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _sectionBanner(context, classroomName: widget.classroomName, subject: widget.subject, section: _Section.assignments),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}

// ── FEEDBACK ─────────────────────────────────────────────────────────────

class SubjectFeedbackScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final String? classroomName;
  const SubjectFeedbackScreen({super.key, required this.subject, this.classroomName});

  @override
  State<SubjectFeedbackScreen> createState() => _SubjectFeedbackScreenState();
}

class _SubjectFeedbackScreenState extends State<SubjectFeedbackScreen> {
  late ApiClient _client;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic> _body = {};

  int _overall = 0;
  int _teaching = 0;
  int _content = 0;
  int _engagement = 0;
  final _commentCtrl = TextEditingController();
  bool _anonymous = false;

  int get _classSubId => _classSubIdOf(widget.subject);

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await _client.getSubjectFeedback(_classSubId);
      final existing = body['feedback'] is Map ? Map<String, dynamic>.from(body['feedback']) : null;
      setState(() {
        _body = body;
        if (existing != null) {
          _overall = _asNum(existing['overall_rating']).toInt();
          _teaching = _asNum(existing['teaching_rating']).toInt();
          _content = _asNum(existing['content_rating']).toInt();
          _engagement = _asNum(existing['engagement_rating']).toInt();
          _commentCtrl.text = '${existing['comment'] ?? ''}';
          _anonymous = existing['is_anonymous'] == 1 || existing['is_anonymous'] == true;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_overall < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give an overall rating.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await _client.submitSubjectFeedback(
        _classSubId,
        overallRating: _overall,
        teachingRating: _teaching,
        contentRating: _content,
        engagementRating: _engagement,
        comment: _commentCtrl.text.trim(),
        isAnonymous: _anonymous,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _starRow(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12))),
        for (var i = 1; i <= 5; i++)
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            icon: Icon(i <= value ? Icons.star : Icons.star_border, color: AppColors.warning, size: 20),
            onPressed: () => onChanged(i),
          ),
      ],
    );
  }

  Widget _readOnlyStars(String label, int value) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))),
        for (var i = 1; i <= 5; i++)
          Icon(i <= value ? Icons.star : Icons.star_border, color: AppColors.warning, size: 16),
      ],
    );
  }

  Widget _selfForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rate this subject', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 12),
        _starRow('Overall', _overall, (v) => setState(() => _overall = v)),
        _starRow('Teaching', _teaching, (v) => setState(() => _teaching = v)),
        _starRow('Content', _content, (v) => setState(() => _content = v)),
        _starRow('Engagement', _engagement, (v) => setState(() => _engagement = v)),
        const SizedBox(height: 10),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add a comment (optional)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(value: _anonymous, onChanged: (v) => setState(() => _anonymous = v ?? false)),
            const Text('Submit anonymously', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit'),
          ),
        ),
      ],
    );
  }

  Widget _readOnlyCard(Map<String, dynamic>? feedback, {String? title}) {
    final scheme = Theme.of(context).colorScheme;
    if (feedback == null) {
      return _sectionCard(context,
          title: title ?? 'Feedback',
          child: _emptyHint(context, 'No feedback submitted yet.'));
    }
    return _sectionCard(context,
        title: title ?? 'Feedback',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _readOnlyStars('Overall', _asNum(feedback['overall_rating']).toInt()),
            const SizedBox(height: 4),
            _readOnlyStars('Teaching', _asNum(feedback['teaching_rating']).toInt()),
            const SizedBox(height: 4),
            _readOnlyStars('Content', _asNum(feedback['content_rating']).toInt()),
            const SizedBox(height: 4),
            _readOnlyStars('Engagement', _asNum(feedback['engagement_rating']).toInt()),
            if ((feedback['comment'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('"${feedback['comment']}"', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant)),
            ],
          ],
        ));
  }

  Widget _summarySection(Map<String, dynamic> body) {
    final averages = Map<String, dynamic>.from(body['averages'] ?? {});
    final feedbacks = List<Map<String, dynamic>>.from(body['feedbacks'] ?? []);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _sectionCard(context,
            title: 'Class Averages',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${averages['total_responses'] ?? 0} responses',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                _readOnlyStars('Overall', _asNum(averages['avg_overall']).round()),
                const SizedBox(height: 4),
                _readOnlyStars('Teaching', _asNum(averages['avg_teaching']).round()),
                const SizedBox(height: 4),
                _readOnlyStars('Content', _asNum(averages['avg_content']).round()),
                const SizedBox(height: 4),
                _readOnlyStars('Engagement', _asNum(averages['avg_engagement']).round()),
              ],
            )),
        const SizedBox(height: 16),
        if (feedbacks.isNotEmpty)
          _sectionCard(context,
              title: 'Responses',
              child: Column(
                children: [
                  for (final f in feedbacks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${f['student_name'] ?? 'Anonymous'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 4),
                          _readOnlyStars('Overall', _asNum(f['overall_rating']).toInt()),
                          if ((f['comment'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('"${f['comment']}"', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant)),
                          ],
                        ],
                      ),
                    ),
                ],
              )),
      ],
    );
  }

  Widget _childrenSection(List<dynamic> children) {
    if (children.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text('No linked children in this classroom.')),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in List<Map<String, dynamic>>.from(children)) ...[
          Text('${child['childName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          _readOnlyCard(child['feedback'] is Map ? Map<String, dynamic>.from(child['feedback']) : null),
          const SizedBox(height: 22),
        ],
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Failed to load feedback: $_error'));
    final mode = '${_body['mode'] ?? ''}';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (mode == 'summary')
            _summarySection(_body)
          else if (mode == 'children')
            _childrenSection(List<dynamic>.from(_body['children'] ?? []))
          else
            _sectionCard(context, title: 'Your Feedback', child: _selfForm()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: _sectionActions(context, widget.subject, _Section.feedback, classroomName: widget.classroomName),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _sectionBanner(context, classroomName: widget.classroomName, subject: widget.subject, section: _Section.feedback),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}
