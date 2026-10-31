# Lema

A content operating system for creators. Plan posts, keep a consistent publishing queue, and see what performs across Instagram, TikTok, YouTube, LinkedIn and X. Built with Flutter for macOS, Windows, iOS, Android and web.

## What it does

- **Queue and calendar.** Preset peak-hour slots, drag to reorder, and a month view of everything scheduled.
- **Composer.** Write once, pick platforms, attach images or video, schedule or share now.
- **AI assistant.** Hook variations, script structure and caption rewrites (Gemini, optional key).
- **Analytics.** Per-post likes, views, comments and shares.

Publishing goes through a local daemon on port 3001. With no daemon running, turn on Demo Mode in Settings to simulate dispatches. Demo data lives in `lib/core/demo_seed.dart`.

## Run

Requires Flutter with Dart `^3.13.5`.

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos   # or ios, android, windows, chrome
```
