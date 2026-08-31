import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_messages.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';

/// Target level, daily goal, interface language.
///
/// The target level is what seeds the start position in the content tree, so
/// someone beginning at B1.1 is never walked through A1.1.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _levels = ['A1.1', 'A1.2', 'A2.1', 'A2.2', 'B1.1', 'B1.2'];
  static const _goals = [10, 20, 30, 60];
  static const _languages = [
    (code: 'fa', label: 'فارسی'),
    (code: 'en', label: 'English'),
    (code: 'de', label: 'Deutsch'),
  ];

  String _level = 'A1.1';
  int _goal = 20;
  String _language = 'fa';
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    try {
      await widget.controller.completeOnboarding(
        targetLevel: _level,
        dailyGoalMinutes: _goal,
        interfaceLanguage: _language,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = AuthMessages.of(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final busy = widget.controller.busy;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.gutter,
            vertical: spacing.xl,
          ),
          children: [
            const PlateLabel('شروع'),
            SizedBox(height: spacing.sm),
            Text('مسیرت را بچین', style: context.texts.displaySmall),
            SizedBox(height: spacing.xs),
            Text(
              'بعداً می‌توانی همه اینها را عوض کنی.',
              style: context.texts.bodySmall,
            ),
            SizedBox(height: spacing.xl),

            SectionHeader(title: 'از کدام سطح شروع کنی', eyebrow: 'سطح هدف'),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: [
                for (final level in _levels)
                  _Choice(
                    label: level,
                    monospace: true,
                    selected: _level == level,
                    onTap: () => setState(() => _level = level),
                  ),
              ],
            ),
            SizedBox(height: spacing.xl),

            SectionHeader(title: 'هر روز چند دقیقه', eyebrow: 'هدف روزانه'),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: [
                for (final goal in _goals)
                  _Choice(
                    label: '$goal دقیقه',
                    selected: _goal == goal,
                    onTap: () => setState(() => _goal = goal),
                  ),
              ],
            ),
            SizedBox(height: spacing.xl),

            SectionHeader(title: 'زبان برنامه', eyebrow: 'نمایش'),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: [
                for (final lang in _languages)
                  _Choice(
                    label: lang.label,
                    selected: _language == lang.code,
                    onTap: () => setState(() => _language = lang.code),
                  ),
              ],
            ),
            SizedBox(height: spacing.xxl),

            if (_error != null) ...[
              Text(
                _error!,
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.error,
                ),
              ),
              SizedBox(height: spacing.md),
            ],

            FilledButton(
              onPressed: busy ? null : _submit,
              child: busy
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.textTertiary,
                      ),
                    )
                  : const Text('شروع یادگیری'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.monospace = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = monospace
        ? AppTypography.monoStyle(
            color: selected ? colors.accentSoft : colors.textSecondary,
            size: 15,
            weight: FontWeight.w600,
          )
        : context.texts.bodyMedium?.copyWith(
            color: selected ? colors.accentSoft : colors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : null,
          );

    return Material(
      color: Colors.transparent,
      borderRadius: context.radii.pillBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.radii.pillBorder,
        child: AnimatedContainer(
          duration: context.motion.resolve(context, context.motion.quick),
          curve: context.motion.curve,
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.lg,
            vertical: context.spacing.md,
          ),
          decoration: BoxDecoration(
            color: selected
                ? colors.accent.withValues(alpha: 0.14)
                : colors.card,
            borderRadius: context.radii.pillBorder,
            border: Border.all(
              color: selected ? colors.accent : colors.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(label, style: style),
        ),
      ),
    );
  }
}
