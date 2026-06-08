# Chiltern View

A smallholding tracker: a **Django + DRF** REST backend (containerised for the
Luma001 Docker host) and a **Flutter** app for day-to-day use.

```
chiltern-view/
├── backend/            Django + DRF API (Dockerised)
│   ├── config/         project settings, urls, wsgi/asgi
│   ├── tracker/        models, serializers, viewsets, admin
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/           Flutter app (dashboard, potato timeline, egg log)
├── docker-compose.yml  Postgres + backend, for Luma001
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

`Person` is deliberately lightweight (just a name) — this is a no-login app on a
trusted network. Deleting a person leaves their tasks intact but unassigned
(`on_delete=SET_NULL`). The Flutter app remembers which person is "you" on each
device (Settings → People) and defaults the dashboard to your tasks.

`CareTask` computes `next_due`, `days_overdue` and `status`
(`overdue`/`due_today`/`upcoming`) from `last_completed + recurrence_interval_days`.
`PotatoPlanting` computes its growth `stages`, `current_stage`, `estimated_harvest`
and `progress` from the planting date and category (first early → maincrop).

## Run the backend on Luma001 (Docker)

```bash
cp .env.example .env          # then edit secrets / allowed hosts
docker compose up -d --build
```

This starts Postgres and the API (gunicorn) on port 8000. On boot the backend
applies migrations and — if `DJANGO_SUPERUSER_USERNAME`/`PASSWORD` are set —
creates an admin user. Health check: `GET /api/health/`.

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

## Verification status

- Backend: migrations generated, `manage.py check` clean, 13/13 API smoke checks
  passed (overdue ranking, task completion, egg counter, potato stages).
- Frontend: `flutter analyze` clean, `flutter test` passing.
- The Docker **image build** wasn't run here (Docker daemon wasn't started on the
  dev machine); `docker compose up --build` is expected to work on Luma001.

## Notes

- `git init` if you want version control — `.gitignore` and `.gitattributes`
  (which keeps `entrypoint.sh` LF on Windows) are already in place.
- The Flutter UI logic (overdue ranking, potato stages, egg counter) mirrors the
  backend's computed fields and is structured to fold in your React prototype's
  exact logic when you share it.
