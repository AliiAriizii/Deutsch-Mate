import '../constants/app_data.dart';
import 'progress_models.dart';

/// What a Lektion actually contains, and therefore what a learner can do in it.
///
/// The Menschen shape has five sections. The current content carries material
/// for three: a word field, a grammar summary, and example sentences. Rather
/// than show two steps that lead nowhere, the plan reports only the sections
/// that have content, and [missingSections] names the rest so the gap is
/// visible instead of silently absent.
class LektionPlan {
  const LektionPlan({
    required this.index,
    required this.lektionId,
    required this.modulId,
    required this.levelId,
    required this.title,
    required this.name,
    required this.topic,
    required this.grammar,
    required this.wordCount,
    required this.sentenceCount,
    required this.steps,
  });

  final int index;
  final String lektionId;
  final String modulId;
  final String levelId;

  /// "Lektion 1" as authored.
  final String title;

  /// The Lektion's own title. Still Hueber's wording until the content
  /// migration replaces it - see docs/DECISIONS.md.
  final String name;

  final String topic;
  final String grammar;
  final int wordCount;
  final int sentenceCount;

  /// The sections that have something to do, in the order they should be done.
  final List<SectionKind> steps;

  static const lektionenPerModul = 3;

  /// The two sections this content cannot yet fill.
  static const missingSections = [SectionKind.einstieg, SectionKind.abschluss];

  int get stepCount => steps.length;

  /// How many exercises a section holds, used to size its progress.
  int itemsIn(SectionKind kind) => switch (kind) {
        SectionKind.wortschatz => wordCount,
        SectionKind.redemittel => sentenceCount,
        SectionKind.grammatik => grammar.isEmpty ? 0 : 1,
        _ => 0,
      };
}

/// Builds the plan for every Lektion in the bundled content.
///
/// This is the seam the content migration replaces: today it reads the
/// hardcoded `AppData`, later it reads a validated content package. Everything
/// downstream depends on [LektionPlan], not on `AppData`.
List<LektionPlan> buildLektionPlans() {
  final lessons = AppData.lessons;
  return [
    for (var i = 0; i < lessons.length; i++) _planFor(lessons[i], i),
  ];
}

LektionPlan _planFor(Map<String, dynamic> lesson, int index) {
  final words = (lesson['words'] as List?) ?? const [];
  final sentences = (lesson['sentences'] as List?) ?? const [];
  final grammar = lesson['grammar']?.toString() ?? '';

  final modulNumber = (index ~/ LektionPlan.lektionenPerModul) + 1;
  const levelId = 'A1.1';
  final modulId = 'a1.1.m$modulNumber';

  // Order follows the book: meet the words, then the structure, then the
  // phrases that use both.
  final steps = <SectionKind>[
    if (words.isNotEmpty) SectionKind.wortschatz,
    if (grammar.isNotEmpty) SectionKind.grammatik,
    if (sentences.isNotEmpty) SectionKind.redemittel,
  ];

  return LektionPlan(
    index: index,
    lektionId: '$modulId.l${index + 1}',
    modulId: modulId,
    levelId: levelId,
    title: lesson['title']?.toString() ?? 'Lektion ${index + 1}',
    name: lesson['name']?.toString() ?? '',
    topic: lesson['topic']?.toString() ?? '',
    grammar: grammar,
    wordCount: words.length,
    sentenceCount: sentences.length,
    steps: steps,
  );
}
