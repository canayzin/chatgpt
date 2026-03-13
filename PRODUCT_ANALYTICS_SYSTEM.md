# 1. Analytics System Architecture

The analytics stack is implemented as four composable modules:

- `analytics_event_service` (Flutter): logs normalized product events and handles offline buffering.
- `session_tracking_service` (Flutter): issues and updates session records in `user_sessions`.
- `content_metrics_aggregator` (Cloud Functions): converts raw events into content and daily rollups.
- `growth_insight_engine` (Flutter read service): fetches dashboard-ready snapshots.

Data flow:
App interaction -> `analytics_events` write -> `onAnalyticsEventCreated` trigger -> rollup collections -> dashboards.

# 2. Event Data Model

Each event writes:

- `userId`
- `eventType`
- `contentId` (optional)
- `category` (optional)
- `timestamp`
- `sessionId`
- `deviceInfo`
- `properties` (extensible payload)
- `eventId` (optional deterministic key for dedupe)

Supported event types implemented in hooks:

- `feed_scroll`
- `knowledge_view`
- `knowledge_complete`
- `favorite_add`
- `favorite_remove`
- `quiz_start`
- `quiz_complete`
- `audio_play`
- `share_action`
- `streak_update`

Pipeline supports `audio_complete` if emitted later.

# 3. Firestore / BigQuery Storage Design

Primary collections:

- `analytics_events` (raw immutable event log)
- `user_sessions` (session boundaries + event volume)
- `content_metrics` (per-card aggregates)
- `analytics_daily` (daily event + active-user counters)
- `retention_metrics` (DAU/WAU rollups)
- `user_analytics` (per-user category/event activity summary)

BigQuery path (future): stream `analytics_events` to BigQuery for heavy cohort analysis.

# 4. Event Tracking Integration

Flutter integration points:

- feed page changes emit `feed_scroll`
- card entry emits `knowledge_view`
- meaningful read/dwell emits `knowledge_complete`
- favorite toggle emits `favorite_add` / `favorite_remove`
- share actions emit `share_action`
- audio playback emits `audio_play`
- quiz launch emits `quiz_start`
- quiz result emits `quiz_complete`
- streak progression emits `streak_update`

# 5. Metrics Aggregation Pipeline

Cloud Functions:

- `onAnalyticsEventCreated`: real-time fan-out to daily/session/content/user aggregates.
- `recomputeAnalyticsRollups` (daily schedule): computes derived rates and retention rollups.

This avoids expensive client-side querying and keeps writes append-only at the edge.

# 6. Content Performance Metrics

Stored in `content_metrics/{contentId}`:

- `viewCount`
- `completionCount`
- `favoriteCount`
- `shareCount`
- `audioPlayCount`
- `audioCompleteCount`
- `quizAttempts`
- `quizCorrectTotal`
- `quizQuestionTotal`
- derived: `completionRate`, `favoriteRate`, `shareRate`, `quizSuccessRate`

# 7. Retention Metrics

Derived in `retention_metrics`:

- per-day `dau`
- weekly document with `wau`

Also available from `analytics_daily.activeUsers` for returning-user calculations.

# 8. Dashboard Data Model

Ready-to-query dashboard sources:

- Content Performance Dashboard -> `content_metrics`
- User Engagement Dashboard -> `analytics_daily`, `user_analytics`, `user_sessions`
- Category Popularity Dashboard -> `user_analytics.categories`, `content_metrics.category`

# 9. Example Cloud Functions

Implemented in `functions/src/analytics_pipeline.ts`:

- `onAnalyticsEventCreated`
- `recomputeAnalyticsRollups`

and exported from `functions/src/index.ts`.

# 10. Example Flutter Analytics Hooks

Implemented across:

- `FeedScreen` (scroll/view/complete/favorite/share/audio events)
- `QuizScreen` (start/complete/share events)
- `UserStatsService` (streak update events)

plus reusable services:

- `analytics_event_service.dart`
- `session_tracking_service.dart`
- `growth_insight_engine.dart`

# 11. Future Data Science Upgrade Path

- Stream to BigQuery + dbt for cohort tables and LTV forecasts.
- Add A/B experiment assignment and variant exposure events.
- Add event-level attribution fields (`campaign`, `source`, `creative`).
- Add anomaly alerts for engagement drops via scheduled checks.
- Upgrade retention to n-day cohorts and rolling survivorship curves.

## Edge Cases Handling

- duplicate events: deterministic `eventId` for key actions and idempotent set writes.
- offline logging: shared-preferences queue with background flush.
- missing session data: service auto-creates session on first event.
- rapid scroll spam: dedupe key on scroll index and bounded event payload.
