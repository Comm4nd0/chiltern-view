# Chiltern View — web app

React + TypeScript single-page app, kept at **feature parity** with the Flutter
mobile app (see [../CLAUDE.md](../CLAUDE.md)). Same features: the **what needs
doing** dashboard (overdue ranking, per-person filter chips, complete, add task),
the **potato growth timeline**, and the **egg log** with a quick counter, plus
people management and "who am I" in Settings.

Stack: Vite · React · MUI · TanStack Query · React Router.

## Develop

```bash
npm install
npm run dev        # http://localhost:5173, proxies /api -> http://localhost:8000
```

Run the backend too (`docker compose up db backend`, or `manage.py runserver`) so
the proxy has something to talk to.

## Check

```bash
npm run build      # tsc --noEmit + vite build
npm run lint
```

## Production

Built and served by nginx via the root `docker compose up` (see the root README).
nginx serves the SPA and reverse-proxies `/api` to the backend, so the app is
same-origin — there is no API URL to configure.

## Layout

```
src/
  main.tsx              app entry (Query, Theme, Router providers)
  App.tsx               AppBar + tabs + routes
  theme.ts              MUI theme (matches the Flutter green)
  config.ts             "me" person, stored per-browser (localStorage)
  api/types.ts          TS types mirroring the API
  api/client.ts         fetch wrapper (base = /api)
  api/hooks.ts          TanStack Query hooks
  components/           CareTaskCard, PotatoTimelineCard, dialogs, ...
  pages/                Dashboard, PotatoTimeline, EggLog, Settings
```
