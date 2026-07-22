#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "Missing SUPABASE_URL or SUPABASE_ANON_KEY in Vercel Environment Variables."
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_ROOT="${HOME}/flutter"
  if [[ ! -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_ROOT}"
  fi
  export PATH="${FLUTTER_ROOT}/bin:${PATH}"
fi

flutter config --enable-web
flutter pub get
flutter build web --release \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
