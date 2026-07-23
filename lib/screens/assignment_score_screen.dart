import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';

num _asNum(dynamic v) => (v is num) ? v : (num.tryParse('$v') ?? 0);

class _FileTypeStyle {
  final IconData icon;
  final Color color;
  const _FileTypeStyle(this.icon, this.color);
}

_FileTypeStyle _fileTypeStyle(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return const _FileTypeStyle(Icons.picture_as_pdf, Color(0xFFE2574C));
    case 'doc':
    case 'docx':
      return const _FileTypeStyle(Icons.description, Color(0xFF2B579A));
    case 'xls':
    case 'xlsx':
    case 'csv':
      return const _FileTypeStyle(Icons.grid_on, Color(0xFF217346));
    case 'ppt':
    case 'pptx':
      return const _FileTypeStyle(Icons.slideshow, Color(0xFFD24726));
    case 'zip':
    case 'rar':
    case '7z':
      return const _FileTypeStyle(Icons.folder_zip, Color(0xFF8D6E63));
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':
      return const _FileTypeStyle(Icons.image, Color(0xFF00AEEF));
    case 'txt':
      return const _FileTypeStyle(Icons.article, Color(0xFF757575));
    default:
      return const _FileTypeStyle(Icons.insert_drive_file, Color(0xFF757575));
  }
}

Future<void> _openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      AppSnackbar.error(context, 'Could not open file.');
    }
  } catch (_) {
    if (context.mounted) {
      AppSnackbar.error(context, 'Could not open file.');
    }
  }
}

String _formatDate(dynamic raw) {
  final s = '${raw ?? ''}';
  if (s.isEmpty) return '—';
  final dt = DateTime.tryParse(s);
  if (dt == null) return s;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year} $hour12:${dt.minute.toString().padLeft(2, '0')} $period';
}

class AssignmentScoreScreen extends StatefulWidget {
  final int classSubId;
  final int assignmentId;
  final String assignmentName;
  final int? childId;

  const AssignmentScoreScreen({
    super.key,
    required this.classSubId,
    required this.assignmentId,
    required this.assignmentName,
    this.childId,
  });

  @override
  State<AssignmentScoreScreen> createState() => _AssignmentScoreScreenState();
}

class _AssignmentScoreScreenState extends State<AssignmentScoreScreen> {
  late ApiClient _client;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

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
      final body = await _client.getSubjectAssignmentDetail(widget.classSubId, widget.assignmentId, childId: widget.childId);
      setState(() {
        _data = body;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.assignmentName, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 40, color: scheme.error),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          OutlinedButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                : (_data == null || _data!['success'] != true)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.assignment_outlined, size: 48, color: scheme.onSurfaceVariant),
                              const SizedBox(height: 12),
                              Text(
                                '${_data?['message'] ?? 'Assignment not found.'}',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(onRefresh: _load, child: _body(scheme)),
      ),
    );
  }

  Widget _body(ColorScheme scheme) {
    final data = _data!;
    final mode = '${data['mode'] ?? ''}';
    final assignment = Map<String, dynamic>.from(data['assignment'] ?? {});
    final stats = Map<String, dynamic>.from(data['stats'] ?? {});
    final submission = data['submission'] != null ? Map<String, dynamic>.from(data['submission']) : null;
    final score = data['score'] != null ? Map<String, dynamic>.from(data['score']) : null;
    final files = List<Map<String, dynamic>>.from(assignment['files'] ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (mode == 'self') _selfCard(scheme, score, submission) else _summaryCard(scheme, stats),
        const SizedBox(height: 16),
        _statsGrid(scheme, stats, score),
        const SizedBox(height: 20),
        Text('Assignment Question', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface)),
        const SizedBox(height: 8),
        _filesSection(scheme, files, emptyText: 'No file uploaded by the teacher.'),
        if (mode == 'self') ...[
          const SizedBox(height: 20),
          Text('Your Submitted Solution', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface)),
          const SizedBox(height: 8),
          submission != null && submission['file'] != null
              ? _filesSection(scheme, [Map<String, dynamic>.from(submission['file'])], emptyText: '')
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
                  child: Text('No submission made yet.', style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
        ],
      ],
    );
  }

  Widget _selfCard(ColorScheme scheme, Map<String, dynamic>? score, Map<String, dynamic>? submission) {
    if (score == null) {
      final status = submission != null ? '${submission['status'] ?? 'Submitted'}' : 'Not submitted';
      return Container(
        decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.hourglass_empty, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(status, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
            if (submission != null) ...[
              const SizedBox(height: 6),
              Text('Submitted ${_formatDate(submission['submittedAt'])}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('Awaiting grading', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      );
    }

    final pct = _asNum(score['pct']).toDouble();
    final color = _scoreColor(pct);
    final mark = _asNum(score['mark']);
    final position = score['position'];
    final outOf = score['outOf'];

    return Container(
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                    value: (pct / 100).clamp(0, 1),
                    strokeWidth: 9,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: scheme.onSurface)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('$mark / ${_asNum(_data!['assignment']['totalScore'])} pts', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          if (position != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text('Position $position of $outOf', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ),
          ],
          if (score['feedback'] != null && '${score['feedback']}'.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Feedback', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 4),
            Text('${score['feedback']}', style: TextStyle(fontSize: 12, color: scheme.onSurface)),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_available_outlined, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('Graded ${_formatDate(score['gradedAt'])}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(ColorScheme scheme, Map<String, dynamic> stats) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 40, color: AppColors.primary),
          const SizedBox(height: 10),
          Text('Class Assignment Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface)),
          const SizedBox(height: 4),
          Text('${stats['totalSubmitted'] ?? 0} submitted · ${stats['gradedCount'] ?? 0} graded',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _statsGrid(ColorScheme scheme, Map<String, dynamic> stats, Map<String, dynamic>? score) {
    final avgPct = stats['avgPct'];
    return Row(
      children: [
        Expanded(child: _statChip('Submissions', '${stats['totalSubmitted'] ?? 0}', AppColors.primary, scheme)),
        const SizedBox(width: 8),
        Expanded(child: _statChip('Passed', stats['passedPct'] != null ? '${stats['passedPct']}%' : '—', AppColors.success, scheme)),
        const SizedBox(width: 8),
        Expanded(child: _statChip('Average', avgPct != null ? '$avgPct%' : '—', AppColors.warning, scheme)),
        const SizedBox(width: 8),
        Expanded(
          child: _statChip(
            'Position',
            score != null && score['position'] != null ? '${score['position']}/${score['outOf']}' : '—',
            AppColors.secondary,
            scheme,
          ),
        ),
      ],
    );
  }

  Widget _statChip(String label, String value, Color color, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _filesSection(ColorScheme scheme, List<Map<String, dynamic>> files, {required String emptyText}) {
    if (files.isEmpty) {
      if (emptyText.isEmpty) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
        child: Text(emptyText, style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }
    return Column(children: [for (final f in files) _fileTile(scheme, f)]);
  }

  Widget _fileTile(ColorScheme scheme, Map<String, dynamic> f) {
    final ext = '${f['ext'] ?? ''}';
    final url = '${f['url'] ?? ''}';
    final style = _fileTypeStyle(ext);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _openUrl(context, url),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(style.icon, color: style.color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  url.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.open_in_new, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
