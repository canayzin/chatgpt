# 1. Viral Growth System Architecture

The viral engine extends existing analytics/recommendation infrastructure without replacing app architecture:

- `referral_service` (Flutter + callable): referral profile, invite counts, install claims.
- `invite_link_generator` (Flutter): short dynamic links with `referralId` + optional `contentId`.
- `share_attribution_tracker` (Flutter): consumes initial/foreground deep links and applies attribution.
- `growth_metrics_service` (Flutter): reads growth KPI snapshots and top viral content.
- Cloud Functions pipeline (`viral_growth_pipeline.ts`): secure claim processing, reward grants, growth KPI recompute, notification-window optimization.

# 2. Referral Data Model

Collections:

- `referral_profiles/{uid}`
  - `referralCode`, `totalInvites`, `successfulInstalls`, `rewards`, `updatedAt`
- `referral_installs/{newUserId}`
  - `userId`, `referrerId`, `referralCode`, `contentId`, `ipHash`, `claimedAt`, `status`
- `notification_optimization/{uid}`
  - `bestHourUtc`, `preferredCategory`
- `growth_metrics/{date}`
  - `viralCoefficient`, `shareToInstallRate`, `referralConversionRate`, `topViralContent`

# 3. Dynamic Link System

Dynamic links generated with `FirebaseDynamicLinks` include:

- `referralId=<code>`
- `contentId=<knowledgeId>` (optional)

Deep links resolve into app and are handled by attribution tracker on:

- cold start (`getInitialLink`)
- foreground open (`onLink` stream)

# 4. Invite UX Design

Added `InviteFriendsScreen` with:

- referral code display + quick share/copy
- invite progress (invites sent vs successful installs)
- reward milestone visibility
- CTA to generate/share short invite links

Access path: Profile -> “Invite friends”.

# 5. Share Attribution Tracking

When deep links are opened:

1. Tracker reads `referralId` and `contentId`.
2. Logs analytics attribution event.
3. Calls secure backend `processReferralInstall` for claim.

This ties social share -> open -> install claim chain.

# 6. Growth Metrics Pipeline

Scheduled function `recomputeGrowthMetrics` computes:

- `viralCoefficient = installs / uniqueReferrers`
- `shareToInstallRate = installs / shares`
- `referralConversionRate = installs / referral_claims`
- `topViralContent` from highest share-rate content metrics

Stored daily in `growth_metrics/{date}` for dashboards.

# 7. Notification Optimization Logic

Scheduled function `suggestNotificationWindows` analyzes recent events by user and updates:

- best engagement hour (UTC)
- preferred content category

Output lands in `notification_optimization/{uid}` for targeting send-time and category choice.

# 8. Example Cloud Functions

Implemented in `functions/src/viral_growth_pipeline.ts`:

- `processReferralInstall`
- `recomputeGrowthMetrics`
- `suggestNotificationWindows`

Also exported through `functions/src/index.ts`.

# 9. Example Flutter Code

Implemented modules:

- `lib/features/growth/viral/services/referral_service.dart`
- `lib/features/growth/viral/services/invite_link_generator.dart`
- `lib/features/growth/viral/services/share_attribution_tracker.dart`
- `lib/features/growth/viral/services/growth_metrics_service.dart`
- `lib/features/growth/viral/presentation/invite_friends_screen.dart`

Integrations:

- route `/invite`
- profile CTA button
- app bootstrap attribution initialization

# 10. Growth Dashboard Preparation

Dashboard-ready sources:

- `growth_metrics` for KPI trends
- `referral_profiles` for inviter leaderboard
- `referral_installs` for conversion funnel
- `content_metrics` + `topViralContent` for viral content discovery

# 11. Future Growth Experimentation

- add signed referral tokens to prevent tampering and replay
- add anti-abuse velocity checks by IP/device clusters
- integrate paid campaigns with UTM + MMP fields in deep links
- auto-generate social snippets per content category
- run A/B tests on reward milestones and invite copy

## Edge Cases Addressed

- duplicate referrals: one `referral_installs/{uid}` claim per installer
- fake installs/self-referral: auth required + self-referral blocked + ip hash storage
- referral abuse: deterministic claim checks + reward thresholds
- link tampering: backend validates referral code existence and ownership
