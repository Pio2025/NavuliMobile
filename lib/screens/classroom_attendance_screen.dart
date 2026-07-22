import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ClassroomAttendanceScreen extends StatefulWidget {
  final int classId;

  const ClassroomAttendanceScreen({super.key, required this.classId});

  @override
  State<ClassroomAttendanceScreen> createState() => _ClassroomAttendanceScreenState();
}

class _ClassroomAttendanceScreenState extends State<ClassroomAttendanceScreen> {
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
      final body = await _client.getClassroomAttendance(widget.classId);
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

  @override
  Widget build(BuildContext context) {
    final mode = '${_body['mode'] ?? ''}';
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Failed to load attendance: $_error'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (mode == 'self')
                          _selfOrChildSection(List<dynamic>.from(_body['records'] ?? []))
                        else if (mode == 'children')
                          _childrenSection(List<dynamic>.from(_body['children'] ?? []))
                        else
                          _summarySection(Map<String, dynamic>.from(_body['summary'] ?? {})),
                      ],
                    ),
                  ),
      ),
    );
  }
}
