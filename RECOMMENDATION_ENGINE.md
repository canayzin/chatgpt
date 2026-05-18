# 1. Recommendation System Architecture

The personalization stack extends existing AI Learn services without replacing the feed foundation:

- `interaction_tracking_service` (Flutter): writes immutable interaction events and performs low-latency preference updates.
- `user_profile_service` (Flutter): maintains incremental `user_profiles` signals (`categoryAffinity`, `quizStrength`, `learningFrequency`, `recentInteractions`, `favoriteTopics`).
- `feed_ranking_engine` (repo-level scoring): computes per-card feed score from engagement, preference, quality, virality, and recency.
- `recommendation_service` (Flutter + callable): optional server-side score refresh trigger.
- Cloud Functions (`recommendation_pipeline.ts`): event-driven profile reinforcement + feed score materialization (`feed_scores`).

# 2. Firestore Data Model

## `user_profiles/{uid}`
- `categoryAffinity: map<string,double>`
- `quizStrength: map<string,double>`
- `learningFrequency: map<yyyy-mm-dd,int>`
- `recentInteractions: string[]`
- `favoriteTopics: string[]`
- `updatedAt, lastInteractionAt`

## `interaction_events/{eventId}`
- `uid`
- `knowledgeId` (optional for quiz events)
- `category`
- `eventType` (`read|dwell|favorite|share|audio_play|quiz_complete`)
- `dwellMs`
- `isFavorite`
- `topic/correct/total` (quiz)
- `createdAt`

## `feed_scores/{uid}_{knowledgeId}`
- `uid`
- `knowledgeId`
- `rank`
- `score`
- `components`
- `updatedAt`

# 3. User Preference Tracking

User preferences are updated incrementally after each event:

- favorites/shares/audio events receive higher category-affinity weights,
- reads and meaningful dwell events strengthen weaker weights,
- favorite categories populate `favoriteTopics`,
- recent interactions are deduped and capped for repeat-content suppression,
- quiz completion updates `quizStrength[topic] = accuracy`.

# 4. Interaction Event Pipeline

1. Flutter action creates an immutable `interaction_events` write.
2. `InteractionTrackingService` immediately updates `user_profiles` (low latency).
3. Firestore trigger (`onInteractionEventCreated`) reinforces category affinity server-side.
4. Optional callable (`recomputeUserFeedScores`) materializes ranked candidate list into `feed_scores`.

This dual-write model handles missing events and preserves resilience for transient client failures.

# 5. Feed Ranking Algorithm

Per-card score components:

- `engagementScore`: favorites/read counters + stored engagement prior.
- `categoryPreferenceScore`: user profile affinity for card category.
- `recencyBoost`: strong boost for <24h, medium for <72h, light for <7 days.
- `qualityScore`: AI/content quality prior.
- `viralityScore`: sharing propensity prior.

Formula (current implementation):

`score = favorites*1.8 + reads*0.35 + engagementScore*10 + categoryPreference*0.7 + qualityScore*12 + viralityScore*10 + recencyBoost`

# 6. Personalization Logic

Feed prioritization order now favors:

1. preferred categories (`user_profiles.categoryAffinity`),
2. high quality / high virality cards,
3. high engagement cards,
4. recent cards,
5. unseen cards (via `recentInteractions` filtering).

Cold-start fallback:
- if no profile exists, feed defaults to recency + global engagement signals.

# 7. Flutter Feed Integration

- `FeedQuery` now includes `personalized` flag (default true).
- `FeedController` routes uncategorized feeds through `getPersonalizedKnowledgePage`.
- `FeedScreen` emits events for favorite/share/audio/read/dwell.
- Quiz completion emits `quiz_complete` signal.
- Category feeds preserve deterministic category query behavior.

# 8. Example Cloud Functions

Added:

- `onInteractionEventCreated` Firestore trigger to reinforce profile affinity in real time.
- `recomputeUserFeedScores` callable to compute top ranked candidates and write `feed_scores`.

# 9. Example Flutter Code

Added modules:

- `lib/features/recommendation/services/interaction_tracking_service.dart`
- `lib/features/recommendation/services/user_profile_service.dart`
- `lib/features/recommendation/services/recommendation_service.dart`
- `lib/features/recommendation/domain/user_profile_model.dart`

Modified:

- feed repository/controller/screen for ranked retrieval and event signals.
- quiz screen for completion signal.

# 10. Performance Optimization

- Incremental profile updates avoid expensive full-history scans.
- Candidate fetch uses bounded query window (`limit * 4`) and local score sort.
- Recent-interaction filtering reduces duplicate card resurfacing.
- Feed remains paginated and ad-injected after ranking.
- Cloud function recompute is callable/on-demand to control cost.

# 11. Future ML Upgrade Path

- Move from heuristic scoring to learned ranker (GBDT/DLRM) using logged interactions.
- Add vector embeddings for semantic matching across `question/details/tags`.
- Introduce two-stage retrieval (candidate generation + ranking).
- Add exploration/exploitation (bandit) for cold start and novelty.
- Expand profile signals with completion rate, session time, and temporal intent.
