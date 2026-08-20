import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// German text-to-speech.
///
/// The naive version of this (setLanguage + speak) mispronounces words for a
/// reason that is invisible at the call site: `setLanguage` fails silently when
/// the device has no German voice installed, and the engine then reads German
/// text with whatever voice *is* active - an English or Persian one. The vowels
/// and the "ch"/"ei"/"eu" digraphs come out wrong, which is exactly the sound
/// of "it pronounces words incorrectly".
///
/// So: resolve a real German voice once, report it when there isn't one, and
/// normalise the text before it reaches the engine.
class AudioHelper {
  AudioHelper._();

  static final FlutterTts _tts = FlutterTts();

  static bool _initialised = false;
  static bool _germanVoiceAvailable = false;
  static String? _resolvedVoiceName;

  /// False once initialisation has run and found no German voice. The UI uses
  /// this to tell the user to install German voice data rather than letting
  /// them listen to wrong pronunciation and assume the app taught it.
  static bool get germanVoiceAvailable => _germanVoiceAvailable;

  /// Name of the voice actually in use, for the settings screen.
  static String? get resolvedVoiceName => _resolvedVoiceName;

  /// Normal speaking rate differs per engine: Android and iOS take 0.0-1.0
  /// with 0.5 as normal, the web SpeechSynthesis scale is centred on 1.0. A
  /// single constant is therefore fast on one platform and sluggish on
  /// another. Slightly under normal in both cases, because learners are
  /// hearing these words for the first time.
  static double get _rate {
    if (kIsWeb) return 0.85;
    return 0.42;
  }

  static Future<void> _ensureInitialised() async {
    if (_initialised) return;
    _initialised = true;

    // Without this, a second tap starts a new utterance while the first is
    // still speaking; the engine interleaves them and the result is garbled.
    await _tts.awaitSpeakCompletion(true);

    _germanVoiceAvailable = await _resolveGermanVoice();

    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  /// Prefer an exact de-DE voice, then any German locale (de-AT, de-CH), then
  /// give up honestly rather than reading German with a foreign voice.
  static Future<bool> _resolveGermanVoice() async {
    try {
      final exact = await _tts.isLanguageAvailable('de-DE');
      if (exact == true) {
        await _tts.setLanguage('de-DE');
        _resolvedVoiceName = await _pickVoiceForLocale('de-DE');
        return true;
      }

      final languages = await _tts.getLanguages;
      final german = (languages as List?)
          ?.map((l) => l.toString())
          .firstWhere(
            (l) => l.toLowerCase().startsWith('de'),
            orElse: () => '',
          );
      if (german != null && german.isNotEmpty) {
        await _tts.setLanguage(german);
        _resolvedVoiceName = await _pickVoiceForLocale(german);
        return true;
      }
    } catch (e) {
      debugPrint('TTS language resolution failed: ${e.runtimeType}');
    }
    return false;
  }

  /// Picking the voice explicitly matters on Android, where several German
  /// voices can be installed and the default is not always the best quality.
  static Future<String?> _pickVoiceForLocale(String locale) async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return null;

      final candidates = voices
          .whereType<Map>()
          .where(
            (v) => (v['locale']?.toString().toLowerCase() ?? '')
                .startsWith(locale.split('-').first.toLowerCase()),
          )
          .toList();
      if (candidates.isEmpty) return null;

      // Prefer an exact locale match over a merely same-language one.
      final best = candidates.firstWhere(
        (v) => v['locale']?.toString().toLowerCase() == locale.toLowerCase(),
        orElse: () => candidates.first,
      );

      await _tts.setVoice({
        'name': best['name'].toString(),
        'locale': best['locale'].toString(),
      });
      return best['name'].toString();
    } catch (e) {
      debugPrint('TTS voice selection failed: ${e.runtimeType}');
      return null;
    }
  }

  /// Strip everything the content uses for the *reader* but that an engine
  /// would try to pronounce.
  ///
  /// Vocabulary entries carry editorial notation - "super / toll" for
  /// alternatives, "alt (Person)" for disambiguation, IPA in slashes. Spoken
  /// literally these become "super slash toll" and "alt bracket person". Only
  /// the first variant is spoken, which is what a learner needs to hear.
  @visibleForTesting
  static String normalizeForSpeech(String input) {
    var text = input.trim();

    // Drop parenthesised and bracketed asides.
    text = text.replaceAll(RegExp(r'[\(\[][^\)\]]*[\)\]]'), ' ');

    // "A / B" or "A|B" -> just A. Splitting on the separator keeps the entry
    // usable as a single spoken word.
    text = text.split(RegExp(r'\s*[/|]\s*')).first;

    // Ellipses stand in for a slot the learner fills ("ich komme aus ...").
    text = text.replaceAll(RegExp(r'\.{2,}|…'), ' ');

    // Collapse whitespace left behind by the removals.
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  /// Speak German text. Silently does nothing for empty input.
  ///
  /// Returns false when no German voice could be resolved, so the caller can
  /// surface that instead of playing a wrong-language reading.
  static Future<bool> speakDe(String text) async {
    await _ensureInitialised();

    final spoken = normalizeForSpeech(text);
    if (spoken.isEmpty) return _germanVoiceAvailable;
    if (!_germanVoiceAvailable) return false;

    // Cancel whatever is in flight: tapping a second word should replace the
    // first, not queue behind it.
    await _tts.stop();
    await _tts.speak(spoken);
    return true;
  }

  static Future<void> stop() async {
    if (!_initialised) return;
    await _tts.stop();
  }
}
