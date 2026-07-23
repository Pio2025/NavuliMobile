import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/classroom_overview_body.dart';
import '../widgets/error_state.dart';
import 'classroom_captains_screen.dart';
import 'classroom_form_screen.dart';
import 'classroom_students_screen.dart';
import 'classroom_subjects_screen.dart';
import 'classroom_teachers_screen.dart';

/// Read-only classroom detail reached from "Classroom Listing" (scope=all).
/// Top-right icons are all view-only: Students, Subjects, Class Teachers,
/// Class Captains.
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
              onPressed: () => _openTab((id) => ClassroomSubjectsScreen(classId: id)),
            ),
            IconButton(
              icon: const Icon(Icons.school_outlined),
              tooltip: 'Class Teachers',
              onPressed: () => _openTab((id) => ClassroomTeachersScreen(classId: id)),
            ),
            IconButton(
              icon: const Icon(Icons.military_tech_outlined),
              tooltip: 'Class Captains',
              onPressed: () => _openTab((id) => ClassroomCaptainsScreen(classId: id)),
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
