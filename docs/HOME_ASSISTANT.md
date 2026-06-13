# Chiltern View on Home Assistant

Bring the smallholding dashboard into Home Assistant: eggs, crop stages, the
to-do list, animals and weather as native HA sensors, plus buttons to add eggs
and complete tasks. It works against the live API with **no add-on to install**
— Home Assistant's built-in [RESTful integration](https://www.home-assistant.io/integrations/rest/)
polls the same endpoints the web and mobile apps use.

Two files do the work, both in [`homeassistant/`](../homeassistant):

| File | What it is |
| --- | --- |
| `chiltern_view.yaml` | The sensors (`rest:`) and actions (`rest_command:`), packaged so you can drop it in whole. |
| `dashboard.yaml` | A Lovelace dashboard wiring those sensors into cards. |

## How it talks to the API

Home Assistant calls the same REST API as the apps. Pick the URL HA can reach
and use it everywhere in `chiltern_view.yaml`:

- `https://chilternview.lumatechsolutions.co.uk` — public, via Caddy → the web
  nginx (which proxies `/api/` to the backend). Best if HA isn't on the LAN.
- `http://<luma001-ip>:8007` — LAN, via the web nginx.
- `http://<luma001-ip>:8009` — LAN, straight to the backend.

The API is currently **open** (no login — the gate was dropped for the kiosk),
so no credentials are needed. Anyone who can reach the URL can read and write,
which is fine on a trusted LAN. If you re-enable token auth later, add a header
to each `rest:` resource and `rest_command:`:

```yaml
headers:
  Authorization: "Token <your-key>"
```

## Setup

1. **Copy the package.** Put `chiltern_view.yaml` at
   `<ha-config>/packages/chiltern_view.yaml` (create the `packages` folder if
   needed).

2. **Enable packages** in `configuration.yaml` (once):

   ```yaml
   homeassistant:
     packages: !include_dir_named packages
   ```

3. **Set the server URL.** Edit `chiltern_view.yaml` and replace the
   `chilternview.lumatechsolutions.co.uk` URLs with whichever option above HA
   can reach.

4. **Restart Home Assistant.** Check **Developer Tools → States** for the new
   `sensor.chiltern_*` entities (e.g. `sensor.chiltern_eggs_today`).

5. **Add the dashboard.** Either:
   - **UI mode:** Settings → Dashboards → Add dashboard → open it → ⋮ → *Edit in
     YAML*, then paste the cards from `dashboard.yaml`; or
   - **YAML mode:** reference `dashboard.yaml` from your `lovelace:` config.

## What you get

- **Sensors** — `sensor.chiltern_eggs_today`, `…_eggs_this_week`,
  `…_tasks_overdue`, `…_tasks_due_today`, `…_tasks_upcoming`, `…_crops_growing`,
  `…_next_harvest`, `…_animals`, `…_tasks` (top five rides along as an
  attribute), `…_crops` (each growing crop with stage, progress and harvest date
  as attributes), and `…_weather` (today, the next days, and any frost warning).
  Because they're real entities you can also use them in HA automations — e.g.
  *announce overdue tasks at 6pm* or *notify when a frost warning appears*.
- **Add eggs** — the dashboard's buttons call `rest_command.chiltern_add_egg`,
  which POSTs to the same atomic counter the apps use. Tap to add 1, or a clutch
  of 6. Pass `count:` (and optionally `source:`) in the button's `data:`.
- **Crop stages** — the *Crops* card lists everything in the ground with its
  current growth stage and % to harvest, the same data as the app's crop cards.

### Completing tasks from HA (optional)

`rest_command.chiltern_complete_task` marks a task done — it needs the task's
numeric `id` (the `top` attribute on `sensor.chiltern_tasks` carries `id` and
`name`):

```yaml
# Example: a button that completes a specific task by id.
- type: button
  name: Shut the hens in
  icon: mdi:check
  tap_action:
    action: perform-action
    perform_action: rest_command.chiltern_complete_task
    data:
      task_id: 42
```

Because task ids are dynamic, the core button card can't pick one at tap time.
For a "complete the next task" control, drive an `input_select` from the
`top` attribute and a script that reads the chosen id, or just tick tasks off in
the web/mobile app. Completing recurring tasks reschedules them; completing a
one-off (a growth-stage or harvest reminder) closes it — identical to the apps.

## Refresh rate

The overview polls every 5 minutes and the crop board every 10 (`scan_interval`
in `chiltern_view.yaml`); adjust to taste. Egg/task buttons take effect
immediately on the server, and the matching sensor catches up on its next poll —
call `homeassistant.update_entity` after a button press if you want it instant.

## Keeping it in step with the apps

This is a third front-end over the **same API**, so it inherits new fields for
free. If the dashboard ever gains a brand-new endpoint or response field you
want surfaced here, add a sensor/command in `chiltern_view.yaml` and a card in
`dashboard.yaml` to match — the web and Flutter apps remain the source of truth
for behaviour.
