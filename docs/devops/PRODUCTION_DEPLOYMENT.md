# 1. DevOps Architecture

AI Learn production operations are organized into four modules:

- `deployment_pipeline`: GitHub Actions workflows for quality gates, Android builds, and Firebase deploys.
- `environment_config_manager`: environment JSON files (`development`, `staging`, `production`) + Firebase project aliases.
- `monitoring_system`: Crashlytics + Firebase Performance in app, analytics/crash anomaly checks in backend.
- `release_manager`: tag-based release to Play internal track with staged promotion.

Flow:
commit -> CI checks -> staging deploy -> production deploy -> release artifact -> Play upload.

# 2. CI/CD Pipeline Design

Implemented pipeline (`.github/workflows/mobile-ci-cd.yml`):

- **flutter-quality** job:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test --coverage`
- **android-build** job:
  - keystore decode from secrets
  - `flutter build appbundle --release --dart-define-from-file=config/env/<env>.json`
  - upload AAB artifact
- **firebase-functions-deploy** job:
  - install firebase-tools
  - authenticate with `GCP_SA_KEY`
  - deploy only functions via script
- **play-store-release** job:
  - trigger on semantic version tags
  - upload AAB to Play internal track

# 3. Environment Configuration

Environment files:

- `config/env/development.json`
- `config/env/staging.json`
- `config/env/production.json`

Each includes:

- `appEnv`
- `firebaseProjectId`
- `apiBaseUrl`
- `enableCrashlytics`
- `enablePerformanceMonitoring`

Firebase environment mapping configured in `.firebaserc` and `firebase.json`.

# 4. Secrets Management

Secrets expected in GitHub Actions:

- `GCP_SA_KEY` (Firebase deploy service account JSON)
- `ANDROID_KEYSTORE_B64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`
- `PLAY_SERVICE_ACCOUNT_JSON`

Guidelines:

- never commit keys, certs, or service-account JSON
- rotate credentials quarterly
- separate service accounts for staging vs production
- least-privilege IAM (Functions Admin + limited Firebase roles)

# 5. Monitoring Infrastructure

App-side monitoring:

- Firebase Crashlytics for fatal/non-fatal captures
- Firebase Performance Monitoring for runtime traces

Backend monitoring:

- analytics rollups available in Firestore collections:
  - `analytics_daily`
  - `retention_metrics`
  - `content_metrics`

Alerting-ready signals:

- DAU drop
- crash-rate increase
- content generation/deploy failures

# 6. Crash Reporting Integration

`lib/main.dart` now:

- enables/disables Crashlytics and Performance by env flags (`--dart-define`)
- routes `FlutterError.onError` into Crashlytics
- captures `PlatformDispatcher` uncaught errors
- wraps app startup in `runZonedGuarded`

This ensures release crashes are captured with minimal code changes.

# 7. Release Automation

Release steps:

1. Merge into `staging` -> full CI + staging functions deploy.
2. Validate staging metrics/crash baseline.
3. Merge to `main` -> production deploy + production AAB build.
4. Tag `vX.Y.Z` -> Play internal track upload.
5. Promote from internal -> closed/open/production after QA signoff.

Rollback:

- redeploy previous function revision
- promote previous Play build version code

# 8. Firebase Deployment Pipeline

Deployer script (`scripts/deploy/deploy_functions.sh`):

- validates environment argument
- loads project id from environment file
- deploys with `firebase deploy --only functions`

Why this is safe:

- scoped deploy avoids accidental rules/hosting changes
- environment-specific project ids reduce cross-environment blast radius

# 9. Example CI Configuration

Provided file:

- `.github/workflows/mobile-ci-cd.yml`

Key reliability controls:

- workflow `concurrency` to cancel outdated pipelines
- environment-specific deploy gates
- artifact persistence for release handoff

# 10. Example Deployment Scripts

Included scripts:

- `scripts/deploy/deploy_functions.sh` (functions-only environment deploy)
- `scripts/deploy/release_android.sh` (local/CI release helper)

Both validate environment and fail fast on missing prerequisites.

# 11. Operational Best Practices

- enforce branch protection on `main` and `staging`
- require CI green + review before merge
- monitor crash-free users and startup latency per release
- add anomaly checker function for DAU/crash spikes against 7-day baseline
- document runbooks for: build failure, partial deploy, secret rotation, incident rollback

## Edge Cases and Controls

- **failed builds**: CI blocks deploy and release jobs by dependency chain.
- **partial deploys**: functions-only deploy + explicit environment id prevents cross-scope drift.
- **secrets exposure**: all credentials sourced from Actions secrets only.
- **crash spike detection**: monitored via Crashlytics + analytics trend docs for alert rules.

## Alternative Solutions

- multi-platform: add iOS Fastlane lanes + TestFlight upload in same pipeline.
- future web release: add Firebase Hosting preview channels + Lighthouse checks.
- Kubernetes migration: move heavy pipelines to Cloud Run/GKE while keeping Firebase Auth/FCM.
