import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

num _asNum(dynamic v) => (v is num) ? v : (num.tryParse('$v') ?? 0);
int _asInt(dynamic v) => _asNum(v).toInt();

class QuizScoreScreen extends StatefulWidget {
  final int quizId;
  final String quizName;
  final bool autoDownload;
  final int? childId;

  const QuizScoreScreen({super.key, required this.quizId, required this.quizName, this.autoDownload = false, this.childId});

  @override
  State<QuizScoreScreen> createState() => _QuizScoreScreenState();
}

class _QuizScoreScreenState extends State<QuizScoreScreen> {
  late ApiClient _client;
  bool _loading = true;
  bool _generatingPdf = false;
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
      final body = await _client.getLessonQuizScore(widget.quizId, childId: widget.childId);
      setState(() {
        _data = body;
        _loading = false;
      });
      if (widget.autoDownload && body['success'] == true) {
        _downloadScript();
      }
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

  Future<void> _downloadScript() async {
    if (_data == null || _generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildTranscriptPdf(_data!, context.read<AuthService>().user?.name ?? '');
      if (!mounted) return;
      await Printing.sharePdf(bytes: bytes, filename: 'quiz-transcript-${widget.quizId}.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate transcript: $e')));
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_data != null && _data!['success'] == true)
            IconButton(
              tooltip: 'Download Script',
              icon: _generatingPdf
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _generatingPdf ? null : _downloadScript,
            ),
        ],
      ),
      body: _loading
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
                            Icon(Icons.quiz_outlined, size: 48, color: scheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              '${_data?['message'] ?? 'No completed attempt found.'}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _scoreBody(scheme),
                    ),
    );
  }

  Widget _scoreBody(ColorScheme scheme) {
    final attempt = Map<String, dynamic>.from(_data!['attempt'] ?? {});
    final questions = List<Map<String, dynamic>>.from(_data!['questions'] ?? []);
    final score = _asNum(attempt['score']).toDouble();
    final correct = _asInt(attempt['correct']);
    final total = _asInt(attempt['total']);
    final unanswered = _asInt(attempt['unanswered']);
    final incorrect = total - correct - unanswered;
    final statusLabel = '${attempt['statusLabel'] ?? ''}';
    final submittedAt = _formatDate(attempt['submittedAt']);
    final color = _scoreColor(score);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
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
                        value: (score / 100).clamp(0, 1),
                        strokeWidth: 9,
                        backgroundColor: scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    Text('${score.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('$correct / $total Correct', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _statChip('Questions', total, AppColors.primary, scheme)),
                  const SizedBox(width: 8),
                  Expanded(child: _statChip('Correct', correct, AppColors.success, scheme)),
                  const SizedBox(width: 8),
                  Expanded(child: _statChip('Incorrect', incorrect, AppColors.danger, scheme)),
                  const SizedBox(width: 8),
                  Expanded(child: _statChip('Unanswered', unanswered, AppColors.warning, scheme)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.event_available_outlined, size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('Submitted $submittedAt', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Question Review', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface)),
        Text('${questions.where((q) => q['isAnswered'] == true).length} of $total questions answered',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        for (var i = 0; i < questions.length; i++) _questionCard(scheme, i + 1, questions[i]),
      ],
    );
  }

  Widget _statChip(String label, int value, Color color, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _questionCard(ColorScheme scheme, int index, Map<String, dynamic> q) {
    final isAnswered = q['isAnswered'] == true;
    final isCorrect = q['isCorrect'] == true;
    final borderColor = !isAnswered ? scheme.outlineVariant : (isCorrect ? AppColors.success : AppColors.danger);
    final bgColor = !isAnswered ? null : (isCorrect ? AppColors.success : AppColors.danger).withValues(alpha: 0.06);
    final answers = List<Map<String, dynamic>>.from(q['answers'] ?? []);
    final files = List<Map<String, dynamic>>.from(q['files'] ?? []);
    final letters = ['A', 'B', 'C', 'D', 'E', 'F'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
        color: bgColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !isAnswered ? scheme.surfaceContainerHighest : (isCorrect ? AppColors.success : AppColors.danger),
                  shape: BoxShape.circle,
                ),
                child: Text('$index',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: !isAnswered ? scheme.onSurfaceVariant : Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${q['question'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (!isAnswered ? scheme.outlineVariant : (isCorrect ? AppColors.success : AppColors.danger))
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        !isAnswered ? 'Not answered' : (isCorrect ? 'Correct' : 'Incorrect'),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: !isAnswered ? scheme.onSurfaceVariant : (isCorrect ? AppColors.success : AppColors.danger)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (files.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: files.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network('${files[i]['url']}', height: 90, width: 140, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                            height: 90,
                            width: 140,
                            color: scheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined),
                          )),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (var ai = 0; ai < answers.length; ai++) _answerRow(scheme, letters, ai, answers[ai]),
        ],
      ),
    );
  }

  Widget _answerRow(ColorScheme scheme, List<String> letters, int ai, Map<String, dynamic> ans) {
    final isRight = ans['isCorrect'] == true;
    final isSelected = ans['isSelected'] == true;
    final bg = isRight ? AppColors.success.withValues(alpha: 0.10) : (isSelected ? AppColors.danger.withValues(alpha: 0.10) : null);
    final border = isRight ? AppColors.success : (isSelected ? AppColors.danger : scheme.outlineVariant);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isRight ? AppColors.success : scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text(ai < letters.length ? letters[ai] : '${ai + 1}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isRight ? Colors.white : scheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${ans['answer'] ?? ''}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: isRight ? FontWeight.w700 : FontWeight.w400,
                    color: isRight ? AppColors.success : (isSelected ? AppColors.danger : scheme.onSurface))),
          ),
          if (isRight) const Icon(Icons.check_circle, size: 16, color: AppColors.success),
          if (isSelected && !isRight) const Icon(Icons.cancel, size: 16, color: AppColors.danger),
        ],
      ),
    );
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

