import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_ago.dart';
import 'classroom_form_screen.dart';
import 'classroom_staff_screen.dart';
import 'classroom_students_screen.dart';
import 'classroom_subjects_screen.dart';

class ClassroomDetailScreen extends StatefulWidget {
  final int classId;
  final bool readOnly;

  const ClassroomDetailScreen({super.key, required this.classId, this.readOnly = false});

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> {
  late ApiClient _client;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _classroom;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _changed = false;

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
        _canEdit = !widget.readOnly && body['canEdit'] == true;
        _canDelete = !widget.readOnly && body['canDelete'] == true;
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

  Future<void> _editClassroom() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClassroomFormScreen(existingClassroom: _classroom),
      ),
    );
    if (updated == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete classroom?'),
        content: Text(
          'Are you sure you want to delete "${_classroom?['name'] ?? 'this classroom'}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF1416C)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _client.deleteClassroom(widget.classId);
      if (!mounted) return;
      Navigator.of(context).pop({'deleted': true});
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e', style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.groups_outlined),
              tooltip: 'Students',
              onPressed: () => _openTab((id) => ClassroomStudentsScreen(classId: id)),
            ),
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
          ],
        ),
        body: SafeArea(
          top: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Failed to load classroom: $_error'))
                  : Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildOverview(),
                            ],
                          ),
                        ),
                        if (_busy)
                          Container(
                            color: Colors.black.withValues(alpha: 0.15),
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    final c = _classroom ?? {};
    final scheme = Theme.of(context).colorScheme;
    final schoolLogo = '${c['schoolLogo'] ?? ''}';
    final classTeacher = '${c['classTeacher'] ?? ''}';
    final classTeacherPhoto = '${c['classTeacherPhoto'] ?? ''}';

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
              if (_canEdit || _canDelete)
                PopupMenuButton<String>(
                  icon: Icon(Icons.arrow_drop_down_circle_outlined, color: scheme.onSurfaceVariant),
                  onSelected: (value) {
                    if (value == 'edit') _editClassroom();
                    if (value == 'delete') _confirmDelete();
                  },
                  itemBuilder: (context) => [
                    if (_canEdit)
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (_canDelete)
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Color(0xFFF1416C)),
                          title: Text('Delete', style: TextStyle(color: Color(0xFFF1416C))),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: schoolLogo.isNotEmpty
                      ? Image.network(
                          ApiConfig.schoolLogoUrl(schoolLogo),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Image.asset(
                            'assets/images/icon.png',
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/icon.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${c['schoolName'] ?? ''}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(height: 1.2, width: 40, color: AppColors.primary.withValues(alpha: 0.4)),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                    Container(height: 1.2, width: 40, color: AppColors.primary.withValues(alpha: 0.4)),
                  ],
                ),
              ],
            ),
          ),
          if (classTeacher.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage:
                      classTeacherPhoto.isNotEmpty ? NetworkImage(ApiConfig.photoUrl(classTeacherPhoto)) : null,
                  child: classTeacherPhoto.isEmpty
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Class Teacher',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      Text(classTeacher,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statTile(Icons.calendar_today_outlined, 'Year', '${c['year'] ?? ''}'),
              _statTile(Icons.stream_outlined, 'Stream', '${c['streamName'] ?? '—'}'),
              _statTile(Icons.layers_outlined, 'Level', '${c['levelName'] ?? '—'}'),
              _statTile(Icons.menu_book_outlined, 'Subjects', '${c['subjectCount'] ?? 0}'),
              _statTile(Icons.groups_outlined, 'Students', '${c['studentCount'] ?? 0}'),
              _statTile(Icons.play_lesson_outlined, 'Lessons', '${c['lessonCount'] ?? 0}'),
            ],
          ),
          if ((c['createdAt'] ?? '').toString().isNotEmpty ||
              (c['updatedAt'] ?? '').toString().isNotEmpty) ...[
            const Divider(height: 28),
            if ((c['createdAt'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  'Created by ${c['createdBy'] ?? ''} · ${timeAgo(c['createdAt'])}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            if ((c['updatedAt'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  'Updated by ${c['updatedBy'] ?? ''} · ${timeAgo(c['updatedAt'])}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
