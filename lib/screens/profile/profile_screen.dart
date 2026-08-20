import 'package:flutter/material.dart';

import '../../core/utils/audio_helper.dart';
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
