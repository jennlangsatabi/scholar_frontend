# Deployment Guide

This repository is now prepared for Render static-site deployment and centralized runtime environment variables.

## What Works In This Repo Now

- Flutter web build for deployment on Render
- Runtime environment injection through `--dart-define`
- Centralized environment constants in `lib/config/app_env.dart`
- Static-site routing rewrite for Flutter web deep links

## What Is Not Yet Migrated

This codebase still uses the PHP backend referenced by `API_BASE_URL`.

- Supabase is not yet wired into the app's authentication or data layer
- A Render backend service is not included in this repository
- The existing PHP backend still lives outside this repo

That means this repo can deploy the frontend today, but a full "Supabase database + Render backend" setup still requires either:

- migrating the PHP backend into its own deployable Render service, or
- rewriting the backend/data access layer to use Supabase directly

## Local Environment

Create a `.env` file in the repo root:

```text
API_BASE_URL=https://your-render-backend.onrender.com
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-public-anon-key
```

Run locally:

```bash
dart pub get
flutter run -d chrome --dart-define-from-file=.env
```

Build locally:

```bash
flutter build web --release --dart-define-from-file=.env
```

## Render Frontend Deploy

This repo includes:

- `render.yaml`
- `tools/render_build.sh`

On Render:

1. Create a new Static Site from this repository.
2. Confirm the build command is `bash tools/render_build.sh`.
3. Confirm the publish directory is `build/web`.
4. Add these environment variables in Render:
   - `API_BASE_URL`
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

The blueprint also rewrites `/*` to `/index.html` so Flutter web routes keep working on refresh.

## Render Backend Deploy

If you want to keep the current PHP backend, deploy it as a separate Render Web Service.

A ready-to-copy scaffold is included in:

- `backend_render/Dockerfile`
- `backend_render/.dockerignore`
- `backend_render/render.backend.yaml`
- `backend_render/connection.php.example`
- `backend_render/README.md`

That backend should be placed in its own repository based on your current PHP source from:

`C:\xampp\htdocs\scholar_php`

After the backend is deployed, set this in the frontend Static Site:

```text
API_BASE_URL=https://your-backend-service.onrender.com
```

## Supabase Notes

You can use Supabase today as the hosted database for a separate backend service, but this Flutter app is not yet reading from Supabase directly.

If you want the app itself to authenticate against Supabase and query Supabase tables, the next step is a source migration:

- add `supabase_flutter`
- initialize Supabase in `main.dart`
- replace the current PHP login and API flow
- adapt the admin and scholar screens to Supabase tables and policies
