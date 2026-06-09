# Chiltern View — project guide for Claude

Smallholding tracker: a **Django + DRF** backend (Docker, runs on the **Luma001**
home server), a **Flutter** mobile app (`frontend/`), and a **React** web app
(`web/`) — "what needs doing" dashboard, potato growth timeline, egg log, and
per-person task assignment. See [README.md](README.md) for the full picture.

## ⚠️ Web and mobile must stay in lockstep (non-negotiable)

**The web application and the mobile app must ALWAYS have the same features and
the same functionality.** If a feature, screen, or behaviour is added or changed
on one, it MUST be added or changed on the other as part of the same work. Never
ship a feature to only one platform.

- **Two codebases, one API.** The web app is **React + TypeScript** in `web/`; the
  mobile app is **Flutter** in `frontend/`. They are separate front-ends over the
  same Django API. A feature added to one MUST be added to the other in the same
  piece of work.
- Before considering any user-facing change done, implement and verify it on
  **both**: web (`cd web && npm run build && npm run lint`) and mobile
  (`cd frontend && flutter analyze && flutter test`).
- Current known gap to close: **reminders** exist on mobile (on-device
  notifications) but not yet on web (would need browser Web Push).

## Layout
- `backend/` — Django + DRF API (models, serializers, viewsets). Dockerised.
- `frontend/` — Flutter mobile app (iOS/Android); app code in `lib/`.
- `web/` — React + TypeScript web app (Vite, MUI, React Query); served by nginx.
- `docs/IOS_TESTFLIGHT.md` — getting the mobile app onto iPhones via TestFlight.

## Common commands
- Whole stack (Docker): `docker compose up -d --build` (db + backend + web)
- Backend (local dev): venv in `backend/`, `pip install -r backend/requirements.txt`, then `python backend/manage.py runserver`
- Web checks: `cd web && npm run build && npm run lint`
- Web dev server: `cd web && npm run dev`
- Flutter checks: `cd frontend && flutter analyze && flutter test`
- Flutter run: `flutter run` (device)

## Conventions
- Backend is no-login (trusted LAN); "people" are lightweight name records, not
  auth users.
- Keep `flutter analyze` clean and `flutter test` green before committing.
- The Flutter UI mirrors the backend's computed fields (overdue ranking, potato
  stages, egg counter); match existing style when extending.
