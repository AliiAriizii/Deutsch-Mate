import 'package:flutter/material.dart';

import '../../core/constants/app_data.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';

/// Sentinel for "no filter".
const kAllLessons = '__all__';

/// Lesson filter shared by the three drill screens, which each had their own
/// copy of this dropdown with slightly different styling.
class LessonFilter extends StatelessWidget {
  const LessonFilter({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    final titles = [
      kAllLessons,
      ...AppData.lessons.map((l) => l['title']?.toString() ?? ''),
    ];

    return AppCard(
      padding: EdgeInsetsDirectional.only(
        start: spacing.lg,
        end: spacing.sm,
        top: spacing.xxs,
        bottom: spacing.xxs,
      ),
      background: context.colors.surface,
      child: Row(
        children: [
          const PlateLabel('محدوده'),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              onChanged: (v) => v == null ? null : onChanged(v),
              dropdownColor: colors.card,
              borderRadius: context.radii.controlBorder,
              style: context.texts.bodyMedium,
              icon: Icon(
                Icons.expand_more,
                size: 18,
                color: colors.textSecondary,
              ),
              items: [
                for (final t in titles)
                  DropdownMenuItem(
                    value: t,
                    child: Text(t == kAllLessons ? 'همه درس‌ها' : t),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
