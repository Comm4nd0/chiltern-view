# Chiltern View

A smallholding tracker: a **Django + DRF** REST backend (containerised for the
Luma001 Docker host), a **Flutter** mobile app, and a **React** web app. The web
and mobile apps are kept at feature parity (see [CLAUDE.md](CLAUDE.md)).

```
chiltern-view/
├── backend/            Django + DRF API (Dockerised)
│   ├── config/         project settings, urls, wsgi/asgi
│   ├── tracker/        models, serializers, viewsets, admin
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/           Flutter app — mobile (iOS/Android)
├── web/                React + TypeScript web app (Vite, MUI, nginx)
├── docker-compose.yml  Postgres + backend + web, for Luma001
└── .env.example        copy to .env and edit before deploying
```

## What it tracks

| Model            | Purpose                                                              |
| ---------------- | ------------------------------------------------------------------- |
| `Animal`         | Animals/colonies kept on the holding (species, breed, dates).       |
| `Person`         | Who looks after the holding; tasks are assigned to a person.        |
| `CareTask`       | Recurring husbandry jobs with a **recurrence interval in days**, optionally assigned to a `Person`. |
| `LogEntry`       | Dated notes, optionally tied to an animal or task.                  |
| `EggRecord`      | Eggs collected per day (one row per day/source, unique).            |
| `PotatoPlanting` | Seed-potato plantings that drive the growth timeline.               |

