import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';

String _grade(double pct) {
  if (pct >= 90) return 'A+';
  if (pct >= 80) return 'A';
  if (pct >= 70) return 'B';
  if (pct >= 50) return 'C';
  return 'F';
}

Color _gradeColor(String g) {
  if (g.startsWith('A')) return AppColors.success;
  if (g == 'B') return AppColors.primary;
  if (g == 'C') return AppColors.warning;
  return AppColors.danger;
}

PdfColor _gradeColorPdf(String g) {
  if (g.startsWith('A')) return PdfColors.green800;
  if (g == 'B') return PdfColors.blue800;
  if (g == 'C') return PdfColors.orange800;
  return PdfColors.red800;
}

String _fmtDate(dynamic raw) {
  final s = '${raw ?? ''}';
  if (s.isEmpty) return '';
  final dt = DateTime.tryParse(s);
  if (dt == null) return s;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String _fmtDateTime(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '${dt.day} ${months[dt.month - 1]} ${dt.year} at $hour12:${dt.minute.toString().padLeft(2, '0')} $period';
}

num _asNum(dynamic v) => (v is num) ? v : (num.tryParse('$v') ?? 0);

/// Displays a term's published report card (or a "not yet posted" message).
/// Individual `term_exam_def` rows within a term all open this same screen —
/// "published" is only tracked per (class, term) in the schema, not per exam.
class ExamReportCardScreen extends StatefulWidget {
  final Map<String, dynamic> classroom;
  final String examName;
  final String studentName;
  final String studentPhoto;
  final String termLabel;
  final int term;
  final Map<String, dynamic> termData;

  const ExamReportCardScreen({
    super.key,
    required this.classroom,
    required this.examName,
    required this.studentName,
    required this.studentPhoto,
    required this.termLabel,
    required this.term,
    required this.termData,
  });

  @override
  State<ExamReportCardScreen> createState() => _ExamReportCardScreenState();
}

class _ExamReportCardScreenState extends State<ExamReportCardScreen> {
  bool _generatingPdf = false;

  bool get _published => widget.termData['published'] == true;
  Map<String, dynamic> get _report => Map<String, dynamic>.from(widget.termData['report'] ?? {});
  Map<String, dynamic> get _stats => Map<String, dynamic>.from(widget.termData['stats'] ?? {});
  String get _verifyUrl => '${widget.termData['verifyUrl'] ?? ''}';

  double? get _overallPct {
    final v = _report['overall_pct'];
    return v == null ? null : _asNum(v).toDouble();
  }

  Future<Uint8List?> _fetchBytes(String url) async {
    if (url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  Future<void> _downloadPdf() async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildPdf().timeout(const Duration(seconds: 25));
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'report_card_term${widget.term}_${widget.studentName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Could not generate the PDF. Please check your connection and try again.');
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<Uint8List> _buildPdf() async {
    final c = widget.classroom;
    final schoolLogoUrl = ApiConfig.schoolLogoUrl('${c['schoolLogo'] ?? ''}');
    final studentPhotoUrl = ApiConfig.photoUrl(widget.studentPhoto);

    final results = await Future.wait([
      _fetchBytes(schoolLogoUrl),
      _fetchBytes(studentPhotoUrl),
      rootBundle.load('assets/images/icon.png').then((d) => d.buffer.asUint8List()),
    ]);
    final schoolLogoBytes = results[0];
    final studentPhotoBytes = results[1];
    final navuliLogoBytes = results[2]!;

    final marks = List<Map<String, dynamic>>.from(_report['marks'] ?? []);
    final totalE = _asNum(_report['total_earned']).toDouble();
    final totalP = _asNum(_report['total_possible']).toDouble();
    final ovPct = _overallPct;
    final grade = ovPct != null ? _grade(ovPct) : null;
    final gColor = grade != null ? _gradeColorPdf(grade) : PdfColors.grey600;

    final contactParts = [
      '${c['schoolAddress'] ?? ''}',
      if ('${c['schoolPhone'] ?? ''}'.isNotEmpty) 'Ph: ${c['schoolPhone']}',
      '${c['schoolEmail'] ?? ''}',
    ].where((s) => s.isNotEmpty).join('  |  ');

    final statItems = <List<String>>[
      ['NO. SAT', '${_stats['number_sat'] ?? 0}'],
      ['PASS', '${_stats['number_pass'] ?? 0}'],
      ['FAIL', '${_stats['number_fail'] ?? 0}'],
      if (_asNum(_stats['number_absent'] ?? 0) > 0) ['ABSENT', '${_stats['number_absent']}'],
      ['PASS %', '${_stats['pct_pass'] ?? 0}%'],
      ['CLASS AVG', _stats['avg_score'] != null ? '${_stats['avg_score']}%' : '-'],
    ];

    final generatedLine = 'Generated by Navuli Fiji School Management System on ${_fmtDateTime(DateTime.now())}.';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue700, width: 1.2)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (schoolLogoBytes != null)
                    pw.Container(width: 50, height: 50, child: pw.Image(pw.MemoryImage(schoolLogoBytes), fit: pw.BoxFit.contain)),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text('${c['schoolName'] ?? ''}'.toUpperCase(),
                            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        pw.SizedBox(height: 3),
                        pw.Text('TERM ${widget.term} EXAMINATION REPORT CARD',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 2),
                        pw.Text('${c['className'] ?? ''} - ${c['classYear'] ?? ''}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        if (contactParts.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(contactParts, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                        ],
                      ],
                    ),
                  ),
                  pw.Container(width: 46, height: 46, child: pw.Image(pw.MemoryImage(navuliLogoBytes), fit: pw.BoxFit.contain)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.blue200, thickness: 1),
              pw.SizedBox(height: 10),

              // Student info + score box
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (studentPhotoBytes != null)
                    pw.Container(width: 56, height: 56, child: pw.Image(pw.MemoryImage(studentPhotoBytes), fit: pw.BoxFit.cover))
                  else
                    pw.Container(
                      width: 56,
                      height: 56,
                      alignment: pw.Alignment.center,
                      decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                      child: pw.Text(
                        widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : '?',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                      ),
                    ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _kv('Full Name', widget.studentName),
                        _kv('Class', '${c['className'] ?? ''}'),
                        _kv('Year', '${c['classYear'] ?? ''}'),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(color: PdfColors.grey300)),
                      child: pw.Column(
                        children: [
                          pw.Text('${totalE.toStringAsFixed(1)} / ${totalP.toStringAsFixed(1)}',
                              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: gColor)),
                          pw.SizedBox(height: 6),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                            children: [
                              if (_stats['position'] != null)
                                pw.Column(children: [
                                  pw.Text('${_stats['position']}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                                  pw.Text('POSITION', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                                ]),
                              pw.Column(children: [
                                pw.Text(grade ?? '-', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: gColor)),
                                pw.Text('GRADE', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                              ]),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // Subject table
              pw.Text('Subject Results', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3.2),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(0.9),
                  4: pw.FlexColumnWidth(0.9),
                  5: pw.FlexColumnWidth(2.4),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _th('Subject'), _th('Mark'), _th('Total'), _th('%'), _th('Grade'), _th('Comment'),
                    ],
                  ),
                  for (final m in marks) _markRow(m),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _td('Overall', bold: true),
                      _td(totalE.toStringAsFixed(1), bold: true, align: pw.TextAlign.center),
                      _td(totalP.toStringAsFixed(1), bold: true, align: pw.TextAlign.center),
                      _td(ovPct != null ? '$ovPct%' : '-', bold: true, align: pw.TextAlign.center),
                      _td(grade ?? '-', bold: true, align: pw.TextAlign.center, color: gColor),
                      _td('', align: pw.TextAlign.center),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('Grade Scale:  A+ >= 90%   A >= 80%   B >= 70%   C >= 50% (Pass)   F < 50% (Fail)',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              pw.SizedBox(height: 10),

              // Class stats
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('CLASS STATS', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                    for (final si in statItems)
                      pw.Column(children: [
                        pw.Text(si[1], style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text(si[0], style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                      ]),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Comments
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _commentBox('Class Teacher Comment', '${_report['ct_comment'] ?? ''}', PdfColors.blue50, PdfColors.blue200)),
                  pw.SizedBox(width: 8),
                  pw.Expanded(child: _commentBox('Principal Comment', '${_report['principal_comment'] ?? ''}', PdfColors.green50, PdfColors.green200)),
                ],
              ),
              pw.SizedBox(height: 10),

              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${c['schoolName'] ?? ''} | Term ${widget.term}, ${c['classYear'] ?? ''}'
                    '${_report['published_at'] != null ? ' | Published ${_fmtDate(_report['published_at'])}' : ''}',
                    style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey500),
                  ),
                  pw.Text('Parent/Guardian Signature: ________________', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey500)),
                ],
              ),
              pw.SizedBox(height: 10),

              pw.Center(
                child: pw.Column(
                  children: [
                    if (_verifyUrl.isNotEmpty) ...[
                      pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: _verifyUrl, width: 60, height: 60),
                      pw.SizedBox(height: 2),
                      pw.Text('Scan to verify', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
                      pw.SizedBox(height: 4),
                    ],
                    pw.Text(generatedLine, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey400)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _kv(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(children: [
          pw.SizedBox(width: 55, child: pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  pw.Widget _th(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _td(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(fontSize: 7.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      );

  pw.TableRow _markRow(Map<String, dynamic> m) {
    final mark = m['mark'];
    final total = _asNum(m['total_mark']).toDouble();
    final mp = (mark != null && total > 0) ? (( _asNum(mark).toDouble() / total) * 100).roundToDouble() : null;
    final mg = mp != null ? _grade(mp) : '-';
    return pw.TableRow(children: [
      _td('${m['subject_name'] ?? ''}'),
      _td(mark != null ? '$mark' : '-', align: pw.TextAlign.center, bold: true),
      _td('${m['total_mark'] ?? ''}', align: pw.TextAlign.center),
      _td(mp != null ? '$mp%' : '-', align: pw.TextAlign.center),
      _td(mg, align: pw.TextAlign.center, bold: true, color: mp != null ? _gradeColorPdf(mg) : PdfColors.grey500),
      _td('${m['teacher_comment'] ?? ''}'),
    ]);
  }

  pw.Widget _commentBox(String title, String text, PdfColor bg, PdfColor border) => pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(color: bg, border: pw.Border.all(color: border)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(text.isNotEmpty ? text : 'No comment.', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_published)
            IconButton(
              tooltip: 'Print / PDF',
              icon: _generatingPdf
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _generatingPdf ? null : _downloadPdf,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !_published
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_empty_rounded, size: 48, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('${widget.termLabel} ${widget.term} results have not been published yet.',
                          textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _headerCard(scheme),
                  const SizedBox(height: 14),
                  _studentInfoCard(scheme),
                  const SizedBox(height: 14),
                  _subjectsCard(scheme),
                  const SizedBox(height: 14),
                  _classStatsStrip(scheme),
                  const SizedBox(height: 14),
                  _commentCard(scheme, 'Class Teacher Comment', '${_report['ct_comment'] ?? ''}', AppColors.primary),
                  const SizedBox(height: 10),
                  _commentCard(scheme, 'Principal Comment', '${_report['principal_comment'] ?? ''}', AppColors.success),
                  const SizedBox(height: 14),
                  _footer(scheme),
                ],
              ),
      ),
    );
  }

  Widget _card(ColorScheme scheme, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );

  Widget _headerCard(ColorScheme scheme) {
    final c = widget.classroom;
    final logo = '${c['schoolLogo'] ?? ''}';
    final contactParts = [
      '${c['schoolAddress'] ?? ''}',
      if ('${c['schoolPhone'] ?? ''}'.isNotEmpty) 'Ph: ${c['schoolPhone']}',
      '${c['schoolEmail'] ?? ''}',
    ].where((s) => s.isNotEmpty).join('  |  ');

    return _card(
      scheme,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: logo.isNotEmpty
                ? Image.network(ApiConfig.schoolLogoUrl(logo), width: 46, height: 46, fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Image.asset('assets/images/icon.png', width: 46, height: 46))
                : Image.asset('assets/images/icon.png', width: 46, height: 46),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('${c['schoolName'] ?? ''}'.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                const SizedBox(height: 4),
                Text('TERM ${widget.term} EXAMINATION REPORT CARD',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text('${c['className'] ?? ''} — ${c['classYear'] ?? ''}',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                if (contactParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(contactParts, textAlign: TextAlign.center, style: TextStyle(fontSize: 8.5, color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentInfoCard(ColorScheme scheme) {
    final c = widget.classroom;
    final totalE = _asNum(_report['total_earned']).toDouble();
    final totalP = _asNum(_report['total_possible']).toDouble();
    final ovPct = _overallPct;
    final grade = ovPct != null ? _grade(ovPct) : null;
    final gColor = grade != null ? _gradeColor(grade) : scheme.onSurfaceVariant;
    final photo = widget.studentPhoto;

    return _card(
      scheme,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: photo.isNotEmpty
                ? Image.network(ApiConfig.photoUrl(photo), width: 64, height: 64, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _initialsAvatar())
                : _initialsAvatar(),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labelValue('Full Name', widget.studentName),
                _labelValue('Class', '${c['className'] ?? ''}'),
                _labelValue('Year', '${c['classYear'] ?? ''}'),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text('${totalE.toStringAsFixed(1)} / ${totalP.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: gColor)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (_stats['position'] != null)
                        Column(children: [
                          Text('${_stats['position']}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
                          Text('POSITION', style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant)),
                        ]),
                      Column(children: [
                        Text(grade ?? '—', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: gColor)),
                        Text('GRADE', style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant)),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialsAvatar() => Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        color: AppColors.primary.withValues(alpha: 0.12),
        child: Text(
          widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
      );

  Widget _labelValue(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
            children: [
              TextSpan(text: '$label  ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
              TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  Widget _subjectsCard(ColorScheme scheme) {
    final marks = List<Map<String, dynamic>>.from(_report['marks'] ?? []);
    final totalE = _asNum(_report['total_earned']).toDouble();
    final totalP = _asNum(_report['total_possible']).toDouble();
    final ovPct = _overallPct;
    final grade = ovPct != null ? _grade(ovPct) : null;

    return _card(
      scheme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Subject Results', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (marks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No marks recorded.', style: TextStyle(color: scheme.onSurfaceVariant))),
            )
          else
            for (final m in marks) _subjectRow(scheme, m),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Overall', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                Text('${totalE.toStringAsFixed(1)} / ${totalP.toStringAsFixed(1)}  ·  ${ovPct != null ? '$ovPct%' : '—'}'
                    '${grade != null ? '  ·  $grade' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('Grade Scale:  A+ ≥ 90%  ·  A ≥ 80%  ·  B ≥ 70%  ·  C ≥ 50% (Pass)  ·  F < 50% (Fail)',
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _subjectRow(ColorScheme scheme, Map<String, dynamic> m) {
    final mark = m['mark'];
    final total = _asNum(m['total_mark']).toDouble();
    final mp = (mark != null && total > 0) ? ((_asNum(mark).toDouble() / total) * 100).round() : null;
    final mg = mp != null ? _grade(mp.toDouble()) : null;
    final comment = '${m['teacher_comment'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('${m['subject_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
              if (mg != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _gradeColor(mg).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(mg, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _gradeColor(mg))),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            mark != null ? '$mark / ${m['total_mark']} (${mp ?? '—'}%)' : 'Not recorded',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(comment, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  Widget _classStatsStrip(ColorScheme scheme) {
    final st = _stats;
    final items = <List<String>>[
      ['SAT', '${st['number_sat'] ?? 0}'],
      ['PASS', '${st['number_pass'] ?? 0}'],
      ['FAIL', '${st['number_fail'] ?? 0}'],
      if (_asNum(st['number_absent'] ?? 0) > 0) ['ABSENT', '${st['number_absent']}'],
      ['PASS %', '${st['pct_pass'] ?? 0}%'],
      ['CLASS AVG', st['avg_score'] != null ? '${st['avg_score']}%' : '—'],
    ];
    return _card(
      scheme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CLASS STATS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              for (final it in items)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it[1], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text(it[0], style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _commentCard(ColorScheme scheme, String title, String text, Color accent) {
    return _card(
      scheme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 14, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(text.isNotEmpty ? text : 'No comment.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontStyle: text.isEmpty ? FontStyle.italic : FontStyle.normal)),
        ],
      ),
    );
  }

  Widget _footer(ColorScheme scheme) {
    final c = widget.classroom;
    final publishedAt = _report['published_at'];
    return Center(
      child: Text(
        '${c['schoolName'] ?? ''} · ${widget.termLabel} ${widget.term}, ${c['classYear'] ?? ''}'
        '${publishedAt != null ? ' · Published ${_fmtDate(publishedAt)}' : ''}',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
