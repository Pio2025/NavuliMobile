import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/error_state.dart';

num _asNum(dynamic v) => (v is num) ? v : (num.tryParse('$v') ?? 0);

class AttendanceDailyDetailScreen extends StatefulWidget {
  final int classId;
  final int? childId;
  final int term;
  final String termLabel;

  const AttendanceDailyDetailScreen({
    super.key,
    required this.classId,
    this.childId,
    required this.term,
    required this.termLabel,
  });

  @override
  State<AttendanceDailyDetailScreen> createState() => _AttendanceDailyDetailScreenState();
}

class _AttendanceDailyDetailScreenState extends State<AttendanceDailyDetailScreen> {
  late ApiClient _client;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _body = {};

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
      final body = await _client.getClassroomAttendanceDaily(widget.classId, term: widget.term, childId: widget.childId);
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

  Color _rateColor(double pct) {
    if (pct >= 80) return AppColors.success;
    if (pct >= 70) return AppColors.warning;
    return AppColors.danger;
  }

  Widget _statCard(String label, String value, Color color, {double? progress}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 5,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  ({String text, Color bg, Color fg}) _cellStyle(String status) {
    switch (status) {
      case 'present':
        return (text: '✓', bg: const Color(0xFFD1FAE5), fg: const Color(0xFF065F46));
      case 'absent':
        return (text: '✗', bg: const Color(0xFFFEE2E2), fg: const Color(0xFF991B1B));
      case 'holiday':
        return (text: 'H', bg: const Color(0xFFEDE9FE), fg: const Color(0xFF6D28D9));
      case 'future':
        return (text: '—', bg: Colors.transparent, fg: const Color(0xFFD1D5DB));
      default:
        return (text: '—', bg: const Color(0xFFF3F4F6), fg: const Color(0xFF9CA3AF));
    }
  }

  Widget _gridCell(String text, Color bg, Color fg) {
    return Container(
      width: 42,
      height: 42,
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: text.length > 1 ? 11 : 15)),
    );
  }

  Widget _weeklyGrid(List<dynamic> weeks, List<dynamic> dayNames) {
    final weeksList = List<Map<String, dynamic>>.from(weeks);
    if (weeksList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No weeks configured for this term.')),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(width: 42, height: 42),
            for (final d in dayNames)
              Container(
                width: 42,
                height: 42,
                margin: const EdgeInsets.all(2),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                child: Text('$d', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1A56DB))),
              ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final w in weeksList)
                  Column(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        margin: const EdgeInsets.all(2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFFFFF8E6), borderRadius: BorderRadius.circular(8)),
                        child: Text('W${w['weekNum']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFE6A817))),
                      ),
                      for (final d in List<Map<String, dynamic>>.from(w['days'] ?? []))
                        Builder(builder: (_) {
                          final s = _cellStyle('${d['status']}');
                          return _gridCell(s.text, s.bg, s.fg);
                        }),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend() {
    Widget item(Color bg, Color fg, String symbol, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
              child: Text(symbol, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11.5)),
          ],
        );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(const Color(0xFFD1FAE5), const Color(0xFF065F46), '✓', 'Present'),
        item(const Color(0xFFFEE2E2), const Color(0xFF991B1B), '✗', 'Absent'),
        item(const Color(0xFFF3F4F6), const Color(0xFF9CA3AF), '—', 'Not marked'),
        item(const Color(0xFFEDE9FE), const Color(0xFF6D28D9), 'H', 'Holiday'),
      ],
    );
  }

  Widget _card({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _overallDonut(Map<String, dynamic> stats) {
    final present = _asNum(stats['present']).toDouble();
    final absent = _asNum(stats['absent']).toDouble();
    final unmarked = _asNum(stats['unmarked']).toDouble();
    final pct = _asNum(stats['pct']).toDouble();
    final total = present + absent + unmarked;
    return SizedBox(
      height: 160,
      child: Row(
        children: [
          SizedBox(
            height: 140,
            width: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        value: present <= 0 ? 0.0001 : present,
                        color: AppColors.success,
                        showTitle: false,
                        radius: 26,
                      ),
                      PieChartSectionData(
                        value: absent <= 0 ? 0.0001 : absent,
                        color: AppColors.danger,
                        showTitle: false,
                        radius: 26,
                      ),
                      PieChartSectionData(
                        value: unmarked <= 0 ? 0.0001 : unmarked,
                        color: const Color(0xFF9CA3AF),
                        showTitle: false,
                        radius: 26,
                      ),
                    ],
                  ),
                ),
                Text('${total > 0 ? pct : 0}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendRow(AppColors.success, 'Present', present.toInt()),
                const SizedBox(height: 8),
                _legendRow(AppColors.danger, 'Absent', absent.toInt()),
                const SizedBox(height: 8),
                _legendRow(const Color(0xFF9CA3AF), 'Unmarked', unmarked.toInt()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label, int value) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const Spacer(),
        Text('$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _weeklyRateChart(List<dynamic> weeks) {
    final weeksList = List<Map<String, dynamic>>.from(weeks);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: 100,
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
                reservedSize: 32,
                interval: 25,
                getTitlesWidget: (value, meta) =>
                    Text('${value.toInt()}%', style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= weeksList.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('W${weeksList[i]['weekNum']}', style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < weeksList.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: weeksList[i]['pct'] != null ? _asNum(weeksList[i]['pct']).toDouble() : 0,
                  color: weeksList[i]['pct'] != null ? _rateColor(_asNum(weeksList[i]['pct']).toDouble()) : const Color(0xFFE5E7EB),
                  width: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final childName = _body['childName'] as String?;
    final title = childName != null && childName.isNotEmpty
        ? '$childName — Daily Attendance'
        : '${widget.termLabel} ${widget.term} — My Daily Attendance';

    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 15))),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorState(error: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Builder(builder: (_) {
                          final streamInfo = Map<String, dynamic>.from(_body['streamInfo'] ?? {});
                          final streamName = '${streamInfo['streamName'] ?? ''}';
                          final levelName = '${streamInfo['levelName'] ?? ''}';
                          if (streamName.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.event_available_outlined, color: AppColors.primary, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(levelName.isNotEmpty ? '$streamName ($levelName)' : streamName,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      Text('${widget.termLabel} ${widget.term}',
                                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        Builder(builder: (_) {
                          final stats = Map<String, dynamic>.from(_body['summaryStats'] ?? {});
                          final pct = _asNum(stats['pct']).toDouble();
                          final color = _rateColor(pct);
                          return GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.7,
                            children: [
                              _statCard('Days Marked', '${stats['numMarked'] ?? 0}', AppColors.secondary),
                              _statCard('Present', '${stats['present'] ?? 0}', AppColors.success),
                              _statCard('Absent', '${stats['absent'] ?? 0}', AppColors.danger),
                              _statCard('Attendance Rate', '$pct%', color, progress: pct / 100),
                            ],
                          );
                        }),
                        const SizedBox(height: 16),
                        _card(
                          title: 'Weekly Attendance Grid',
                          icon: Icons.grid_on_outlined,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _weeklyGrid(_body['weeks'] ?? [], _body['dayNames'] ?? const ['M', 'T', 'W', 'TH', 'F']),
                              const SizedBox(height: 14),
                              _legend(),
                            ],
                          ),
                        ),
                        _card(
                          title: 'Overall Attendance',
                          icon: Icons.donut_large_outlined,
                          child: _overallDonut(Map<String, dynamic>.from(_body['summaryStats'] ?? {})),
                        ),
                        _card(
                          title: 'Weekly Attendance Rate (%)',
                          icon: Icons.bar_chart_outlined,
                          child: _weeklyRateChart(_body['weeks'] ?? []),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