`Person` is deliberately lightweight (just a name), optionally linked to a login
account (`Person.user → auth.User`; see [Authentication](#authentication)).
Deleting a person leaves their tasks intact but unassigned (`on_delete=SET_NULL`).
The Flutter app remembers which person is "you" on each device (Settings → People)
and defaults the dashboard to your tasks.

`CareTask` computes `next_due`, `days_overdue` and `status`
(`overdue`/`due_today`/`upcoming`) from `last_completed + recurrence_interval_days`.
`PotatoPlanting` computes its growth `stages`, `current_stage`, `estimated_harvest`
and `progress` from the planting date and category (first early → maincrop).

## Run the backend on Luma001 (Docker)

```bash
cp .env.example .env          # then edit secrets / allowed hosts
docker compose up -d --build
```

This starts Postgres, the API (gunicorn) on port 8000, and the React web app
(nginx) on `WEB_PORT` (default 8080). On boot the backend applies migrations and
— if `DJANGO_SUPERUSER_USERNAME`/`PASSWORD` are set — creates an admin user.
Health check: `GET /api/health/`. The web app is then at `http://luma001:8080`.

## Authentication

The API requires a login (DRF **token auth**). Every endpoint needs an
`Authorization: Token <key>` header except `GET /api/health/` and
`POST /api/auth/login/`. There's no sign-up — the household accounts are created
by hand:

1. Ensure an admin exists (the `DJANGO_SUPERUSER_*` env vars create one on first
   container boot, or run `python manage.py createsuperuser`).
2. In Django admin (`/admin/`) create a **User** for each person (Marco, Claire)
   and set their password.
3. Edit the matching **Person** record and set its **User** field, so the app can
   show who's signed in and default task assignment to "you".

Endpoints: `POST /api/auth/login/` `{username, password}` → `{token, user}`;
`POST /api/auth/logout/` (revokes the token); `GET /api/auth/me/`. Both apps store
the token (browser `localStorage` / `shared_preferences`), send it on every
request, and return to the login screen on a `401`.

## Run the backend locally (no Docker)

A virtualenv is already present at `backend/.venv` (created during scaffolding;
git-ignored). With no `DATABASE_URL` set it uses SQLite and `DEBUG=True`.

```powershell
backend\.venv\Scripts\python.exe backend\manage.py migrate
backend\.venv\Scripts\python.exe backend\manage.py runserver
```

Browse the API at <http://localhost:8000/api/> (DRF browsable API) and the admin
at <http://localhost:8000/admin/>.

## API

Base path `/api/`. Standard REST CRUD on each collection, plus:

| Method & path                          | Purpose                                                |
| -------------------------------------- | ------------------------------------------------------ |
| `GET  /api/health/`                    | Liveness probe.                                        |
| `GET  /api/care-tasks/dashboard/`      | Active tasks ranked most-overdue-first. `?include=due`, `?assignee=<id>\|unassigned` |
| `POST /api/care-tasks/{id}/complete/`  | Mark done (`{date?, note?}`); writes a `LogEntry`.     |
| `GET  /api/potato-plantings/timeline/` | Plantings + stages, oldest first. `?show=growing\|all` |
| `POST /api/egg-records/increment/`     | Quick counter — atomically add to a day's tally.       |
| `GET  /api/egg-records/summary/`       | Totals for today / week / month / all time.            |
| `GET  /api/crops/board/`               | Growing crops + stage/progress, wrapped for Home Assistant. |

Collections: `/api/people/`, `/api/animals/`, `/api/care-tasks/`,
`/api/log-entries/`, `/api/egg-records/`, `/api/potato-plantings/`. All support
filtering, search and `?ordering=`. Lists are paginated (50/page); the custom
actions above are not. `care-tasks` can be filtered by `?assignee=<id>`.

## Run the Flutter app

```bash
cd frontend
flutter pub get
flutter run            # or: flutter run -d chrome / -d windows
```

Set the API address in-app (gear icon → Settings) — e.g. `http://luma001:8000/api`.
See [frontend/README.md](frontend/README.md) for per-platform URLs.

## Run the web app

In production it's built and served by nginx as part of `docker compose up`
(above), at `http://luma001:8080`. nginx serves the SPA and reverse-proxies
`/api` to the backend, so the web app is same-origin — no API URL to configure.

For local development:

```bash
cd web
npm install
npm run dev            # Vite dev server on http://localhost:5173
```

The dev server proxies `/api` to `http://localhost:8000`, so run the backend too.
Checked with `npm run build` (tsc + Vite) and `npm run lint`. See
[web/README.md](web/README.md).

## Reminders (on-device)

Each phone shows local notifications reminding **its** person of their tasks —
no cloud, no Firebase, no Apple Developer account needed for the notifications.
Because care tasks recur on a fixed interval, the app computes upcoming due dates
and registers reminders with the OS, so they fire even when the app is closed.

- **Morning digest** — a daily summary of what's due/overdue for you.
- **Per-task ping** — a reminder on each task's due date.

Per phone: **Settings → People**, mark which person is *you*, then under
**Reminders** turn them on and pick a time. Reminders cover a rolling 14-day
window and refresh whenever the app opens or you add/complete a task. Only tasks
assigned to that phone's person generate reminders. Times use Europe/London (set
in [notification_service.dart](frontend/lib/services/notification_service.dart)).

### Installing on iPhone

A self-built Flutter app isn't on the App Store, so putting it on an iPhone needs
a Mac with Xcode:

- **Free Apple ID** — installs, but the signature **expires after 7 days** and the
  app stops opening until re-signed.
- **Apple Developer account ($99/yr)** — sign for a year and push to both phones
  via **TestFlight** (the practical option for two phones).

The local notifications need no paid account — only the install method does.
Step-by-step TestFlight setup with a one-command fastlane release is in
**[docs/IOS_TESTFLIGHT.md](docs/IOS_TESTFLIGHT.md)**. The iOS `Info.plist` already
permits the app's plain-HTTP calls to Luma001 over the local network
(`NSAllowsLocalNetworking`).

## Home Assistant

A third front-end over the same API: pull eggs, crop stages, the to-do list,
animals and weather onto a Home Assistant dashboard as native sensors, with
buttons to add eggs and complete tasks — no add-on to install, just Home
Assistant's built-in REST integration. Paste-in config (`homeassistant/`) and
setup steps are in **[docs/HOME_ASSISTANT.md](docs/HOME_ASSISTANT.md)**.

## Verification status

- Backend: migrations generated, `manage.py check` clean, 13/13 API smoke checks
  passed (overdue ranking, task completion, egg counter, potato stages).
- Frontend (Flutter): `flutter analyze` clean, `flutter test` passing.
- Web (React): `npm run build` (tsc + Vite) clean, `npm run lint` clean.
- Reminders: Dart layer verified (analyze + tests). The iOS/Android **native build
  wasn't compiled here** (no Mac; Windows can't build iOS, and plugin builds need
  Developer Mode) — the native config follows the flutter_local_notifications docs.
- The Docker **image build** wasn't run here (Docker daemon wasn't started on the
  dev machine); `docker compose up --build` is expected to work on Luma001.

## Notes

- Source is on GitHub: <https://github.com/Comm4nd0/chiltern-view>.
- Web and mobile share the Django API and are kept at feature parity per
  [CLAUDE.md](CLAUDE.md). Known gap: task reminders exist on mobile (on-device
  notifications) but not yet on web (would need browser Web Push).
