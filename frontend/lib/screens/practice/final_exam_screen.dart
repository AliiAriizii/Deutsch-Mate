import 'package:flutter/material.dart';

import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';
import '../../widgets/quiz_widgets.dart';

/// End-of-level exam. 20 items, 5 points each, pass at 70.
///
/// The item bank is unchanged and still hardcoded; it moves to content JSON
/// with the schema work.
class FinalExamScreen extends StatefulWidget {
  const FinalExamScreen({super.key});

  @override
  State<FinalExamScreen> createState() => _FinalExamScreenState();
}

class _FinalExamScreenState extends State<FinalExamScreen> {
  int _index = 0;
  int _score = 0;
  bool _submitted = false;
  int? _picked;

  static const _passMark = 70;
  static const _pointsPerItem = 5;

  static const _questions = <({
    String prompt,
    List<String> choices,
    int answer,
  })>[
    (
      prompt: 'معنی «der Vorname» چیست؟',
      choices: ['نام خانوادگی', 'نام کوچک', 'شغل', 'کشور'],
      answer: 1
    ),
    (
      prompt: 'Ich ___ aus dem Iran.',
      choices: ['komme', 'kommt', 'heiße', 'wohne'],
      answer: 0
    ),
    (
      prompt: 'کدام شغل برای یک زن است؟',
      choices: [
        'der Arzt',
        'die Journalistin',
        'der Lehrer',
        'der Verkäufer'
      ],
      answer: 1
    ),
    (
      prompt: 'آرتیکل درست «Tisch» کدام است؟',
      choices: ['die', 'das', 'der', 'den'],
      answer: 2
    ),
    (
      prompt: '«خانواده من بزرگ است» کدام است؟',
      choices: [
        'Meine Familie ist klein.',
        'Meine Familie ist groß.',
        'Das ist meine Mutter.',
        'Ich habe keine Familie.'
      ],
      answer: 1
    ),
    (
      prompt: 'منفی «ein Buch» کدام است؟',
      choices: ['kein Buch', 'keine Buch', 'nicht Buch', 'keinen Buch'],
      answer: 0
    ),
    (
      prompt: 'شکل درست können برای ich کدام است؟',
      choices: ['kannst', 'können', 'kann', 'könnt'],
      answer: 2
    ),
    (
      prompt: 'آرتیکل درست «Brille» چیست؟',
      choices: ['der', 'das', 'die', 'den'],
      answer: 2
    ),
    (
      prompt: 'برای روزهای هفته کدام حرف اضافه؟',
      choices: ['um', 'am', 'in', 'aus'],
      answer: 1
    ),
    (
      prompt: 'معنی «möchten» چیست؟',
      choices: ['نوشیدن', 'خوردن', 'خواستن', 'آمدن'],
      answer: 2
    ),
    (
      prompt: '«einsteigen» چه نوع فعلی است؟',
      choices: ['مدال', 'جداشدنی', 'ساده', 'بی‌قاعده'],
      answer: 1
    ),
    (
      prompt: 'Partizip II فعل arbeiten کدام است؟',
      choices: ['gearbeitet', 'gearbeiten', 'arbeitete', 'gearbeit'],
      answer: 0
    ),
    (
      prompt: 'کدام واژه به معنی «ایستگاه قطار» است؟',
      choices: [
        'der Flughafen',
        'der Bahnhof',
        'die Haltestelle',
        'das Auto'
      ],
      answer: 1
    ),
    (
      prompt: 'Ich habe meinen Schlüssel ___',
      choices: ['verloren', 'passiert', 'gegangen', 'geblieben'],
      answer: 0
    ),
    (
      prompt: 'برای ساعت دقیق کدام حرف اضافه؟',
      choices: ['am', 'um', 'aus', 'mit'],
      answer: 1
    ),
    (
      prompt: 'جمع «das Kind» کدام است؟',
      choices: ['die Kinder', 'die Kindes', 'die Kind', 'der Kinder'],
      answer: 0
    ),
    (
      prompt: 'معنی «kaputt» چیست؟',
      choices: ['جدید', 'زیبا', 'خراب', 'گران'],
      answer: 2
    ),
    (
      prompt: 'پاسخ مناسب «Wie alt bist du?» کدام است؟',
      choices: [
        'Ich wohne in Teheran.',
        'Ich bin 19 Jahre alt.',
        'Ich bin Student.',
        'Ich komme aus Iran.'
      ],
      answer: 1
    ),
    (
      prompt: 'در Akkusativ، «der Tisch» چه می‌شود؟',
      choices: ['das Tisch', 'die Tisch', 'den Tisch', 'dem Tisch'],
      answer: 2
    ),
    (
      prompt: '«چیزی خوردن» به آلمانی کدام است؟',
      choices: [
        'etwas trinken',
        'etwas essen',
        'etwas kochen',
        'etwas machen'
      ],
      answer: 1
    ),
  ];

