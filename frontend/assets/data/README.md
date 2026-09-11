# assets/data

Bundled content packages, one JSON file per level (`a1_1.json` … `b1_2.json`).

These ship with the app so a first launch works fully offline. On launch the app
compares each level's `version` against `GET /content/manifest` and pulls only
what changed, verifying the `checksum` after download.

Declared in `pubspec.yaml` under `flutter: assets:`. The directory must exist
even while empty, or `flutter analyze` reports
`asset_directory_does_not_exist`.
