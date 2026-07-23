import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ClassroomExamScreen extends StatefulWidget {
  final int classId;

  const ClassroomExamScreen({super.key, required this.classId});

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
      final body = await _client.getClassroomExam(widget.classId);
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

  Widget _reportCard(Map<String, dynamic> termData) {
    final scheme = Theme.of(context).colorScheme;
    final published = termData['published'] == true;
    if (!published) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Text('Results for this term have not been published yet.',
              textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }
    final report = Map<String, dynamic>.from(termData['report'] ?? {});
    final stats = Map<String, dynamic>.from(termData['stats'] ?? {});
    final marks = List<Map<String, dynamic>>.from(report['marks'] ?? []);
    final pct = report['overall_pct'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statChip('Overall %', pct != null ? '$pct%' : '—', AppColors.primary),
            _statChip('Position', '${stats['position'] ?? '—'}/${stats['total_ranked'] ?? '—'}', AppColors.secondary),
            _statChip('Class Avg', '${stats['avg_score'] ?? '—'}%', AppColors.warning),
          ],
        ),
        const SizedBox(height: 16),
        for (final m in marks)
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
                    child: Text('${m['subject_name'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  Text(
                    (m['is_absent'] == true || m['is_absent'] == 1)
                        ? 'Absent'
                        : '${m['mark'] ?? '—'} / ${m['total_mark'] ?? '—'}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: (m['is_absent'] == true || m['is_absent'] == 1) ? AppColors.danger : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if ((report['ct_comment'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Class Teacher: ${report['ct_comment']}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
        if ((report['principal_comment'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Principal: ${report['principal_comment']}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
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
            _statChip('Pass %', '${stats['pct_pass'] ?? 0}%', AppColors.success),
            _statChip('Class Avg', '${stats['avg_score'] ?? '—'}%', AppColors.warning),
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
          Text('${child['childName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          _reportCard(_termsAt(child)['$_term'] ?? {}),
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
                ? Center(child: Text('Failed to load exam results: $_error'))
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
                          _reportCard(Map<String, dynamic>.from(terms['$_term'] ?? {}))
                        else
                          _summaryGrid(Map<String, dynamic>.from(terms['$_term'] ?? {})),
                      ],
                    ),
                  ),
      ),
    );
  }
}
