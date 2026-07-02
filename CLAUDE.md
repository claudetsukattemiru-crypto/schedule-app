# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

This is a brand-new Flutter app, currently pre-code. The agreed architecture and implementation order live in the approved plan at `C:\Users\rhoso\.claude\plans\rosy-orbiting-meteor.md` — read it before scaffolding the project so the structure below is created consistently.

A separate, lightweight **Web prototype** also exists at `web-prototype/` (plain HTML/CSS/JS — `index.html` / `style.css` / `script.js`, no build step). It is independent of the Flutter app below: same product idea and the same "never auto-save from voice" rule, but its own throwaway implementation (Web Speech API instead of `speech_to_text`, `localStorage` instead of Drift, no sync-readiness fields). Don't conflate the two — changes to one are not expected to touch the other. See `## Web prototype` below for details.

## What this app does

A Japanese-language mobile app where the user speaks a schedule entry (e.g. "来週火曜の15時に会議") and the app extracts a date/time + title and adds it to a local schedule list. v1 is intentionally local-only and rule-based (no LLM API, no cloud backend) but the data model is designed so that syncing across the user's own multiple devices can be added later without a schema rewrite. Multi-user sharing is explicitly out of scope.

## Commands

Once the Flutter project is scaffolded (`flutter create .`), the standard commands apply:
- `flutter pub get` — install dependencies
- `flutter pub run build_runner build --delete-conflicting-outputs` — regenerate Drift database code after editing table definitions in `lib/data/db/`
- `flutter test` — run all tests; `flutter test test/domain/parsing/jp_datetime_parser_test.dart` to run just the parser tests (this should be the fastest feedback loop — no emulator needed)
- `flutter run` — run on a connected Android emulator/device
- `flutter doctor` — verify toolchain setup

**iOS cannot be built or run on this Windows machine** (requires Xcode on macOS). Treat Android as the primary target for local verification.

## Architecture

Three layers, kept independently testable:
- `lib/data/` — Drift (sqlite) database + repository. `ScheduleEvent` rows use **client-generated UUIDv4 primary keys** (not autoincrement), UTC timestamps (`createdAt`/`updatedAt`), and a soft-delete `deletedAt` column instead of hard deletes. These fields exist specifically so a future device-sync layer can be bolted on additively — don't "clean up" these columns even though v1 has no sync logic yet.
- `lib/domain/parsing/` — the Japanese date/time parser. It's an ordered list of matcher functions (absolute dates before relative ones, week+weekday before bare weekday, explicit time before vague time-of-day words like 朝/夜) run against the raw transcript; each match is stripped from the string and whatever remains becomes the title. The result carries a `warnings` list for low-confidence fields (e.g. 朝→9:00 is a guess). Known unsupported expressions (date ranges like "3日間", "再来週の今頃") are an accepted v1 gap, not a bug to chase.
- `lib/domain/voice/` — thin wrapper around the `speech_to_text` plugin (`localeId: "ja_JP"`).
- `lib/features/` — UI screens, wired to `data/` via Riverpod providers.

## Key design rule: never auto-save from voice

Both speech-to-text and the regex parser are failure-prone. The voice flow always routes through a confirmation/edit screen (`features/confirm/confirm_event_screen.dart`) where low-confidence fields are visually flagged; saving only happens on explicit user action. This screen is shared with the manual add/edit form rather than duplicated.

## Web prototype

`web-prototype/index.html` / `style.css` / `script.js` — a standalone HTML/CSS/JS version of the same idea, kept deliberately separate from the Flutter app (don't try to share code between them; the parsing logic in `script.js` is a JS port of the same matcher-ordering rules described above, not an import).

- **Run it via a local server, not `file://`** — `SpeechRecognition` was unreliable opened directly as a file. From `web-prototype/`: `node _serve.js` (a minimal static file server already in that folder) then open `http://localhost:8000/`.
- Voice input uses the browser's native `SpeechRecognition`/`webkitSpeechRecognition` (`lang = "ja-JP"`), not a plugin — Chrome required, no server-side speech API.
- Data is stored in `localStorage` under the key `scheduleEvents`. Unlike the Flutter app's `ScheduleEvent` table, this prototype has no `deletedAt`/sync-readiness columns — it's throwaway, not the future-sync-ready data model.
- If voice input fails with a `no-speech` error, it's almost always the OS picking the wrong default input device (e.g. Windows defaulting to an unplugged jack mic instead of the built-in mic) rather than a bug in the page — check the OS sound input settings before debugging the JS.
- Recognition runs with `continuous = true` and does NOT auto-stop on a pause; the user must tap the mic button again to end listening (a 30s safety timer force-stops it if they forget). Don't "fix" this back to stop-on-first-result — it was changed deliberately so longer utterances aren't cut off mid-sentence.
- `location` is extracted only via an explicit trigger word: saying "場所は◯◯" puts the word(s) right after "場所" into the location field (`matchLocation` in `script.js`). It is not general place-name recognition — if the user never says "場所", the field is left blank for manual entry on the confirm screen.
