import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Horizontal school-switcher tabs shown above Notices/Announcements/Wall
/// when the account can see more than one school (own school for
/// Students/Teachers, plus each linked child's active-admission school for
/// Parents / parent-flagged staff). Hidden entirely when there's only one.
class SchoolTabBar extends StatelessWidget {
  final List<Map<String, dynamic>> schools;
  final int activeSchoolId;
  final ValueChanged<int> onSelected;

  const SchoolTabBar({
    super.key,
    required this.schools,
    required this.activeSchoolId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (schools.length < 2) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: schools.length,
          itemBuilder: (context, i) {
            final s = schools[i];
            final schId = (s['schId'] as num).toInt();
            final selected = schId == activeSchoolId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${s['schName'] ?? 'School'}'),
                selected: selected,
                onSelected: (_) => onSelected(schId),
                selectedColor: AppColors.primary,
                backgroundColor:
                    Theme.of(context).cardTheme.color ?? scheme.surface,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide.none,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
