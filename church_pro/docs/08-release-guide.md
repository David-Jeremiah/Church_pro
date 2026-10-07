# 08 · Release Guide (Flutter: Android, iOS, Windows)

## Versioning

- `pubspec.yaml`: `version: MAJOR.MINOR.PATCH+BUILD` (example `0.1.0+1`).
- Increase BUILD for every Play Store upload; follow SemVer for the rest.
- Record changes in `CHANGELOG.md`.

## Environments

| Environment | Purpose | Backend project |
|---|---|---|
| dev | Daily development | your dev Firebase project |
| staging | Pilot churches, release candidates | staging (optional) |
| prod | Public release | your prod Firebase project |

Use flavors and separate entry points (`main_dev.dart`, `main_prod.dart`), each with its own application id suffix (`.dev`) so dev and prod can be installed side by side.

## Pre-release checklist

- [ ] All items in the test plan exit criteria are met
- [ ] `flutter analyze` and `flutter test` pass
- [ ] Version and build number updated; changelog written
- [ ] Prod backend rules deployed and tested; the platform admin (`platformAdmins/{uid}`) created in the prod project
- [ ] Rules tests pass against the emulator; budget/ledger integrity checks pass on pilot data
- [ ] Crash reporting and App Check enabled in prod
- [ ] App name, icon, and splash screen final
- [ ] Privacy policy URL ready and reachable
- [ ] Debug banners, test accounts, and demo repositories removed (`data/in_memory/` not used in prod)
- [ ] Release signing configured

## Build a signed release

1. Create an upload keystore (keep it and its passwords backed up somewhere safe; losing it blocks updates):
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (never commit it) and reference it in `android/app/build.gradle`.
3. Build an app bundle:
   ```bash
   flutter build appbundle --release --flavor prod -t lib/main_prod.dart
   ```
4. Output: `build/app/outputs/bundle/prodRelease/app-prod-release.aab`.
5. Optional: shrink and obfuscate:
   ```bash
   flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
   ```
   Keep the `symbols` folder to decode crash reports.

## Google Play steps

1. Create a Google Play developer account and the app listing.
2. Complete: app content (data safety form, target audience), privacy policy, store listing (description, screenshots, icon, feature graphic).
3. Upload the `.aab` to **Internal testing** first, then **Closed testing** with the pilot church, then **Production**.
4. Use staged rollout (for example 10% → 50% → 100%) and watch crash rates.

Store listing assets: 512×512 icon, 1024×500 feature graphic, at least 2 phone screenshots.

## CI/CD (GitHub Actions outline)

On pull request: `flutter pub get` → `flutter analyze` → `flutter test` → backend rules tests.
On tag `v*`: build the app bundle, upload as an artifact (or to Play internal track with a service account).

## Post-release

- Watch crash-free sessions, ANRs, and slow starts in the first 48 hours.
- Collect feedback from the pilot church weekly.
- Hotfix flow: branch from `main`, fix, bump PATCH and BUILD, test, release with staged rollout.

## Rollback

Play Store releases cannot be un-published once installed, so halt the staged rollout and ship a fixed build quickly. Keep backend changes backward compatible for at least one app version so older builds keep working.

## Support and operations

- A single support contact and a way to report bugs in-app (email or WhatsApp link in settings).
- Budget alerts on the backend project.
- Regular backups of the database and a tested restore procedure.
- Train each new church's staff for 1–2 hours; adoption depends on it.
