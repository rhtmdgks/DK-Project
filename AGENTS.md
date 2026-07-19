# AGENTS.md

## Cursor Cloud specific instructions

### Project Overview

LAON (라온) — Korean school management Flutter app. Backend is hosted Supabase (PostgreSQL + Auth + Realtime + Edge Functions).

### Prerequisites (already installed on cloud VM)

- Flutter SDK 3.41+ (includes Dart 3.11+, satisfies `sdk: ^3.9.0`)
- Node.js 20.x (for `scripts/seed.js`)
- Google Chrome (for web target testing)

### Running the App

```bash
# Web (headless, no emulator needed)
flutter run -d web-server --web-port=8080 --dart-define-from-file=dart_defines.json

# Or use Chrome device (opens browser)
flutter run -d chrome --dart-define-from-file=dart_defines.json
```

The `dart_defines.json` at project root contains `SUPABASE_URL` and `SUPABASE_ANON_KEY`. Always pass `--dart-define-from-file=dart_defines.json` when running or building.

### Lint / Test / Build

```bash
flutter analyze          # Lint (1 info-level issue expected in home_tab.dart)
flutter test             # Unit/widget tests
flutter build web --dart-define-from-file=dart_defines.json  # Production web build
```

### Key Gotchas

- **No sign-up flow**: Users are pre-created via `scripts/seed.js`. Default test account: student ID `10101`, password `12345678`.
- **First login forces password change**: After login with default password, the app redirects to a password change screen (`must_change_password` flag in `profiles` table).
- **Backend is hosted Supabase**: The app connects to `jxfmonyqfhvcxspuuucm.supabase.co`. No local Supabase setup needed for running/testing the Flutter app.
- **Edge Functions** (NEIS meal proxy, FCM, moderation) are deployed to the hosted Supabase project.
- **Seed script**: `cd scripts && npm install && node seed.js` — requires `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` env vars (or `scripts/.env`).
- **Flutter PATH**: `/opt/flutter/bin` must be in PATH.
