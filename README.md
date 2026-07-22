# Castle Watch

Independent Flutter companion for managing game accounts and shield expiry times.

## Run

For an explicit local demonstration mode:

```sh
flutter run --dart-define=DEMO_MODE=true
```

For Supabase authentication and persistence, apply the migrations in
`supabase/migrations` and provide the public project values:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key
```

Or copy `.env.example` to `.env` and run:

```sh
flutter run -d chrome --dart-define-from-file=.env
```

Never provide the Supabase service-role key to the Flutter client.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
