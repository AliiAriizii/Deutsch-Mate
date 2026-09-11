import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';
import 'artikel_trainer_screen.dart';
import 'final_exam_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import 'writing_practice_screen.dart';

/// Practice hub.
///
/// Grouped by what the exercise trains rather than presented as a flat menu of
/// games, and each row carries the accent that mode uses elsewhere: blue for
/// drills, violet for spaced repetition, plain for the exam.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Scaffold(
      appBar: AppBar(title: const Text('تمرین')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          spacing.gutter,
          0,
          spacing.gutter,
          spacing.xxxl,
        ),
        children: [
          SectionHeader(title: 'گرامر و واژه', eyebrow: 'تمرین هدفمند'),
          _PracticeRow(
            eyebrow: 'der / die / das',
            title: 'تمرین آرتیکل',
            subtitle: 'جنسیت اسم‌ها را با رنگ و تکرار یاد بگیر',
            tint: colors.accent,
            destination: const ArtikelTrainerScreen(),
          ),
          _PracticeRow(
            eyebrow: 'Grammatik',
            title: 'آزمون چهارگزینه‌ای',
            subtitle: 'ساختارهای درس‌ها را بسنج',
            tint: colors.accent,
            destination: const QuizScreen(),
          ),
          _PracticeRow(
            eyebrow: 'Schreibtraining',
            title: 'نوشتن',
            subtitle: 'جمله فارسی را به آلمانی بنویس',
            tint: colors.accent,
            destination: const WritingPracticeScreen(),
          ),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'مرور', eyebrow: 'تکرار فاصله‌دار'),
          _PracticeRow(
            eyebrow: 'Leitner',
            title: 'کارت‌های مرور',
            subtitle: 'واژه‌هایی که وقت مرورشان رسیده',
            tint: colors.review,
            destination: const FlashcardScreen(),
          ),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'ارزیابی', eyebrow: 'پایان سطح'),
          _PracticeRow(
            eyebrow: 'A1.1',
            title: 'آزمون جامع',
            subtitle: '20 پرسش · حد قبولی 70 از 100',
            tint: colors.textSecondary,
            destination: const FinalExamScreen(),
          ),
        ],
      ),
    );
  }
}

class _PracticeRow extends StatelessWidget {
  const _PracticeRow({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.destination,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Color tint;
  final Widget destination;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: AppCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => destination),
        ),
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            // A 3px leading rule carries the mode colour. Cheaper than an icon
            // and it mirrors under RTL for free.
            Container(
              width: 3,
              height: 68,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: context.radii.pillBorder,
              ),
            ),
            SizedBox(width: spacing.lg),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlateLabel(eyebrow, color: tint),
                    SizedBox(height: spacing.xxs),
                    Text(title, style: context.texts.titleSmall),
                    SizedBox(height: spacing.xxs),
                    Text(subtitle, style: context.texts.bodySmall),
                  ],
                ),
              ),
            ),
            SizedBox(width: spacing.sm),
            Padding(
              padding: EdgeInsetsDirectional.only(end: spacing.lg),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: context.colors.textTertiary,
                textDirection: Directionality.of(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
