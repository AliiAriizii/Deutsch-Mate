import 'package:flutter/material.dart';

import '../core/utils/audio_helper.dart';
import '../theme/app_tokens.dart';

/// Speaks German text, and says so plainly when it cannot.
///
/// The old call sites fired TTS and ignored the outcome, so a device with no
/// German voice would read German text with an English or Persian voice and the
/// learner had no way to know the pronunciation they just heard was wrong.
/// Here, a failure is surfaced as a direction: what happened, and what to do.
class SpeakButton extends StatelessWidget {
  const SpeakButton({
    super.key,
    required this.text,
    this.size = 20,
    this.tooltip,
  });

  final String text;
  final double size;
  final String? tooltip;

  Future<void> _speak(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final spoken = await AudioHelper.speakDe(text);
    if (spoken || messenger == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'صدای آلمانی روی این دستگاه نصب نیست. '
            'در تنظیمات دستگاه، بخش تبدیل متن به گفتار، زبان آلمانی را نصب کنید.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _speak(context),
      icon: Icon(Icons.volume_up_outlined, size: size),
      color: context.colors.textSecondary,
      tooltip: tooltip ?? 'تلفظ',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }
}
