import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../screens/quiz_score_screen.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'lesson_discussion_section.dart';

class _FileTypeStyle {
  final IconData icon;
  final Color color;
  const _FileTypeStyle(this.icon, this.color);
}

_FileTypeStyle _fileTypeStyle(String nameOrType) {
  final ext = nameOrType.toLowerCase().split('.').last;
  switch (ext) {
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

String? _youtubeThumbnail(String url) {
  final match = RegExp(
    r'(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([A-Za-z0-9_-]{11})',
  ).firstMatch(url);
  if (match == null) return null;
  return 'https://img.youtube.com/vi/${match.group(1)}/mqdefault.jpg';
}

Future<void> _openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }
}

/// Renders a lesson's full detail inline: info card, horizontal Files/Videos/
/// Referrals/Assessments cards, and the interactive Lesson Discussion section.
/// Used directly inside the day-view screen (no separate navigation needed).
class LessonDetailContent extends StatefulWidget {
  final int lessonId;
  final String? classroomName;

  const LessonDetailContent({super.key, required this.lessonId, this.classroomName});

  @override
  State<LessonDetailContent> createState() => _LessonDetailContentState();
}

class _LessonDetailContentState extends State<LessonDetailContent> {
  late ApiClient _client;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _lesson = {};
  List<Map<String, dynamic>> _files = [];
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _links = [];
  List<Map<String, dynamic>> _assessments = [];
  List<Map<String, dynamic>> _discussion = [];

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
      final body = await _client.getLessonDetail(widget.lessonId);
      setState(() {
        _lesson = Map<String, dynamic>.from(body['lesson'] ?? {});
        _files = List<Map<String, dynamic>>.from(body['files'] ?? []);
        _videos = List<Map<String, dynamic>>.from(body['videos'] ?? []);
        _links = List<Map<String, dynamic>>.from(body['links'] ?? []);
        _assessments = List<Map<String, dynamic>>.from(body['assessments'] ?? []);
        _discussion = List<Map<String, dynamic>>.from(body['discussion'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Widget _infoCard(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_lesson['title'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if ((_lesson['desc'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${_lesson['desc']}', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if ((_lesson['duration'] ?? '').toString().isNotEmpty)
                _infoChip(scheme, Icons.schedule, '${_lesson['duration']}'),
              if ((_lesson['status'] ?? '').toString().isNotEmpty)
                _infoChip(scheme, Icons.flag_outlined, '${_lesson['status']}'),
              if ((_lesson['levelName'] ?? '').toString().isNotEmpty)
                _infoChip(scheme, Icons.school_outlined, '${_lesson['levelName']}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(ColorScheme scheme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _sectionHeader(ColorScheme scheme, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _horizontalSection(ColorScheme scheme, String title, List<Map<String, dynamic>> items, Widget Function(Map<String, dynamic>) tileBuilder) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(scheme, title, items.length),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => tileBuilder(items[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileTile(ColorScheme scheme, Map<String, dynamic> f) {
    final name = '${f['name'] ?? ''}';
    final style = _fileTypeStyle((f['type'] ?? name).toString());
    return GestureDetector(
      onTap: () => _openUrl(context, ApiConfig.lessonFileUrl('${f['path'] ?? ''}')),
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(style.icon, color: style.color, size: 32),
            const Spacer(),
            Text(
              name.isEmpty ? 'File' : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoTile(ColorScheme scheme, Map<String, dynamic> v) {
    final url = '${v['url'] ?? ''}';
    final thumb = _youtubeThumbnail(url);
    final title = '${v['title'] ?? ''}';
    return GestureDetector(
      onTap: () => _openUrl(context, url),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumb != null
                      ? Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            color: Colors.black12,
                            child: const Icon(Icons.videocam_outlined, size: 32),
                          ),
                        )
                      : Container(color: Colors.black12, child: const Icon(Icons.videocam_outlined, size: 32)),
                  const Center(
                    child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                title.isEmpty ? 'Video' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkTile(ColorScheme scheme, Map<String, dynamic> l) {
    final url = '${l['url'] ?? ''}';
    final title = '${l['title'] ?? ''}';
    final favicon = url.isNotEmpty ? 'https://www.google.com/s2/favicons?domain=$url&sz=64' : null;
    return GestureDetector(
      onTap: () => _openUrl(context, url),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: favicon != null
                  ? Image.network(
                      favicon,
                      width: 28,
                      height: 28,
                      errorBuilder: (context, error, stack) => const Icon(Icons.link, size: 28),
                    )
                  : const Icon(Icons.link, size: 28),
            ),
            const Spacer(),
            Text(
              title.isEmpty ? url : title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assessmentTile(ColorScheme scheme, Map<String, dynamic> a) {
    final quizId = (a['id'] is num) ? (a['id'] as num).toInt() : (int.tryParse('${a['id']}') ?? 0);
    final quizName = '${a['name'] ?? ''}';
    return Container(
      width: 130,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.quiz_outlined, color: AppColors.primary, size: 28),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, size: 18, color: scheme.onSurfaceVariant),
                onSelected: (value) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => QuizScoreScreen(quizId: quizId, quizName: quizName, autoDownload: value == 'download'),
                  ));
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'view', child: Text('View Score')),
                  PopupMenuItem(value: 'download', child: Text('Download Script')),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(
            quizName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            [if ((a['type'] ?? '').toString().isNotEmpty) '${a['type']}', if ((a['duration'] ?? 0) > 0) '${a['duration']} min']
                .join(' · '),
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Failed to load lesson: $_error')),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoCard(scheme),
        _horizontalSection(scheme, 'Lesson Files', _files, (f) => _fileTile(scheme, f)),
        _horizontalSection(scheme, 'Lesson Videos', _videos, (v) => _videoTile(scheme, v)),
        _horizontalSection(scheme, 'Lesson Referrals', _links, (l) => _linkTile(scheme, l)),
        _horizontalSection(scheme, 'Assessments', _assessments, (a) => _assessmentTile(scheme, a)),
        const SizedBox(height: 14),
        LessonDiscussionSection(
          client: _client,
          lessonId: widget.lessonId,
          initialDiscussions: _discussion,
        ),
      ],
    );
  }
}