Future<Uint8List> _buildTranscriptPdf(Map<String, dynamic> data, String studentName) async {
  final quiz = Map<String, dynamic>.from(data['quiz'] ?? {});
  final lesson = Map<String, dynamic>.from(data['lesson'] ?? {});
  final attempt = Map<String, dynamic>.from(data['attempt'] ?? {});
  final questions = List<Map<String, dynamic>>.from(data['questions'] ?? []);

  final score = _asNum(attempt['score']).toDouble();
  final correct = _asInt(attempt['correct']);
  final total = _asInt(attempt['total']);
  final unanswered = _asInt(attempt['unanswered']);
  final duration = _asInt(quiz['duration']);
  final scoreColor = score >= 80 ? PdfColors.green800 : (score >= 50 ? PdfColors.orange800 : PdfColors.red800);
  final letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('${quiz['name'] ?? ''}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text('Quiz Transcript — ${lesson['title'] ?? ''}', style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.blue400, thickness: 2),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(child: _metaRow('Student', studentName)),
            pw.Expanded(child: _metaRow('Status', '${attempt['statusLabel'] ?? ''}')),
          ],
        ),
        pw.Row(
          children: [
            pw.Expanded(child: _metaRow('Submitted', _formatDate(attempt['submittedAt']))),
            pw.Expanded(child: _metaRow('Duration', duration > 0 ? '$duration min' : 'No limit')),
          ],
        ),
        pw.Row(
          children: [
            pw.Expanded(child: _metaRow('Questions', '$total')),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border(left: pw.BorderSide(color: PdfColors.blue400, width: 4)),
          ),
          child: pw.Row(
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Final Score', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Text('${score.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: scoreColor)),
              ]),
              pw.SizedBox(width: 30),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Correct Answers', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Text('$correct / $total', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.SizedBox(width: 30),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Unanswered', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Text('$unanswered', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 18),
        for (var i = 0; i < questions.length; i++) _questionBlock(i + 1, questions[i], letters),
        pw.SizedBox(height: 16),
        pw.Divider(color: PdfColors.grey400),
        pw.Text('Generated on ${_formatDate(DateTime.now().toIso8601String())} — $studentName — ${quiz['name'] ?? ''}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _metaRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(children: [
      pw.SizedBox(width: 80, child: pw.Text('$label:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
      pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
    ]),
  );
}

pw.Widget _questionBlock(int index, Map<String, dynamic> q, List<String> letters) {
  final isAnswered = q['isAnswered'] == true;
  final isCorrect = q['isCorrect'] == true;
  final borderColor = !isAnswered ? PdfColors.grey400 : (isCorrect ? PdfColors.green700 : PdfColors.red700);
  final answers = List<Map<String, dynamic>>.from(q['answers'] ?? []);

  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        top: const pw.BorderSide(color: PdfColors.grey300),
        right: const pw.BorderSide(color: PdfColors.grey300),
        bottom: const pw.BorderSide(color: PdfColors.grey300),
        left: pw.BorderSide(color: borderColor, width: 3),
      ),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: const pw.BoxDecoration(color: PdfColors.blue400, borderRadius: pw.BorderRadius.all(pw.Radius.circular(3))),
            child: pw.Text('Q$index', style: const pw.TextStyle(fontSize: 9, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            !isAnswered ? 'Not Answered' : (isCorrect ? 'Correct' : 'Incorrect'),
            style: pw.TextStyle(fontSize: 9, color: !isAnswered ? PdfColors.grey600 : (isCorrect ? PdfColors.green700 : PdfColors.red700)),
          ),
        ]),
        pw.SizedBox(height: 6),
        pw.Text('${q['question'] ?? ''}', style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 6),
        for (var ai = 0; ai < answers.length; ai++) _answerLine(ai, answers[ai], letters),
      ],
    ),
  );
}

pw.Widget _answerLine(int ai, Map<String, dynamic> ans, List<String> letters) {
  final isRight = ans['isCorrect'] == true;
  final isSelected = ans['isSelected'] == true;
  final bg = isRight ? PdfColors.green50 : (isSelected ? PdfColors.red50 : null);
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 3),
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: pw.BoxDecoration(color: bg),
    child: pw.Row(
      children: [
        pw.SizedBox(width: 16, child: pw.Text('${ai < letters.length ? letters[ai] : ai + 1}.', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
        pw.Expanded(child: pw.Text('${ans['answer'] ?? ''}', style: const pw.TextStyle(fontSize: 9))),
        if (isSelected)
          pw.Text(isRight ? 'Your answer (Correct)' : 'Your answer', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        if (isRight && !isSelected)
          pw.Text('Correct answer', style: const pw.TextStyle(fontSize: 8, color: PdfColors.green700)),
      ],
    ),
  );
}
