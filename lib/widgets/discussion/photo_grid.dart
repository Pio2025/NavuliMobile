import 'package:flutter/material.dart';

/// Facebook-style photo tiling: 1 photo full-bleed, 2 side-by-side, 3 asymmetric
/// (one large + two stacked), 4 as a 2x2 grid, and 5+ as a 2x2 grid where the
/// last visible tile gets a "+N" overlay for the remaining overflow photos.
class DiscussionPhotoGrid extends StatelessWidget {
  final List<String> photoUrls;
  final void Function(int index) onTapPhoto;

  const DiscussionPhotoGrid({
    super.key,
    required this.photoUrls,
    required this.onTapPhoto,
  });

  Widget _tile(BuildContext context, int index, {BoxFit fit = BoxFit.cover, int? overlayCount}) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onTapPhoto(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            photoUrls[index],
            fit: fit,
            errorBuilder: (context, error, stack) => Container(
              color: scheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
          if (overlayCount != null && overlayCount > 0)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              alignment: Alignment.center,
              child: Text(
                '+$overlayCount',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = photoUrls.length;
    if (count == 0) return const SizedBox.shrink();

    const gap = 4.0;
    const radius = 10.0;

    if (count == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: _tile(context, 0),
        ),
      );
    }

    if (count == 2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          height: 180,
          child: Row(
            children: [
              Expanded(child: _tile(context, 0)),
              const SizedBox(width: gap),
              Expanded(child: _tile(context, 1)),
            ],
          ),
        ),
      );
    }

    if (count == 3) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          height: 220,
          child: Row(
            children: [
              Expanded(child: _tile(context, 0)),
              const SizedBox(width: gap),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _tile(context, 1)),
                    const SizedBox(height: gap),
                    Expanded(child: _tile(context, 2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 4 or more: 2x2 grid, with a "+N" overlay on the last visible tile when there's overflow.
    final overflow = count - 4;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: 220,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _tile(context, 0)),
                  const SizedBox(width: gap),
                  Expanded(child: _tile(context, 1)),
                ],
              ),
            ),
            const SizedBox(height: gap),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _tile(context, 2)),
                  const SizedBox(width: gap),
                  Expanded(child: _tile(context, 3, overlayCount: overflow > 0 ? overflow : null)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
