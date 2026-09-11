import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';
import '../../widgets/quiz_widgets.dart';

/// Grammar multiple choice.
///
/// The item bank is still the three hardcoded questions from before - it moves
/// into content JSON with the schema work. The interaction is what changed: the
/// answer no longer auto-advances after 1.2s, which gave the learner no time to
/// read why they were wrong.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int _score = 0;
  int? _picked;

  static const _questions = [
    (
      prompt: 'Ich ___ aus dem Iran.',
      choices: ['bist', 'bin', 'sind', 'ist'],
      answer: 1,
      note: 'ich + sein',
    ),
    (
      prompt: 'Wie ___ du?',
      choices: ['heiße', 'heißt', 'sein', 'kommt'],
      answer: 1,
      note: 'du + heißen',
    ),
    (
      prompt: 'Das ist ___ Buch.',
      choices: ['der', 'die', 'das', 'den'],
      answer: 2,
      note: 'das Buch, Nominativ',
    ),
  ];

  void _pick(int i) {
    if (_picked != null) return;
    setState(() {
      _picked = i;
      if (i == _questions[_index].answer) _score += 20;
    });
  }

  void _next() {
    setState(() {
      _picked = null;
      _index = (_index + 1) % _questions.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final q = _questions[_index];
    final revealed = _picked != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('آزمون گرامر'),
        actions: [ScoreReadout(value: _score, unit: 'XP')],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppProgressBar(
                value: (_index + 1) / _questions.length,
                height: 4,
              ),
              SizedBox(height: spacing.xl),
              PlateLabel('پرسش ${_index + 1} از ${_questions.length}'),
              SizedBox(height: spacing.md),
              AppCard(
                background: context.colors.surface,
                padding: EdgeInsets.all(spacing.xl),
                child: Text(
                  q.prompt,
                  style: context.texts.headlineMedium,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                ),
              ),
              SizedBox(height: spacing.xl),
              for (var i = 0; i < q.choices.length; i++)
                ChoiceButton(
                  label: q.choices[i],
                  monospace: true,
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
              const Spacer(),
              if (revealed) ...[
                FeedbackBanner(
                  kind: _picked == q.answer
                      ? FeedbackKind.correct
                      : FeedbackKind.wrong,
                  headline: _picked == q.answer ? 'Richtig' : 'Falsch',
                  detail: q.note,
                ),
                SizedBox(height: spacing.lg),
                FilledButton(
                  onPressed: _next,
                  child: const Text('پرسش بعدی'),
                ),
              ],
              SizedBox(height: spacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
