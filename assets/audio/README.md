# assets/audio

Pronunciation audio for vocabulary and dialogues.

Currently unused: playback goes through `flutter_tts` (device text-to-speech) in
`lib/core/utils/audio_helper.dart`. Recorded audio replaces or supplements TTS
when it exists; the naming scheme follows the exercise ids in the content
packages.

Declared in `pubspec.yaml` under `flutter: assets:`. The directory must exist
even while empty, or `flutter analyze` reports
`asset_directory_does_not_exist`.
