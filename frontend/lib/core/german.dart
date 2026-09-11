/// German-specific text helpers.
///
/// Domain logic, not presentation: the widget layer asks these questions, it
/// does not answer them itself. Three screens were each re-deriving "does this
/// vocabulary entry start with an article" with their own slightly different
/// string handling.
library;

/// A vocabulary entry split into its grammatical parts.
class GermanNoun {
  const GermanNoun({required this.article, required this.word});

  /// "der", "die", "das", or null when the entry is not a noun with an
  /// article - verbs, adjectives, proper nouns, set phrases.
  final String? article;

  /// The entry without its article. Equals the whole entry when there is none.
  final String word;

  bool get hasArticle => article != null;
}

const _articles = {'der', 'die', 'das'};

/// Split "der Beruf" into ("der", "Beruf"). Leaves "arbeiten" alone.
///
/// Only a leading definite article counts. "die Schweiz" is a noun with an
/// article; "Musik hören" is not, and neither is "Deutschland".
GermanNoun parseGermanEntry(String entry) {
  final trimmed = entry.trim();
  final space = trimmed.indexOf(' ');
  if (space <= 0) return GermanNoun(article: null, word: trimmed);

  final head = trimmed.substring(0, space);
  if (!_articles.contains(head.toLowerCase())) {
    return GermanNoun(article: null, word: trimmed);
  }

  final rest = trimmed.substring(space + 1).trim();
  if (rest.isEmpty) return GermanNoun(article: null, word: trimmed);

  return GermanNoun(article: head.toLowerCase(), word: rest);
}

/// Every entry in [entries] that carries a definite article.
///
/// This is what the Artikel Trainer drills on, and what lets a vocabulary list
/// show gender colour without the content having to be re-authored.
Iterable<GermanNoun> nounsWithArticles(Iterable<String> entries) =>
    entries.map(parseGermanEntry).where((n) => n.hasArticle);
