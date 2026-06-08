# chiltern_view — Flutter app

Smallholding tracker front end. Three features:

- **What needs doing** — care tasks ranked by overdue-ness, with one-tap "Done".
- **Potato timeline** — each planting shown as a growth-stage timeline with a progress bar.
- **Egg log** — a quick counter for today's eggs plus week/month/all-time totals.
- **Reminders** — on-device notifications (morning digest + per-task due-date
  pings) for the person this phone belongs to. Set up in Settings → People (mark
  "me") → Reminders. No cloud service required.

## Run

```bash
flutter pub get
flutter run            # pick a device, or: flutter run -d chrome / -d windows
```

## Point it at the backend

The API base URL is set in-app (gear icon → Settings) and persisted, so you can
switch between local dev and the Luma001 host without rebuilding. Defaults:

| Where the app runs        | Base URL                       |
| ------------------------- | ------------------------------ |
| Desktop / web (localhost) | `http://localhost:8000/api`    |
| Android emulator          | `http://10.0.2.2:8000/api`     |
| Real device → Luma001     | `http://luma001:8000/api`      |

The default is in [lib/config.dart](lib/config.dart).

## Layout

```
lib/
  main.dart                  # app shell + bottom navigation
  config.dart                # API base URL (persisted via shared_preferences)
  theme.dart                 # Material 3 theme + status colours
  api/api_client.dart        # typed HTTP client over the DRF API
  models/                    # Animal, Person, CareTask, EggRecord, EggSummary, PotatoPlanting, PotatoStage
  services/                  # notification_service.dart — schedules on-device reminders
  screens/                   # dashboard, potato_timeline, egg_log, settings
  widgets/                   # CareTaskCard, PotatoTimelineCard, AsyncView
test/widget_test.dart        # unit tests for model parsing / labels
```

Checked with `flutter analyze` (clean) and `flutter test` (passing).
