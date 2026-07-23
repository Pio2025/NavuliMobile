import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/classroom_overview_body.dart';
import '../widgets/error_state.dart';
import 'classroom_attendance_screen.dart';
import 'classroom_discussion_screen.dart';
import 'classroom_exam_screen.dart';
import 'classroom_form_screen.dart';
import 'classroom_students_screen.dart';
import 'classroom_subjects_screen.dart';

/// Classroom detail reached from "My Classroom" (scope=mine) or
/// "My Child Classroom" (scope=child, [childId] set). Top-right icons:
/// Students, Subjects (filtered to the child's subjects when [childId] is
/// set), Attendance, Exam, Discussion. Overview body is identical to
/// [ClassroomDetailScreen] — only the icons/navigation differ.
class ClassroomFullDetailScreen extends StatefulWidget {
  final int classId;
  final int? childId;
  final bool readOnly;

  const ClassroomFullDetailScreen({
    super.key,
    required this.classId,
    this.childId,
    this.readOnly = false,
  });

  @override
  State<ClassroomFullDetailScreen> createState() => _ClassroomFullDetailScreenState();
}

class _ClassroomFullDetailScreenState extends State<ClassroomFullDetailScreen> {
  late ApiClient _client;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _classroom;
  Map<String, dynamic> _staff = {};
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
      final results = await Future.wait([
        _client.getClassroomDetail(widget.classId),
        _client.getClassroomStaff(widget.classId),
      ]);
      final body = results[0];
      setState(() {
        _classroom = Map<String, dynamic>.from(body['classroom'] ?? {});
        _staff = results[1];
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
      AppSnackbar.error(context, friendlyErrorMessage(e));
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
              onPressed: () => _openTab(
                (id) => ClassroomSubjectsScreen(
                  classId: id,
                  childId: widget.childId,
                  classroomName: _classroom?['name'] as String?,
                  interactive: true,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.event_available_outlined),
              tooltip: 'Attendance',
              onPressed: () => _openTab((id) => ClassroomAttendanceScreen(classId: id, childId: widget.childId)),
            ),
            IconButton(
              icon: const Icon(Icons.fact_check_outlined),
              tooltip: 'Exam',
              onPressed: () => _openTab((id) => ClassroomExamScreen(classId: id, childId: widget.childId)),
            ),
            IconButton(
              icon: const Icon(Icons.forum_outlined),
              tooltip: 'Discussion',
              onPressed: () => _openTab((id) => ClassroomDiscussionScreen(classId: id)),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorState(error: _error!, onRetry: _load)
                  : Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              ClassroomOverviewBody(
                                classroom: _classroom ?? {},
                                staff: _staff,
                                canEdit: _canEdit,
                                canDelete: _canDelete,
                                onEdit: _editClassroom,
                                onDelete: _confirmDelete,
                              ),
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
}
