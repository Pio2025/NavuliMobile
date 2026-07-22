import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'subject_dashboard_screen.dart';

class ClassroomSubjectsScreen extends StatefulWidget {
  final int classId;
  final int? childId;
  final String? classroomName;
  final bool interactive;

  const ClassroomSubjectsScreen({
    super.key,
    required this.classId,
    this.childId,
    this.classroomName,
    this.interactive = false,
  });

  @override
  State<ClassroomSubjectsScreen> createState() => _ClassroomSubjectsScreenState();
}

class _ClassroomSubjectsScreenState extends State<ClassroomSubjectsScreen> {
  late ApiClient _client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _core = [];
  Map<String, List<Map<String, dynamic>>> _optional = {};
  bool _canFullAccess = false;

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
      final subjects = await _client.getClassroomSubjects(widget.classId, childId: widget.childId);
      final core = List<Map<String, dynamic>>.from(subjects['core'] ?? []);
      final optionalField = subjects['optional'];
      final optionalRaw = optionalField is Map ? Map<String, dynamic>.from(optionalField) : <String, dynamic>{};
      final optional = <String, List<Map<String, dynamic>>>{
        for (final entry in optionalRaw.entries)
          entry.key: List<Map<String, dynamic>>.from(entry.value ?? []),
      };
      setState(() {
        _core = core;
        _optional = optional;
        _canFullAccess = subjects['canFullAccess'] == true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Widget _subjectTile(Map<String, dynamic> s) {
    final scheme = Theme.of(context).colorScheme;
    final teacherName = s['teacher_name'] as String?;
    final photo = s['teacher_photo'] as String?;
    final tapEnabled = _canFullAccess && widget.interactive;
    final tile = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${s['subject_name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            backgroundImage: (photo != null && photo.isNotEmpty)
                ? NetworkImage(ApiConfig.photoUrl(photo))
                : null,
            child: (photo == null || photo.isEmpty)
                ? const Icon(Icons.person, size: 13, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            teacherName != null && teacherName.isNotEmpty ? teacherName : 'Not assigned',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (tapEnabled) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: tapEnabled
          ? InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SubjectDashboardScreen(
                    subject: s,
                    classroomName: widget.classroomName,
                  ),
                ),
              ),
              child: tile,
            )
          : tile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final optionalKeys = _optional.keys.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Subjects')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Failed to load subjects: $_error'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_core.isEmpty && _optional.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.menu_book_outlined, size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.childId != null
                                        ? 'This child is not taking any subjects in this classroom yet.'
                                        : 'No subjects assigned yet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_core.isNotEmpty) ...[
                          const Text('Core Subjects',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 8),
                          for (final s in _core) _subjectTile(s),
                          const SizedBox(height: 12),
                        ],
                        for (final key in optionalKeys) ...[
                          Text('Optional Group $key',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 8),
                          for (final s in _optional[key]!) _subjectTile(s),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}
