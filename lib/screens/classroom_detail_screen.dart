import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_ago.dart';
import 'classroom_staff_screen.dart';
import 'classroom_students_screen.dart';
import 'classroom_subjects_screen.dart';

class ClassroomDetailScreen extends StatefulWidget {
  final int classId;

  const ClassroomDetailScreen({super.key, required this.classId});

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> {
  late ApiClient _client;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _classroom;

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
      final body = await _client.getClassroomDetail(widget.classId);
      setState(() {
        _classroom = Map<String, dynamic>.from(body['classroom'] ?? {});
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _openTab(Widget Function(int classId) builder) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => builder(widget.classId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_classroom?['name'] ?? 'Classroom'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Subjects',
            onPressed: () => _openTab((id) => ClassroomSubjectsScreen(classId: id)),
          ),
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            tooltip: 'Staff',
            onPressed: () => _openTab((id) => ClassroomStaffScreen(classId: id)),
          ),
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Students',
            onPressed: () => _openTab((id) => ClassroomStudentsScreen(classId: id)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Failed to load classroom: $_error'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildOverview(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildOverview() {
    final c = _classroom ?? {};
    final scheme = Theme.of(context).colorScheme;

    Widget infoRow(IconData icon, String label, String? value) {
      if (value == null || value.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text('$label: ', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${c['name'] ?? ''}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${c['status'] ?? ''}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          infoRow(Icons.calendar_today_outlined, 'Year', '${c['year'] ?? ''}'),
          infoRow(Icons.stream_outlined, 'Stream', c['streamName']),
          infoRow(Icons.layers_outlined, 'Level', c['levelName']),
          infoRow(Icons.apartment_outlined, 'School', c['schoolName']),
          infoRow(Icons.person_outline, 'Class Teacher', c['classTeacher']),
          infoRow(Icons.menu_book_outlined, 'Subjects', '${c['subjectCount'] ?? 0}'),
          infoRow(Icons.groups_outlined, 'Students', '${c['studentCount'] ?? 0}'),
          if ((c['createdAt'] ?? '').toString().isNotEmpty)
            infoRow(Icons.history_outlined, 'Created', '${c['createdBy'] ?? ''} · ${timeAgo(c['createdAt'])}'),
          if ((c['updatedAt'] ?? '').toString().isNotEmpty)
            infoRow(Icons.update_outlined, 'Updated', '${c['updatedBy'] ?? ''} · ${timeAgo(c['updatedAt'])}'),
        ],
      ),
    );
  }
}
