#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.29.3}"
FLUTTER_ROOT="${RENDER_FLUTTER_ROOT:-$PWD/.render/flutter}"
FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter"
FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_ARCHIVE}"

mkdir -p "$(dirname "$FLUTTER_ROOT")"

if [ ! -x "$FLUTTER_BIN" ]; then
  rm -rf "$FLUTTER_ROOT"
  mkdir -p "$FLUTTER_ROOT"
  curl -L "$FLUTTER_URL" -o /tmp/flutter.tar.xz
  tar -xf /tmp/flutter.tar.xz -C "$(dirname "$FLUTTER_ROOT")"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter --version
flutter config --enable-web
flutter pub get

BUILD_ARGS=(build web --release)

if [ -n "${API_BASE_URL:-}" ]; then
  BUILD_ARGS+=(--dart-define="API_BASE_URL=${API_BASE_URL}")
fi

if [ -n "${SUPABASE_URL:-}" ]; then
  BUILD_ARGS+=(--dart-define="SUPABASE_URL=${SUPABASE_URL}")
fi

if [ -n "${SUPABASE_ANON_KEY:-}" ]; then
  BUILD_ARGS+=(--dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}")
fi

flutter "${BUILD_ARGS[@]}"
