# Chiltern View — project guide for Claude

Smallholding tracker: a **Django + DRF** backend (Docker, runs on the **Luma001**
home server) and a **Flutter** app (`frontend/`) — "what needs doing" dashboard,
potato growth timeline, egg log, per-person task assignment, and on-device
reminders. See [README.md](README.md) for the full picture.

## ⚠️ Web and mobile must stay in lockstep (non-negotiable)

**The web application and the mobile app must ALWAYS have the same features and
the same functionality.** If a feature, screen, or behaviour is added or changed
on one, it MUST be added or changed on the other as part of the same work. Never
ship a feature to only one platform.

- Today both run from the **single Flutter codebase** in `frontend/` (Flutter
  builds web and iOS/Android from the same source), so parity is automatic — keep
  it that way. If a separate web app is ever introduced, this rule still holds:
  every change lands on both, together.
- Before considering any user-facing change done, confirm it builds and works for
  **both web and mobile** (`flutter analyze` + `flutter test`, and a web + device
  smoke check).

## Layout
- `backend/` — Django + DRF API (models, serializers, viewsets). Dockerised.
- `frontend/` — Flutter app for web + iOS/Android; app code in `lib/`.
- `docs/IOS_TESTFLIGHT.md` — getting the app onto iPhones via TestFlight.

## Common commands
- Backend (Docker, primary): `docker compose up -d --build`
- Backend (local dev): make a venv in `backend/`, `pip install -r backend/requirements.txt`, then `python backend/manage.py runserver`
- Flutter checks: `cd frontend && flutter analyze && flutter test`
- Flutter run: `flutter run -d chrome` (web) · `flutter run` (device)

## Conventions
- Backend is no-login (trusted LAN); "people" are lightweight name records, not
  auth users.
- Keep `flutter analyze` clean and `flutter test` green before committing.
- The Flutter UI mirrors the backend's computed fields (overdue ranking, potato
  stages, egg counter); match existing style when extending.
