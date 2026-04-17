# Nexa (legacy, unused)

The app previously referenced Nexa here. It now uses **Plus Jakarta Sans** via `google_fonts` instead. You can delete this folder and the placeholder TTFs if you no longer need them.

## Production fonts

Obtain **Nexa Book** and **Nexa Bold** (and an App license from Fontfabric if you ship the font in a mobile app), then replace the files in this folder:

- `Nexa-Book.ttf` — body and UI text (registered as weight 400)
- `Nexa-Bold.ttf` — headings and emphasis (weights 600 and 700 in the theme map to this file; adjust `pubspec.yaml` if you add a separate Semibold file)

Keep the filenames above or update the `flutter.fonts` section in `pubspec.yaml` to match your files.

## Placeholder files in this repo

Until you drop in licensed Nexa files, the TTFs here are **copies of the project’s existing Helvetica Now Display** assets so the app builds and runs. Replace them before release if you want true Nexa shaping and licensing compliance.