  void _pick(int i) {
    if (_picked != null) return;
    setState(() {
      _picked = i;
      if (i == _questions[_index].answer) _score += _pointsPerItem;
    });
  }

  void _next() {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _picked = null;
      });
    } else {
      setState(() => _submitted = true);
    }
  }

  void _restart() {
    setState(() {
      _index = 0;
      _score = 0;
      _submitted = false;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_submitted ? 'نتیجه' : 'آزمون جامع'),
        actions: [
          if (!_submitted) ScoreReadout(value: _score, unit: 'از 100'),
        ],
      ),
      body: SafeArea(
        child: _submitted ? _result(context) : _question(context),
      ),
    );
  }

  Widget _question(BuildContext context) {
    final spacing = context.spacing;
    final q = _questions[_index];
    final revealed = _picked != null;
    // German prompts must read LTR even inside the Persian layout.
    final isGerman = !RegExp(r'[؀-ۿ]').hasMatch(q.prompt);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppProgressBar(
            value: (_index + 1) / _questions.length,
            height: 4,
          ),
          SizedBox(height: spacing.lg),
          PlateLabel('پرسش ${_index + 1} از ${_questions.length}'),
          SizedBox(height: spacing.md),
          AppCard(
            background: context.colors.surface,
            padding: EdgeInsets.all(spacing.lg),
            child: Text(
              q.prompt,
              style: context.texts.titleLarge,
              textDirection:
                  isGerman ? TextDirection.ltr : TextDirection.rtl,
              textAlign: TextAlign.start,
            ),
          ),
          SizedBox(height: spacing.lg),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < q.choices.length; i++)
                  ChoiceButton(
                    label: q.choices[i],
                    state: switch (_picked) {
                      null => ChoiceState.idle,
                      _ when i == q.answer && i == _picked =>
                        ChoiceState.selectedCorrect,
                      _ when i == q.answer => ChoiceState.revealedCorrect,
                      _ when i == _picked => ChoiceState.selectedWrong,
                      _ => ChoiceState.idle,
                    },
                    onTap: revealed ? null : () => _pick(i),
                  ),
              ],
            ),
          ),
          if (revealed)
            FilledButton(
              onPressed: _next,
              child: Text(
                _index == _questions.length - 1 ? 'دیدن نتیجه' : 'بعدی',
              ),
            ),
          SizedBox(height: spacing.lg),
        ],
      ),
    );
  }

  Widget _result(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final passed = _score >= _passMark;
    final tint = passed ? colors.success : colors.warning;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlateLabel(passed ? 'قبول' : 'حد نصاب نرسید', color: tint),
          SizedBox(height: spacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$_score',
                style: AppTypography.monoStyle(
                  color: tint,
                  size: 56,
                  weight: FontWeight.w700,
                ),
              ),
              SizedBox(width: spacing.sm),
              Text('/ 100', style: context.texts.titleMedium),
            ],
          ),
          SizedBox(height: spacing.lg),
          AppProgressBar(value: _score / 100, tint: tint),
          SizedBox(height: spacing.md),
          Text(
            passed
                ? 'سطح A1.1 را رد کردی. سراغ A1.2 برو.'
                : 'حد قبولی 70 است. درس‌های ضعیف را مرور کن و دوباره امتحان بده.',
            style: context.texts.bodyMedium,
          ),
          SizedBox(height: spacing.xxl),
          FilledButton(onPressed: _restart, child: const Text('آزمون تازه')),
        ],
      ),
    );
  }
}
