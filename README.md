# thermolox

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase Setup

THERMOLOX erwartet die Supabase-Konfiguration über Build-Defines. Die Keys
werden nicht im Repo gespeichert.

Beispiel `supabase.json` (lokal, nicht committen):

```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-key"
}
```

Starten mit Datei:

```bash
flutter run --dart-define-from-file=supabase.json
```

Oder direkt per Defines:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Analytics Events Table

Run the SQL in `supabase/analytics_events.sql` inside the Supabase SQL editor.
This creates the `public.analytics_events` table with RLS (authenticated insert/select).

If you want to allow anonymous events, add a separate insert policy that
permits `user_id is null` for anon users.
