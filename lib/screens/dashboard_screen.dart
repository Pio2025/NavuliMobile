import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

/// Full dashboard — the detailed breakdown behind the Home screen's
/// condensed summary. Shows every numeric metric for the active role plus
/// bar charts for whichever chart-shaped data the backend provides (grade
/// distribution, attendance by classroom, monthly attendance trend, etc).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late ApiClient _client;
  late Future<Map<String, dynamic>> _future;
  int _selectedTab = -1; // -1 = "My Dashboard", else index into childStats

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    _future = _client.getDashboard();
  }

  Future<void> _refresh() async {
    setState(() => _future = _client.getDashboard());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('Failed to load dashboard: ${snapshot.error}')),
                ],
              );
            }

            final data = snapshot.data!;
            final childStats =
                (data['childStats'] as List<dynamic>? ?? [])
                    .cast<Map<String, dynamic>>();
            if (_selectedTab >= childStats.length) _selectedTab = -1;

            final stats = _selectedTab == -1
                ? (data['stats'] as Map<String, dynamic>? ?? {})
                : (childStats[_selectedTab]['stats'] as Map<String, dynamic>? ?? {});

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (childStats.isNotEmpty) ...[
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _tabChip(
                          label: 'My Dashboard',
                          selected: _selectedTab == -1,
                          onTap: () => setState(() => _selectedTab = -1),
                        ),
                        for (var i = 0; i < childStats.length; i++)
                          _tabChip(
                            label: '${childStats[i]['name'] ?? 'Child'}',
                            selected: _selectedTab == i,
                            onTap: () => setState(() => _selectedTab = i),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ..._buildFullStatsGrid(stats),
                const SizedBox(height: 12),
                ..._buildCharts(stats),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tabChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: Theme.of(context).cardTheme.color ?? scheme.surface,
        labelStyle: TextStyle(
          color: selected ? Colors.white : scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
      ),
    );
  }

  bool _isDisplayableStat(String key, dynamic value) {
    if (value is! num) return false;
    if (key == 'user_id' ||
        key.endsWith('_id') ||
        key.endsWith('_id_fk') ||
        key.endsWith('_fk')) {
      return false;
    }
    return true;
  }

  String _prettyLabel(String key) {
    final stripped = key.replaceFirst(RegExp(r'^(sa_|ad_|ts_|st_)'), '');
    final words = stripped.split('_').where((w) => w.isNotEmpty);
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  String _formatValue(String key, num value) {
    if (key.endsWith('_pct')) {
      final v = value.toDouble();
      return '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}%';
    }
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  IconData _iconFor(String key) {
    if (key.contains('school')) return Icons.school_outlined;
    if (key.contains('student')) return Icons.groups_outlined;
    if (key.contains('teacher')) return Icons.person_outline;
    if (key.contains('classroom')) return Icons.class_outlined;
    if (key.contains('attendance')) return Icons.event_available_outlined;
    if (key.contains('announcement')) return Icons.campaign_outlined;
    if (key.contains('notice')) return Icons.notifications_outlined;
    if (key.contains('conduct') || key.contains('incident')) {
      return Icons.gavel_outlined;
    }
    if (key.contains('rank')) return Icons.emoji_events_outlined;
    if (key.contains('mark') || key.contains('pct') || key.contains('overall')) {
      return Icons.grade_outlined;
    }
    if (key.contains('lesson')) return Icons.menu_book_outlined;
    if (key.contains('assignment')) return Icons.assignment_outlined;
    if (key.contains('user')) return Icons.people_outline;
    return Icons.insights_outlined;
  }

  List<Widget> _buildFullStatsGrid(Map<String, dynamic> stats) {
    final entries =
        stats.entries.where((e) => _isDisplayableStat(e.key, e.value)).toList();

    if (entries.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No dashboard metrics to display yet.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }

    return [
      GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 116,
        ),
        children: entries
            .map((e) => StatCard(
                  label: _prettyLabel(e.key),
                  value: _formatValue(e.key, e.value as num),
                  icon: _iconFor(e.key),
                ))
            .toList(),
      ),
    ];
  }

  List<Widget> _buildCharts(Map<String, dynamic> stats) {
    final charts = <Widget>[];

    final markBands = stats['ts_mark_bands'];
    if (markBands is Map) {
      const labels = {
        'absent': 'Absent',
        'below50': '<50',
        'f50': '50s',
        'f60': '60s',
        'f70': '70s',
        'f80': '80s',
        'f90': '90+',
      };
      final bars = labels.entries
          .map((e) => (
                label: e.value,
                value: ((markBands[e.key] ?? 0) as num).toDouble(),
              ))
          .toList();
      if (bars.any((b) => b.value > 0)) {
        charts.add(_BarChartCard(title: 'Grade Distribution', bars: bars));
      }
    }

    final teacherAttendance = stats['ts_attendance'];
    if (teacherAttendance is List && teacherAttendance.isNotEmpty) {
      final bars = teacherAttendance.cast<Map<String, dynamic>>().map((r) {
        return (
          label: '${r['class_name'] ?? ''}',
          value: ((r['pct'] ?? 0) as num).toDouble(),
        );
      }).toList();
      charts.add(_BarChartCard(
        title: 'Attendance Rate by Classroom',
        bars: bars,
        maxY: 100,
        valueSuffix: '%',
      ));
    }

    final monthlyAttendance = stats['st_attendance_monthly'];
    if (monthlyAttendance is List && monthlyAttendance.isNotEmpty) {
      final bars = monthlyAttendance.cast<Map<String, dynamic>>().map((r) {
        final present = ((r['present'] ?? 0) as num).toDouble();
        final total = ((r['total'] ?? 0) as num).toDouble();
        final pct = total > 0 ? (present / total) * 100 : 0.0;
        return (label: '${r['label'] ?? ''}', value: pct);
      }).toList();
      charts.add(_BarChartCard(
        title: 'Monthly Attendance',
        bars: bars,
        maxY: 100,
        valueSuffix: '%',
      ));
    }

    final subjectAttendance = stats['st_subject_attendance'];
    if (subjectAttendance is List && subjectAttendance.isNotEmpty) {
      final bars = subjectAttendance.cast<Map<String, dynamic>>().map((r) {
        final present = ((r['present'] ?? 0) as num).toDouble();
        final total = ((r['total'] ?? 0) as num).toDouble();
        final pct = total > 0 ? (present / total) * 100 : 0.0;
        return (label: '${r['subject_name'] ?? ''}', value: pct);
      }).toList();
      charts.add(_BarChartCard(
        title: 'Attendance by Subject',
        bars: bars,
        maxY: 100,
        valueSuffix: '%',
      ));
    }

    final usersByRole = stats['sa_users_by_role'];
    if (usersByRole is List && usersByRole.isNotEmpty) {
      final bars = usersByRole.cast<Map<String, dynamic>>().map((r) {
        return (
          label: '${r['role_cat_name'] ?? ''}',
          value: ((r['cnt'] ?? 0) as num).toDouble(),
        );
      }).toList();
      charts.add(_BarChartCard(title: 'Users by Role', bars: bars));
    }

    final classroomsList = stats['ad_classrooms_list'];
    if (classroomsList is List && classroomsList.isNotEmpty) {
      final bars = classroomsList.cast<Map<String, dynamic>>().map((r) {
        return (
          label: '${r['class_name'] ?? ''}',
          value: ((r['student_count'] ?? 0) as num).toDouble(),
        );
      }).toList();
      charts.add(_BarChartCard(title: 'Students by Classroom', bars: bars));
    }

    final assignmentSub = stats['ts_assignment_sub'];
    if (assignmentSub is List && assignmentSub.isNotEmpty) {
      final bars = assignmentSub.cast<Map<String, dynamic>>().map((r) {
        final enrolled = ((r['enrolled'] ?? 0) as num).toDouble();
        final submitted = ((r['submitted'] ?? 0) as num).toDouble();
        final pct = enrolled > 0 ? (submitted / enrolled) * 100 : 0.0;
        return (label: '${r['name'] ?? ''}', value: pct);
      }).toList();
      charts.add(_BarChartCard(
        title: 'Assignment Submission Rate',
        bars: bars,
        maxY: 100,
        valueSuffix: '%',
      ));
    }

    return charts;
  }
}

typedef _ChartBar = ({String label, double value});

class _BarChartCard extends StatelessWidget {
  final String title;
  final List<_ChartBar> bars;
  final double? maxY;
  final String valueSuffix;

  const _BarChartCard({
    required this.title,
    required this.bars,
    this.maxY,
    this.valueSuffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedMax = maxY ??
        ((bars.map((b) => b.value).fold<double>(0, (a, b) => a > b ? a : b)) *
                1.25)
            .clamp(4, double.infinity);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // Fixed height keeps this safe from bottom overflow regardless of
          // how many bars/labels are rendered.
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: resolvedMax,
                minY: 0,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= bars.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Transform.rotate(
                            angle: bars.length > 4 ? -0.5 : 0,
                            child: Text(
                              bars[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < bars.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: bars[i].value,
                          color: AppColors.primary,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
