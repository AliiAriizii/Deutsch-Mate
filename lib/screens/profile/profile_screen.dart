import 'package:flutter/material.dart';

import '../../core/utils/audio_helper.dart';
import '../../main.dart' show ThemeScope;
import '../../theme/theme_controller.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';

/// Profile and settings.
///
/// Includes the one genuinely useful diagnostic on this screen: whether a
/// German voice is actually installed. If it is not, pronunciation is wrong and
/// the learner deserves to know rather than trusting what they hear.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Scaffold(
      appBar: AppBar(title: const Text('پروفایل')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          spacing.gutter,
          0,
          spacing.gutter,
          spacing.xxxl,
        ),
        children: [
          AppCard(
            child: Row(
              children: [
                // Initial in the display face, on a tinted square rather than
                // a coloured circle: quieter, and it matches the card language.
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.14),
                    borderRadius: context.radii.controlBorder,
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'A',
                    style: context.texts.headlineSmall?.copyWith(
                      color: colors.accentSoft,
                    ),
                  ),
                ),
                SizedBox(width: spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('حساب مهمان', style: context.texts.titleSmall),
                      SizedBox(height: spacing.xxs),
                      Text(
                        'هدف: A1.1 · روزی 20 دقیقه',
                        style: context.texts.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'ظاهر', eyebrow: 'تم'),
          const _ThemePicker(),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'گفتار', eyebrow: 'تلفظ'),
          const _VoiceStatusCard(),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'درباره', eyebrow: 'برنامه'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _InfoRow(label: 'سطح فعلی', value: 'A1.1'),
                Divider(height: 1, color: colors.hairline),
                _InfoRow(label: 'نسخه', value: '1.0.0'),
                Divider(height: 1, color: colors.hairline),
                _InfoRow(label: 'زبان برنامه', value: 'فارسی'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme choice. Dark is the default and the design target; the other two are
/// available rather than assumed.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  static const _options = [
    (mode: ThemeMode.dark, label: 'تیره', icon: Icons.dark_mode_outlined),
    (mode: ThemeMode.light, label: 'روشن', icon: Icons.light_mode_outlined),
    (mode: ThemeMode.system, label: 'سیستم', icon: Icons.contrast),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    final current = controller?.mode ?? ThemeController.defaultMode;
    final colors = context.colors;
    final spacing = context.spacing;

    return AppCard(
      padding: EdgeInsets.all(spacing.sm),
      child: Row(
        children: [
          for (final option in _options) ...[
            if (option != _options.first) SizedBox(width: spacing.xs),
            Expanded(
              child: _ThemeOption(
                label: option.label,
                icon: option.icon,
                selected: option.mode == current,
                // Disabled only if the controller is absent, which happens
                // just in tests that build the app without async setup.
                onTap: controller == null
                    ? null
                    : () => controller.set(option.mode),
                accent: colors.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedContainer(
      duration: context.motion.resolve(context, context.motion.quick),
      curve: context.motion.curve,
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.14) : colors.surface,
        borderRadius: context.radii.controlBorder,
        border: Border.all(
          color: selected ? accent : colors.hairline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: context.radii.controlBorder,
        child: InkWell(
          onTap: onTap,
          borderRadius: context.radii.controlBorder,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacing.md),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? colors.accentSoft : colors.textTertiary,
                ),
                SizedBox(height: context.spacing.xs),
                Text(
                  label,
                  style: context.texts.labelSmall?.copyWith(
                    color: selected ? colors.accentSoft : colors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reports whether German TTS is available, and what to do when it is not.
class _VoiceStatusCard extends StatefulWidget {
  const _VoiceStatusCard();

  @override
  State<_VoiceStatusCard> createState() => _VoiceStatusCardState();
}

class _VoiceStatusCardState extends State<_VoiceStatusCard> {
  bool _checking = true;
  bool _available = false;
  String? _voice;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // Speaking an empty string initialises the engine and resolves a voice
    // without making a sound.
    await AudioHelper.speakDe('');
    if (!mounted) return;
    setState(() {
      _checking = false;
      _available = AudioHelper.germanVoiceAvailable;
      _voice = AudioHelper.resolvedVoiceName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    if (_checking) {
      return AppCard(
        child: Text('در حال بررسی صدای آلمانی…', style: context.texts.bodySmall),
      );
    }

    final tint = _available ? colors.success : colors.warning;

    return AppCard(
      borderColor: tint.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(
                color: tint,
                shape: BoxShape.circle,
              )),
              SizedBox(width: spacing.sm),
              Text(
                _available ? 'صدای آلمانی فعال است' : 'صدای آلمانی نصب نیست',
                style: context.texts.titleSmall?.copyWith(color: tint),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Text(
            _available
                ? 'تلفظ‌ها با صدای آلمانی دستگاه خوانده می‌شود.'
                : 'بدون صدای آلمانی، واژه‌ها با لهجه اشتباه خوانده می‌شوند. '
                    'در تنظیمات دستگاه، بخش تبدیل متن به گفتار، زبان آلمانی '
                    'را نصب کن.',
            style: context.texts.bodySmall,
          ),
          if (_voice != null) ...[
            SizedBox(height: spacing.sm),
            Text(
              _voice!,
              style: AppTypography.monoStyle(
                color: colors.textTertiary,
                size: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.md,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.texts.bodyMedium)),
          Text(
            value,
            style: AppTypography.monoStyle(
              color: context.colors.textSecondary,
              size: 13,
            ),
          ),
        ],
      ),
    );
  }
}
