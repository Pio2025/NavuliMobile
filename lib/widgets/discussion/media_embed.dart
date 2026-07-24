import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import 'video_player_screen.dart';
import 'youtube_player_screen.dart';

final RegExp _urlPattern = RegExp(r'https?://[^\s]+');
final RegExp _youtubePattern = RegExp(
  r'(?:youtube\.com/(?:watch\?v=|shorts/|embed/)|youtu\.be/)([a-zA-Z0-9_-]{6,})',
  caseSensitive: false,
);
final RegExp _videoFilePattern = RegExp(r'\.(mp4|mov|webm|m3u8)(\?.*)?$', caseSensitive: false);

/// Extracts http(s) URLs from free-form post text, trimming common trailing
/// punctuation that isn't actually part of the link.
List<String> extractUrls(String text) {
  return _urlPattern
      .allMatches(text)
      .map((m) => m.group(0)!.replaceAll(RegExp(r'[),.!?]+$'), ''))
      .where((u) => u.isNotEmpty)
      .toList();
}

String? _youtubeId(String url) => _youtubePattern.firstMatch(url)?.group(1);

bool _isDirectVideo(String url) => _videoFilePattern.hasMatch(Uri.parse(url).path);

/// Renders a single embedded URL as a tappable card: an in-app YouTube player
/// thumbnail, a direct-video-file card (opens a Chewie player), or a generic
/// link card that opens externally via url_launcher.
class DiscussionMediaEmbed extends StatelessWidget {
  final String url;

  const DiscussionMediaEmbed({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final youtubeId = _youtubeId(url);
    if (youtubeId != null) {
      return _YoutubeCard(url: url, videoId: youtubeId);
    }
    if (_isDirectVideo(url)) {
      return _VideoFileCard(url: url);
    }
    return _LinkCard(url: url);
  }
}

class _YoutubeCard extends StatelessWidget {
  final String url;
  final String videoId;

  const _YoutubeCard({required this.url, required this.videoId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => YoutubePlayerScreen(videoId: videoId), fullscreenDialog: true),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: scheme.surfaceContainerHighest,
                  child: const Icon(Icons.smart_display_outlined, size: 40),
                ),
              ),
              Container(color: Colors.black.withValues(alpha: 0.15)),
              const Center(
                child: Icon(Icons.play_circle_fill, size: 56, color: Colors.white),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
                  child: const Text('YouTube', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoFileCard extends StatelessWidget {
  final String url;

  const _VideoFileCard({required this.url});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: url), fullscreenDialog: true),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_outline, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final String url;

  const _LinkCard({required this.url});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final host = Uri.tryParse(url)?.host ?? url;
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.link, color: scheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(host, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
