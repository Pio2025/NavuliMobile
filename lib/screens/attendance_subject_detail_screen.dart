import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/error_state.dart';

class AttendanceSubjectDetailScreen extends StatefulWidget {
  final int classId;
  final int? childId;
  final int term;
  final String termLabel;

  const AttendanceSubjectDetailScreen({
    super.key,
    required this.classId,
    this.childId,
    required this.term,
    required this.termLabel,
  });

  @override
  State<AttendanceSubjectDetailScreen> createState() => _AttendanceSubjectDetailScreenState();
}

class _AttendanceSubjectDetailScreenState extends State<AttendanceSubjectDetailScreen> {
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
      final body = await _client.getClassroomAttendanceSubject(widget.classId, term: widget.term, childId: widget.childId);
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
    if (pct >= 60) return AppColors.warning;
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

  Widget _subjectRow(Map<String, dynamic> s) {
    final pct = (s['pct'] as num? ?? 0).toDouble();
    final color = _rateColor(pct);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${s['subjectName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Text('$pct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('${s['present'] ?? 0} present', style: const TextStyle(fontSize: 11, color: AppColors.success)),
              const SizedBox(width: 10),
              Text('${s['absent'] ?? 0} absent', style: const TextStyle(fontSize: 11, color: AppColors.danger)),
              const SizedBox(width: 10),
              Text('${s['late'] ?? 0} late', style: const TextStyle(fontSize: 11, color: AppColors.warning)),
              const Spacer(),
              Text('${s['total'] ?? 0} total', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recordTile(Map<String, dynamic> r) {
    final status = '${r['status'] ?? ''}';
    final statusLow = status.toLowerCase();
    final color = statusLow == 'present'
        ? AppColors.success
        : statusLow == 'absent'
            ? AppColors.danger
            : statusLow == 'late'
                ? AppColors.warning
                : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text('${r['date'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
            Expanded(
              flex: 4,
              child: Text('${r['subject'] ?? ''}', style: const TextStyle(fontSize: 12.5)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(status.isEmpty ? '—' : status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final childName = _body['childName'] as String?;
    final title = childName != null && childName.isNotEmpty
        ? '$childName — Subject Attendance'
        : '${widget.termLabel} ${widget.term} — My Subject Attendance';

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
                                  decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.menu_book_outlined, color: AppColors.secondary, size: 18),
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
                          final summary = Map<String, dynamic>.from(_body['summary'] ?? {});
                          final pct = (summary['pct'] as num? ?? 0).toDouble();
                          final color = _rateColor(pct);
                          return GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.7,
                            children: [
                              _statCard('Total Records', '${summary['total'] ?? 0}', AppColors.secondary),
                              _statCard('Present', '${summary['present'] ?? 0}', AppColors.success),
                              _statCard('Absent', '${summary['absent'] ?? 0}', AppColors.danger),
                              _statCard('Attendance Rate', '$pct%', color, progress: pct / 100),
                            ],
                          );
                        }),
                        const SizedBox(height: 16),
                        Builder(builder: (_) {
                          final subjects = List<Map<String, dynamic>>.from(_body['bySubject'] ?? []);
                          if (subjects.isEmpty) return const SizedBox.shrink();
                          return _card(
                            title: 'By Subject',
                            icon: Icons.stacked_bar_chart_outlined,
                            child: Column(children: [for (final s in subjects) _subjectRow(s)]),
                          );
                        }),
                        Builder(builder: (_) {
                          final records = List<Map<String, dynamic>>.from(_body['records'] ?? [])
                            ..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
                          return _card(
                            title: 'All Records',
                            icon: Icons.calendar_month_outlined,
                            child: records.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(child: Text('No subject attendance records for this term.')),
                                  )
                                : Column(children: [for (final r in records) _recordTile(r)]),
                          );
                        }),
                      ],
                    ),
                  ),
      ),
    );
  }
}
