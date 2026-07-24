import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../theme/app_theme.dart';

int asInt(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

void showReactionsSheet(BuildContext context, Future<List<Map<String, dynamic>>> Function() loader) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReactionsSheet(loader: loader),
  );
}

class ReactionsSheet extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> Function() loader;

  const ReactionsSheet({super.key, required this.loader});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Reactions', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Flexible(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: loader(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('${snapshot.error}', style: TextStyle(color: scheme.error))),
                  );
                }
                final reactions = snapshot.data ?? [];
                if (reactions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No reactions yet.', style: TextStyle(color: scheme.onSurfaceVariant))),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: reactions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = reactions[i];
                    final isLike = '${r['type']}' == 'like';
                    final photo = '${r['photo'] ?? ''}';
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        backgroundImage: photo.isNotEmpty ? NetworkImage(ApiConfig.photoUrl(photo)) : null,
                        child: photo.isEmpty ? const Icon(Icons.person, color: AppColors.primary, size: 16) : null,
                      ),
                      title: Text('${r['name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: Icon(
                        isLike ? Icons.thumb_up : Icons.thumb_down,
                        size: 16,
                        color: isLike ? AppColors.primary : AppColors.danger,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        ),
      ),
    );
  }
}

Map<String, dynamic> cloneReply(Map<String, dynamic> r) => {
      ...Map<String, dynamic>.from(r),
      'replies': List<Map<String, dynamic>>.from(
          (r['replies'] as List? ?? []).map((x) => cloneReply(Map<String, dynamic>.from(x)))),
    };

Map<String, dynamic> cloneComment(Map<String, dynamic> c) => {
      ...Map<String, dynamic>.from(c),
      'replies': List<Map<String, dynamic>>.from(
          (c['replies'] as List? ?? []).map((r) => cloneReply(Map<String, dynamic>.from(r)))),
    };

Map<String, dynamic> clonePost(Map<String, dynamic> p) => {
      ...Map<String, dynamic>.from(p),
      'photos': List<Map<String, dynamic>>.from(
          (p['photos'] as List? ?? []).map((x) => Map<String, dynamic>.from(x))),
      'comments': List<Map<String, dynamic>>.from(
          (p['comments'] as List? ?? []).map((c) => cloneComment(Map<String, dynamic>.from(c)))),
    };

class ImageViewerScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const ImageViewerScreen({super.key, required this.urls, required this.initialIndex});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pageCtrl = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_index + 1} / ${widget.urls.length}'),
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          child: Center(
            child: Image.network(
              widget.urls[i],
              errorBuilder: (context, error, stack) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
