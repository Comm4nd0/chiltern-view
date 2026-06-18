# Chiltern View — project guide for Claude

**Home management application** for **Marco and Claire** to run their house and
smallholding. A **Django + DRF** backend (Docker, on the **Luma001** home server),
a **Flutter** mobile app (`frontend/`), and a **React** web app (`web/`). See
[README.md](README.md) for the full picture.

## Product vision (north star)

A single place to manage the home. Priorities, in order:
1. **Front page = an at-a-glance dashboard** of the current state of the house —
   what needs doing, animals, crops, eggs, and whatever else we add. Not just a
   task list; an overview.
2. **A strong to-do list**: create tasks, mark them complete, and get **reminders
   when tasks are due or overdue**.
3. **Manage the animals and the crops** with **built-in knowledge**, and stay
   **easily extensible** to other things we want to track later.

Built for two people (Marco + Claire); both must always get the same experience
(see the parity rule below).

### Structure & built-in knowledge (the current direction)
Navigation: **Home · To do · Crops · Animals** (no separate Potatoes/Eggs tabs).
Potatoes are a crop; eggs are tracked under the chickens (an animal).
- **Crop catalog** (code-defined): each crop has its own growth **stages + timing**
  — potatoes keep their detailed stages; carrots, cucumbers, etc. get theirs.
  Adding a crop picks a type from a dropdown; an unknown crop gets added to the
  catalog in code so the app "knows" it.
- **Animal-type catalog** (code-defined): chicken, goat, horse, tortoise, dog, …
  each with its own default care reminders.
- **Auto reminders**: adding a crop creates reminders at each growth stage; adding
  an animal creates that type's care reminders. Implement as auto-generated
  `CareTask`s so the existing to-do + reminder system surfaces them.
- **Weather-aware watering**: use local weather (the holding's location) to decide
  when to remind about watering crops.

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
- Reminders exist on **both** platforms: mobile schedules on-device
  notifications (`frontend/lib/services/notification_service.dart`); web uses
  browser Web Push — a `PushSubscription` model, `/api/push/*` endpoints, a
  service worker (`web/public/sw.js`), and the `send_push_reminders` management
  command run by the compose `scheduler` service. Web push needs `VAPID_*` env
  vars on the server (generate once with `npx web-push generate-vapid-keys`;
  see `.env.example`); it is silently disabled when they're unset. Keep the
  digest wording identical on both platforms.

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

## Deployment (Luma001 + Caddy)

Live stack runs on **Luma001** (`178.104.29.66`, SSH as root) in
`/root/chiltern-view`, via `docker compose` (db + backend + web). **Luma001 also
hosts other production sites behind a shared, dockerised Caddy — never disrupt
them.**

- Host ports, chosen to avoid conflicts with existing services: web nginx
  **8007**, backend **8009**. Always check `ss -tln` before picking ports.
- Secrets live in `/root/chiltern-view/.env` on the server (not in git).
- **Uploaded photos** (animals, crops) live on the `media` Docker volume, shared
  between the backend (writes `/app/media`) and the web nginx, which serves
  `/media/` from it directly. The volume persists across redeploys.
- Redeploy: `cd /root/chiltern-view && git pull && docker compose up -d --build`.
- **Caddy** is the container `caddy-caddy-1`; config at `/root/caddy/Caddyfile`.
  Each site reverse-proxies to the Docker host gateway `172.17.0.1:<host-port>`.
  Our block:

  ```
  chilternview.lumatechsolutions.co.uk {
      reverse_proxy 172.17.0.1:8007
      encode gzip
  }
  ```

  Edit Caddy safely: back up the Caddyfile, append/modify, then
  `docker exec caddy-caddy-1 caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile`,
  and only on success `docker exec caddy-caddy-1 caddy reload --adapter caddyfile --config /etc/caddy/Caddyfile`
  (zero-downtime). Afterwards, verify the existing sites still serve.
- DNS: `chilternview.lumatechsolutions.co.uk` must A-record to `178.104.29.66`
  for Caddy to issue HTTPS.
- **Security — read-only mode (DRF `IsAuthenticatedOrReadOnly`):** reading is
  **public** (anyone can browse `GET`s, no login); **creating, editing or
  deleting needs a token** (`Authorization: Token <key>`). Exceptions:
  `GET /api/health/` and `POST /api/auth/login/` are fully open; `GET
  /api/auth/me/` and the `GET /api/export/...` CSV backups require a token even
  though they're GETs. Each household user (Marco, Claire) is an `auth.User`
  linked to a `Person` (`Person.user`); create the accounts in **Django admin**
  (`/admin/`) — the `DJANGO_SUPERUSER_*` env bootstrap makes the first admin.
  Both clients show the app **read-only when signed out** and prompt sign-in when
  a write is attempted (web: a login dialog; mobile: a login modal). Tokens are
  issued on login and revoked on sign-out; clients persist the token (web
  `localStorage`, Flutter `shared_preferences`) and send it on every request.
  Auth endpoints: `POST /api/auth/login/`, `POST /api/auth/logout/`,
  `GET /api/auth/me/`.

## Conventions
- Backend is **read-only without login**; writes need a token (DRF
  `IsAuthenticatedOrReadOnly`; **internet-facing via Caddy** — see the security
  note above). "people" are lightweight name records, each optionally linked to
  an `auth.User` for login (`Person.user`).
- Keep `flutter analyze` clean and `flutter test` green before committing.
- The Flutter UI mirrors the backend's computed fields (overdue ranking, potato
  stages, egg counter); match existing style when extending.
