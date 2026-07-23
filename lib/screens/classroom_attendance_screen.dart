import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'attendance_daily_detail_screen.dart';
import 'attendance_subject_detail_screen.dart';

class ClassroomAttendanceScreen extends StatefulWidget {
  final int classId;
  final int? childId;

  const ClassroomAttendanceScreen({super.key, required this.classId, this.childId});

  @override
  State<ClassroomAttendanceScreen> createState() => _ClassroomAttendanceScreenState();
}

class _ClassroomAttendanceScreenState extends State<ClassroomAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late ApiClient _client;
  bool _loading = true;
  String? _error;

  // Term-tabbed mode (school has sch_cat term config)
  String _termLabel = 'Term';
  List<Map<String, dynamic>> _terms = [];
  TabController? _tabController;

  // Legacy fallback mode (school has no term config)
  Map<String, dynamic> _legacyBody = {};

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    _load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final termsBody = await _client.getClassroomAttendanceTerms(widget.classId);
      final terms = List<Map<String, dynamic>>.from(termsBody['terms'] ?? []);

      if (terms.isEmpty) {
        final legacy = await _client.getClassroomAttendance(widget.classId);
        setState(() {
          _legacyBody = legacy;
          _terms = [];
          _loading = false;
        });
        return;
      }

      final currentTerm = (termsBody['currentTerm'] as num? ?? 0).toInt();
      final initialIndex = terms.indexWhere((t) => (t['termNum'] as num).toInt() == currentTerm);
      _tabController?.dispose();
      _tabController = TabController(
        length: terms.length,
        vsync: this,
        initialIndex: initialIndex >= 0 ? initialIndex : 0,
      );
      setState(() {
        _termLabel = '${termsBody['termLabel'] ?? 'Term'}';
        _terms = terms;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Widget _optionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ?? scheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _termTab(int termNum) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _optionCard(
          icon: Icons.event_available_outlined,
          color: AppColors.primary,
          title: 'Student Daily Attendance',
          subtitle: 'Weekly attendance grid for $_termLabel $termNum',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AttendanceDailyDetailScreen(
                classId: widget.classId,
                childId: widget.childId,
                term: termNum,
                termLabel: _termLabel,
              ),
            ),
          ),
        ),
        _optionCard(
          icon: Icons.menu_book_outlined,
          color: AppColors.secondary,
          title: 'Student Subject Attendance',
          subtitle: 'Per-subject attendance for $_termLabel $termNum',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AttendanceSubjectDetailScreen(
                classId: widget.classId,
                childId: widget.childId,
                term: termNum,
                termLabel: _termLabel,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Legacy fallback UI (schools without sch_cat term config) ──────────────

  Widget _statusBadge(String status) {
    final isPresent = status.toLowerCase() == 'present';
    final color = isPresent ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.isEmpty ? '—' : status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _recordTile(Map<String, dynamic> r) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${r['date'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            _statusBadge('${r['status'] ?? ''}'),
          ],
        ),
      ),
    );
  }

  Widget _recordsList(List<dynamic> records) {
    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text('No attendance records yet.')),
      );
    }
    final sorted = List<Map<String, dynamic>>.from(records)
      ..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    return Column(children: [for (final r in sorted) _recordTile(r)]);
  }

  Widget _selfOrChildSection(List<dynamic> records) {
    final present = records.where((r) => '${r['status']}'.toLowerCase() == 'present').length;
    final absent = records.where((r) => '${r['status']}'.toLowerCase() == 'absent').length;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _countCard('Present', present, AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _countCard('Absent', absent, AppColors.danger)),
          ],
        ),
        const SizedBox(height: 16),
        Text('History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        _recordsList(records),
      ],
    );
  }

  Widget _countCard(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _summarySection(Map<String, dynamic> summary) {
    final days = List<Map<String, dynamic>>.from(summary['days'] ?? []).reversed.toList();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _countCard('Total Present', (summary['totalPresent'] as num? ?? 0).toInt(), AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _countCard('Total Absent', (summary['totalAbsent'] as num? ?? 0).toInt(), AppColors.danger)),
          ],
        ),
        const SizedBox(height: 16),
        Text('By Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        if (days.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No attendance records yet.')),
          )
        else
          for (final d in days)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${d['date'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Row(
                      children: [
                        Text('${d['presentCount'] ?? 0} present',
                            style: const TextStyle(fontSize: 12, color: AppColors.success)),
                        const SizedBox(width: 8),
                        Text('${d['absentCount'] ?? 0} absent',
                            style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
          Text('${child['childName'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          _selfOrChildSection(List<dynamic>.from(child['records'] ?? [])),
          const SizedBox(height: 22),
        ],
      ],
    );
  }

  Widget _legacyBody0() {
    final mode = '${_legacyBody['mode'] ?? ''}';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (mode == 'self')
            _selfOrChildSection(List<dynamic>.from(_legacyBody['records'] ?? []))
          else if (mode == 'children')
            _childrenSection(List<dynamic>.from(_legacyBody['children'] ?? []))
          else
            _summarySection(Map<String, dynamic>.from(_legacyBody['summary'] ?? {})),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance')),
        body: Center(child: Text('Failed to load attendance: $_error')),
      );
    }
    if (_terms.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance')),
        body: SafeArea(top: false, child: _legacyBody0()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: _terms.length > 3,
          tabs: [for (final t in _terms) Tab(text: '$_termLabel ${t['termNum']}')],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          children: [for (final t in _terms) _termTab((t['termNum'] as num).toInt())],
        ),
      ),
    );
  }
}
