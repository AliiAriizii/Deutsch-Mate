import 'package:flutter_test/flutter_test.dart';

import 'package:deutsch_mate/core/utils/audio_helper.dart';

void main() {
  group('normalizeForSpeech', () {
    test('keeps a plain word with its article', () {
      expect(AudioHelper.normalizeForSpeech('der Beruf'), 'der Beruf');
    });

    test('speaks only the first of two alternatives', () {
      // "super / toll" was read aloud as "super slash toll".
      expect(AudioHelper.normalizeForSpeech('super / toll'), 'super');
      expect(AudioHelper.normalizeForSpeech('super|toll'), 'super');
    });

    test('drops parenthesised and bracketed asides', () {
      expect(AudioHelper.normalizeForSpeech('alt (Person)'), 'alt');
      expect(AudioHelper.normalizeForSpeech('backen [Kuchen]'), 'backen');
      expect(
        AudioHelper.normalizeForSpeech('das Regal (Buch)'),
        'das Regal',
      );
    });

    test('drops the slot ellipsis learners fill in', () {
      expect(
        AudioHelper.normalizeForSpeech('ich komme aus ...'),
        'ich komme aus',
      );
      expect(AudioHelper.normalizeForSpeech('mein Name ist …'), 'mein Name ist');
    });

    test('collapses whitespace left by removals', () {
      expect(
        AudioHelper.normalizeForSpeech('  die   Frau (Ehefrau)  '),
        'die Frau',
      );
    });

    test('preserves umlauts and eszett untouched', () {
      expect(
        AudioHelper.normalizeForSpeech('die Ärztin heißt Müller'),
        'die Ärztin heißt Müller',
      );
    });

    test('yields empty string for notation-only input', () {
      expect(AudioHelper.normalizeForSpeech('(nur Notiz)'), '');
      expect(AudioHelper.normalizeForSpeech('   '), '');
    });
  });
}
