import 'package:flutter/material.dart';

import '../../core/constants/app_data.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';
import '../../widgets/quiz_widgets.dart';
import '../../widgets/speak_button.dart';
import 'lesson_filter.dart';

/// Translate a Persian prompt into German, graded with an edit-distance
/// tolerance so a single typo is "almost" rather than "wrong".
class WritingPracticeScreen extends StatefulWidget {
  const WritingPracticeScreen({super.key});

  @override
  State<WritingPracticeScreen> createState() => _WritingPracticeScreenState();
}

class _WritingPracticeScreenState extends State<WritingPracticeScreen> {
  final _controller = TextEditingController();
  int _index = 0;
  int _correct = 0;
  FeedbackKind? _outcome;
  String _lessonFilter = kAllLessons;
  List<_Prompt> _prompts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _load() {
    final prompts = <_Prompt>[];
    for (final lesson in AppData.lessons) {
      final title = lesson['title']?.toString() ?? '';
      if (_lessonFilter != kAllLessons && title != _lessonFilter) continue;

      for (final s in (lesson['sentences'] as List? ?? const [])) {
        final de = (s['de'] ?? '').toString();
        final fa = (s['fa'] ?? '').toString();
        if (de.isEmpty || fa.isEmpty) continue;
        prompts.add(_Prompt(persian: fa, german: de, lesson: title));
      }
    }
    prompts.shuffle();

    setState(() {
      _prompts = prompts;
      _index = 0;
      _controller.clear();
      _outcome = null;
    });
  }

  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[.,!?;:\-]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static int _distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        current[j + 1] = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[b.length];
  }

  void _check() {
    if (_controller.text.trim().isEmpty || _prompts.isEmpty) return;

    final expected = _normalize(_prompts[_index].german);
    final given = _normalize(_controller.text);
    final distance = _distance(given, expected);
    final tolerance = expected.length > 15 ? 2 : 1;

    setState(() {
      if (distance == 0) {
        _outcome = FeedbackKind.correct;
        _correct++;
      } else if (distance <= tolerance) {
        _outcome = FeedbackKind.almost;
        _correct++;
      } else {
        _outcome = FeedbackKind.wrong;
      }
    });
  }

  void _next() {
    setState(() {
      _controller.clear();
      _outcome = null;
      if (_index < _prompts.length - 1) {
        _index++;
      } else {
        _index = 0;
        _prompts = List.of(_prompts)..shuffle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final answered = _outcome != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('نوشتن'),
        actions: [ScoreReadout(value: _correct, unit: 'درست')],
      ),
      body: SafeArea(
        child: _prompts.isEmpty
            ? const EmptyState(
                title: 'جمله‌ای برای این درس نیست',
                action: 'درس دیگری انتخاب کن یا همه درس‌ها را ببین.',
                icon: Icons.filter_alt_outlined,
              )
            : ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.gutter,
                  vertical: spacing.sm,
                ),
                children: [
                  LessonFilter(
                    value: _lessonFilter,
                    onChanged: (v) {
                      _lessonFilter = v;
                      _load();
                    },
                  ),
                  SizedBox(height: spacing.xl),

                  PlateLabel(
                    '${_prompts[_index].lesson} · '
                    '${_index + 1}/${_prompts.length}',
                  ),
                  SizedBox(height: spacing.md),
                  Text(
                    _prompts[_index].persian,
                    style: context.texts.headlineMedium,
                  ),
                  SizedBox(height: spacing.xs),
                  Text('به آلمانی بنویس', style: context.texts.bodySmall),
                  SizedBox(height: spacing.xl),

                  TextField(
                    controller: _controller,
                    enabled: !answered,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLines: 3,
                    minLines: 2,
                    textDirection: TextDirection.ltr,
                    style: AppTypography.monoStyle(
                      color: context.colors.textPrimary,
                      size: 17,
                    ),
                    decoration: const InputDecoration(hintText: 'Deutsch …'),
                    onSubmitted: (_) => answered ? _next() : _check(),
                  ),
                  SizedBox(height: spacing.lg),

                  FilledButton(
                    onPressed: answered ? _next : _check,
                    child: Text(answered ? 'جمله بعدی' : 'بررسی'),
                  ),

                  if (answered) ...[
                    SizedBox(height: spacing.lg),
                    FeedbackBanner(
                      kind: _outcome!,
                      headline: switch (_outcome!) {
                        FeedbackKind.correct => 'Richtig',
                        FeedbackKind.almost => 'Fast richtig',
                        FeedbackKind.wrong => 'Falsch',
                      },
                      detail: _prompts[_index].german,
                      trailing: SpeakButton(text: _prompts[_index].german),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Prompt {
  const _Prompt({
    required this.persian,
    required this.german,
    required this.lesson,
  });

  final String persian;
  final String german;
  final String lesson;
}
