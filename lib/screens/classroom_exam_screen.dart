import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/error_state.dart';
import 'exam_report_card_screen.dart';

int _asInt(dynamic v) => (v is num) ? v.round() : (num.tryParse('$v')?.round() ?? 0);

class ClassroomExamScreen extends StatefulWidget {
  final int classId;
  final int? childId;

  const ClassroomExamScreen({super.key, required this.classId, this.childId});

  @override
  State<ClassroomExamScreen> createState() => _ClassroomExamScreenState();
}

class _ClassroomExamScreenState extends State<ClassroomExamScreen> {
  late ApiClient _client;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _body = {};
  int _term = 1;
  List<int> _termNums = [1, 2, 3];

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
      final body = await _client.getClassroomExam(widget.classId, childId: widget.childId);
      final mode = '${body['mode'] ?? ''}';
      Map<String, dynamic> termsSource;
      if (mode == 'children') {
        final children = List<Map<String, dynamic>>.from(body['children'] ?? []);
        termsSource = children.isNotEmpty ? _termsAt(children.first) : {};
      } else {
        termsSource = _termsAt(body);
      }
      final terms = termsSource.keys.map(int.parse).toList()..sort();
      setState(() {
        _body = body;
        if (terms.isNotEmpty) {
          _termNums = terms;
          if (!_termNums.contains(_term)) _term = _termNums.first;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _termsAt(Map<String, dynamic> source) {
    final raw = source['terms'];
    return raw is Map ? Map<String, dynamic>.from(raw) : {};
  }

  Widget _termSelector() {
    final label = '${_body['termLabel'] ?? 'Term'}';
    return Row(
      children: [
        for (final t in _termNums)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: t == _termNums.last ? 0 : 8),
              child: ChoiceChip(
                label: Text('$label $t'),
                selected: _term == t,
                onSelected: (_) => setState(() => _term = t),
              ),
            ),
          ),
      ],
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  void _openExam(Map<String, dynamic> termData, {required String examName, required String studentName, required String studentPhoto}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamReportCardScreen(
          classroom: Map<String, dynamic>.from(_body['classroom'] ?? {}),
          examName: examName,
          studentName: studentName,
          studentPhoto: studentPhoto,
          termLabel: '${_body['termLabel'] ?? 'Term'}',
          term: _term,
          termData: termData,
        ),
      ),
    );
  }

  Widget _examList(Map<String, dynamic> termData, {required String studentName, required String studentPhoto}) {
    final scheme = Theme.of(context).colorScheme;
    final exams = List<Map<String, dynamic>>.from(termData['exams'] ?? []);
    final published = termData['published'] == true;

    if (exams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Text('No exams defined for this term yet.',
              textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final exam in exams)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Theme.of(context).cardTheme.color ?? scheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openExam(termData,
                    examName: '${exam['examName'] ?? 'Exam'}', studentName: studentName, studentPhoto: studentPhoto),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${exam['examName'] ?? 'Exam'}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text(
                              published ? 'Report card available' : 'Not yet published',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: published ? AppColors.success : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _summaryGrid(Map<String, dynamic> termData) {
    final scheme = Theme.of(context).colorScheme;
    final stats = Map<String, dynamic>.from(termData['stats'] ?? {});
    final students = List<Map<String, dynamic>>.from(termData['marks'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statChip('Sat', '${stats['number_sat'] ?? 0}', AppColors.primary),
            _statChip('Pass %', '${_asInt(stats['pct_pass'] ?? 0)}%', AppColors.success),
            _statChip('Class Avg', stats['avg_score'] != null ? '${_asInt(stats['avg_score'])}%' : '—', AppColors.warning),
          ],
        ),
        const SizedBox(height: 16),
        if (students.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No exam marks recorded for this term.')),
          )
        else
          for (final s in students)
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
                    Expanded(
                      child: Text(
                        trim('${s['fname'] ?? ''} ${s['lname'] ?? ''}'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    Text(
                      _pctOf(s),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  String trim(String s) => s.trim();

  String _pctOf(Map<String, dynamic> s) {
    final earned = (s['total_earned'] as num?)?.toDouble() ?? 0;
    final possible = (s['total_possible'] as num?)?.toDouble() ?? 0;
    if (possible <= 0) return '—';
    return '${(earned / possible * 100).round()}%';
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
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: '${child['childPhoto'] ?? ''}'.isNotEmpty
                    ? NetworkImage(ApiConfig.photoUrl('${child['childPhoto']}'))
                    : null,
                child: '${child['childPhoto'] ?? ''}'.isEmpty
                    ? Text(
                        '${child['childName'] ?? ''}'.isNotEmpty ? '${child['childName']}'[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 12),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Text('${child['childName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          _examList(
            Map<String, dynamic>.from(_termsAt(child)['$_term'] ?? {}),
            studentName: '${child['childName'] ?? ''}',
            studentPhoto: '${child['childPhoto'] ?? ''}',
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = '${_body['mode'] ?? ''}';
    final terms = _termsAt(_body);
    return Scaffold(
      appBar: AppBar(title: const Text('Exam Results')),
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
                        _termSelector(),
                        const SizedBox(height: 16),
                        if (mode == 'children')
                          _childrenSection(List<dynamic>.from(_body['children'] ?? []))
                        else if (mode == 'self')
                          _examList(
                            Map<String, dynamic>.from(terms['$_term'] ?? {}),
                            studentName: trim('${_body['student']?['fname'] ?? ''} ${_body['student']?['lname'] ?? ''}'),
                            studentPhoto: '${_body['student']?['photo'] ?? ''}',
                          )
                        else
                          _summaryGrid(Map<String, dynamic>.from(terms['$_term'] ?? {})),
                      ],
                    ),
                  ),
      ),
    );
  }
}
