# Putting Chiltern View on your & Claire's iPhones (TestFlight)

This gets the Flutter app onto two iPhones via **TestFlight**, with a one-command
release after the initial setup. You need a **Mac with Xcode** and an **Apple
Developer account** ($99/yr).

App facts:
- Bundle ID: `uk.co.chilternview.app`
- Display name: **Chiltern View**
- Flutter project: `frontend/`

> Note: the app talks to the backend over plain HTTP on your LAN. The iOS
> `Info.plist` already allows this (`NSAllowsLocalNetworking`). The first time the
> app reaches Luma001, iOS may ask to allow local-network access — tap **Allow**.

> **Login required (since the auth update):** ship a **new build** (bump `+N` in
> `frontend/pubspec.yaml`, then `fastlane beta` per §5) so testers get the version
> with the login screen, and make sure each tester has an app account (README →
> *Authentication*).

---

## 1. One-time Apple setup

1. **Enrol** in the Apple Developer Program: <https://developer.apple.com/programs/>.
2. In **App Store Connect** (<https://appstoreconnect.apple.com>) → **Apps → +**
   → **New App**:
   - Platform: iOS
   - Name: `Chiltern View` (must be globally unique on the store; tweak if taken,
     e.g. `Chiltern View — Smallholding`)
   - Bundle ID: select/create `uk.co.chilternview.app`
   - SKU: anything, e.g. `chilternview`
   You do **not** need to submit to the App Store — TestFlight only.
3. **App Store Connect → Users and Access → add Claire** (her Apple ID email) as a
   user, or add her as an **Internal Tester** in step 4. Internal testers (up to
   100) skip Beta App Review, so builds are available in minutes.

## 2. Configure signing in Xcode (once)

```bash
cd frontend
flutter pub get
open ios/Runner.xcworkspace      # the .xcworkspace, not .xcodeproj
```

In Xcode, select the **Runner** target → **Signing & Capabilities**:
- Tick **Automatically manage signing**
- **Team**: your Apple Developer team
- Confirm **Bundle Identifier** = `uk.co.chilternview.app`

## 3. First build & upload (from Xcode)

Doing the first one in Xcode creates your distribution certificate and
provisioning profile, which the fastlane path then reuses.

1. Plug in / select **Any iOS Device (arm64)** as the destination.
2. **Product → Archive**.
3. When the Organizer opens: **Distribute App → App Store Connect → Upload**.
4. Wait for it to process (a few minutes) under **App Store Connect → your app →
   TestFlight**.

## 4. Add testers & install

In **App Store Connect → your app → TestFlight**:
1. Under **Internal Testing**, create a group and add yourself and Claire.
2. You'll each get an email → install the **TestFlight** app from the App Store →
   accept the invite → install Chiltern View.
3. On first launch you'll get a **login screen** — sign in with the username and
   password created for you in Django admin (README → *Authentication*). Then allow
   **notifications** (for reminders) and **local network** (to reach Luma001), and
   in Settings set the API URL and turn on reminders. (Signing in auto-selects
   "you" for task assignment.)

## 5. Releasing updates with one command (fastlane)

After signing works (step 3), subsequent releases are automated.

**One-time fastlane setup:**
1. Install Ruby deps:
   ```bash
   cd frontend/ios
   bundle install
   ```
2. Create an **App Store Connect API key**: App Store Connect → **Users and
   Access → Integrations → App Store Connect API → +**. Role: **App Manager**.
   Download the `AuthKey_XXXXXXXXXX.p8` (you can only download it once) and note
   the **Key ID** and **Issuer ID**.
3. Point fastlane at it (e.g. add to `frontend/ios/.env`, which is git-ignored):
   ```bash
   export ASC_KEY_ID=XXXXXXXXXX
   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   export ASC_KEY_PATH=/absolute/path/to/AuthKey_XXXXXXXXXX.p8
   ```

**Each release:**
1. Bump the build number in `frontend/pubspec.yaml` — the part after `+`:
   `version: 0.1.0+2` → `0.1.0+3` … (TestFlight requires an increasing build
   number).
2. Run:
   ```bash
   cd frontend/ios
   bundle exec fastlane beta
   ```
   This runs `flutter build ipa` and uploads to TestFlight. Testers get the update
   automatically.

## 6. Optional: CI on push

A macOS GitHub Actions runner can run `fastlane beta` on a tag push so releases
are "git push" easy. It needs the API key and signing assets as repo secrets
(via `fastlane match` or imported certs). This is worth adding once the manual
flow above works — ask and I'll wire it up.

---

### Troubleshooting

- **App can't reach the server**: confirm the phone is on the same network as
  Luma001, the API URL in Settings is right (e.g. `http://luma001:8000/api`), and
  `DJANGO_ALLOWED_HOSTS` on the backend includes that hostname. Tap **Allow** on
  the local-network prompt.
- **"No profiles found" / signing errors**: re-open `ios/Runner.xcworkspace`, make
  sure a Team is selected and automatic signing is on.
- **Build number already used**: bump `+N` in `pubspec.yaml`.
- **No reminders**: in Settings, make sure you've marked which person is *you* and
  allowed notifications; reminders only cover tasks assigned to that person.
