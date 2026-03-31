# scholar_frontend

Scholarship Management System frontend built with Flutter and connected to a PHP/MySQL backend.

## Current Stack

- Frontend: Flutter
- Backend API: PHP under `C:\xampp\htdocs\scholar_php`
- Database: MySQL
- Optional local container stack: `docker-compose.yml`

## Running the App

Install packages:

```bash
dart pub get
```

Run on web:

```bash
flutter run -d chrome
```

If login requests fail in Chrome with `ClientException: Failed to fetch`, the PHP endpoint is usually reachable but blocked by the browser because `flutter run` serves the app from a different origin and the PHP server is not returning CORS headers yet.

Run with a custom backend URL:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1/scholar_php
```

Build web release:

```bash
flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1/scholar_php
```

For deployment-oriented env management, copy `.env.example` to `.env` and use:

```bash
flutter run -d chrome --dart-define-from-file=.env
flutter build web --release --dart-define-from-file=.env
```

## Backend Configuration

The app uses `lib/services/api_config.dart` and `lib/services/backend_api.dart`.

Default API targets:

- Web: `http://127.0.0.1/scholar_php`
- Android emulator: `http://10.0.2.2/scholar_php`
- Other platforms: `http://127.0.0.1/scholar_php`

Override the backend at build or run time with `API_BASE_URL`.

## Web Dev Note

`flutter run -d chrome` uses a Flutter dev server such as `http://localhost:xxxxx`, while XAMPP/Apache typically serves PHP from `http://127.0.0.1/scholar_php`. Because that is a different origin, Chrome requires the PHP backend to answer CORS preflight requests.

If you see `ClientException: Failed to fetch`, use one of these approaches:

- Add CORS headers to the PHP backend, including `Access-Control-Allow-Origin`, `Access-Control-Allow-Methods`, and `Access-Control-Allow-Headers`.
- Build the Flutter web app and serve the generated files from Apache/XAMPP so the frontend and PHP API share the same origin.

## Deployment Notes

The deployed architecture reflected by the source is:

- Flutter web frontend
- PHP API hosted from `scholar_php`
- MySQL database

If you want a server-based local stack, `docker-compose.yml` defines:

- `nginx`
- `php`
- `mysql`
- `redis`

## Deployment

This repo now includes:

- `render.yaml` for Render Static Site deployment
- `tools/render_build.sh` for reproducible Flutter web builds on Render
- `lib/config/app_env.dart` for centralized runtime env values
- `DEPLOYMENT.md` for the current deployment workflow and migration notes

Important: the current app still talks to the PHP backend through `API_BASE_URL`. Supabase environment variables are scaffolded for a future migration, but Supabase is not yet the active data layer in this Flutter codebase.

## Database Tables

Main tables referenced by the Flutter app and backend docs:

- `users`
- `scholars`
- `applications`
- `requirements`
- `submissions`
- `notifications`
- `replies`
- `announcements`
- `duty_logs`
- `evaluations`

## Database Relations

These are the intended application-level relations based on the current frontend/backend integration:

- `users.id -> scholars.user_id`
- `users.id -> notifications.user_id`
- `users.id -> replies.user_id`
- `scholars.scholar_id -> applications.scholar_id`
- `applications.application_id -> submissions.application_id`
- `requirements.requirement_id -> submissions.requirement_id`
- `notifications.notification_id -> replies.notification_id`
- `scholars.scholar_id -> evaluations.scholar_id`
- `users.id -> announcements.created_by` if the backend stores author ownership

Relationship summary:

```text
users
  |- scholars
  |    |- applications
  |         |- submissions
  |              |- requirements
  |    |- evaluations
  |
  |- notifications
  |    |- replies
  |
  |- announcements
```

## Reference Docs

- Backend/API overview: `BACKEND_INTEGRATION.md`
- Evaluation table schema: `tools/evaluation_schema.sql`
