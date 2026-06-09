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

## Deployment (Luma001 + Caddy)

Live stack runs on **Luma001** (`178.104.29.66`, SSH as root) in
`/root/chiltern-view`, via `docker compose` (db + backend + web). **Luma001 also
hosts other production sites behind a shared, dockerised Caddy — never disrupt
them.**

- Host ports, chosen to avoid conflicts with existing services: web nginx
  **8007**, backend **8009**. Always check `ss -tln` before picking ports.
- Secrets live in `/root/chiltern-view/.env` on the server (not in git).
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
- **Security:** the app has no login. Once it's reachable on the public domain,
  anyone with the URL can read/write the data. Consider a Caddy `basic_auth`
  gate (which would also require sending those credentials from the web and
  Flutter clients).

## Conventions
- Backend is no-login (trusted LAN; **now also internet-facing via Caddy** — see
  the security note above); "people" are lightweight name records, not auth users.
- Keep `flutter analyze` clean and `flutter test` green before committing.
- The Flutter UI mirrors the backend's computed fields (overdue ranking, potato
  stages, egg counter); match existing style when extending.
