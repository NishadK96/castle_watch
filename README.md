# Castle Watch

Independent Flutter companion for managing multiple game accounts and monitoring shield expiry times. Castle Watch is not affiliated with Lords Mobile or its publisher.

## Features

- Responsive Material 3 dashboard for mobile, tablet, and web
- Supabase email/password authentication and protected routes
- Account management with favorites, archive, search, and filters
- UTC-backed shield countdowns and atomic shield replacement
- PostgreSQL migrations with ownership constraints and Row Level Security
- Explicit local demo mode for UI development

## Supabase setup

Apply the migrations in `supabase/migrations` to your Supabase project. Copy the environment template and add the public project values:

```sh
cp .env.example .env
```

Run the web application:

```sh
flutter run -d chrome --dart-define-from-file=.env
```

Never put a Supabase service-role key in the Flutter client.

## Demo mode

```sh
flutter run --dart-define=DEMO_MODE=true
```

## Quality checks

```sh
flutter analyze
flutter test
```

## Vercel deployment

The repository includes `vercel.json` and a Flutter Web build script. In the
Vercel project, add these variables for Production, Preview, and Development:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `WEB_VAPID_KEY`

Keep the framework preset as **Other**. The repository configuration builds to
`build/web` and rewrites client-side routes to `index.html`.

`WEB_VAPID_KEY` is the public key from Firebase Console → Project settings →
Cloud Messaging → Web Push certificates. Firebase service-account JSON belongs
only in Supabase Edge Function secrets.
