# 1. Product Overview

**AI Learn** is a high-retention, scroll-first microlearning app that combines short-form knowledge cards, optional deep dives, audio narration, and quizzes into a highly engaging habit loop.

## Product goals
- Build a TikTok-like learning experience optimized for 100K+ installs.
- Deliver value in <5 seconds after app open.
- Create compounding retention through streaks, daily goals, and series progression.
- Support multiple learning modes: read, listen, quiz, drive.
- Monetize sustainably with AdMob while preserving UX quality.

## Core user loop
1. Open app → land in personalized vertical feed.
2. Consume card quickly (question + short answer).
3. Expand details / listen to narration.
4. Save/share/quiz.
5. Return daily for streak + daily card + report.

## Primary KPIs
- D1/D7/D30 retention.
- Cards consumed per session.
- Save/share rate.
- Quiz completion rate.
- Streak continuation rate.
- Ad ARPDAU and rewarded ad completion rate.

---

# 2. System Architecture

## High-level architecture
- **Client**: Flutter (latest stable), Riverpod (recommended), go_router, freezed/json_serializable.
- **Backend**: Firebase Firestore, Firebase Auth, Firebase Cloud Messaging, Firebase Storage, Cloud Functions (for fanout tasks and analytics aggregation).
- **Monetization**: Google Mobile Ads (AdMob).

## Architecture style
Use **Clean Architecture + Feature-first modularization**:
- `presentation` (UI + state notifier/controllers)
- `application` (use-cases / orchestration)
- `domain` (entities + repository contracts)
- `data` (Firebase/local implementations)

This keeps feed, audio, quizzes, streaks, and growth systems independently scalable.

## Runtime data flow
1. UI requests feed page via `FeedController`.
2. Controller calls `GetFeedCardsUseCase`.
3. Use case merges remote Firestore + local cache + read-state metadata.
4. Controller emits immutable state.
5. UI renders with prefetch and optimistic interactions (save/read/share).

## Scalability decisions
- Denormalized card docs for read speed.
- Precomputed `trending_score` and `most_saved_score` fields.
- Time-bucketed analytics collections.
- Cursor-based pagination (`startAfterDocument`) for infinite feed.
- Batched writes for read/save events.
- Background sync for offline actions.

## Security model
- Anonymous auth on first launch; optional account upgrade.
- Firestore rules enforce user-scoped writes.
- Admin-only content writes for manual curation.
- Signed URLs or Storage rules for audio access.

---

# 3. Firebase Database Structure

```text
/users/{uid}
  profile:
    display_name, avatar_url, created_at, timezone, preferred_categories[],
    daily_goal, streak_count, best_streak, total_learned_count

/users/{uid}/progress/{cardId}
  is_read, read_count, last_read_at, completed_audio_seconds, quiz_score, saved

/users/{uid}/favorites/{cardId}
  card_ref, folder_ids[], saved_at, offline_cached

/users/{uid}/favorite_folders/{folderId}
  name, color, created_at, card_count

/users/{uid}/daily_stats/{yyyyMMdd}
  cards_read, minutes_listened, quizzes_taken, shares, goal_completed

/users/{uid}/notifications/{notificationId}
  type, scheduled_at, delivered_at, status

/cards/{cardId}
  category_id, tags[], language,
  main_question, short_answer, detailed_explanation,
  has_audio, audio_url, audio_duration_sec,
  difficulty, created_at, updated_at,
  estimated_read_sec,
  metrics: {views, saves, shares, quiz_attempts},
  scores: {trending_score, quality_score, recency_score},
  is_daily_pick, is_active

/categories/{categoryId}
  name, icon, order, active

/series/{seriesId}
  title, description, category_id, cover_image,
  card_ids[], level, estimated_total_min, active

/quizzes/{quizId}
  card_id, type, question, options[], correct_answer, explanation

/daily_content/{yyyyMMdd}
  daily_card_id, mini_podcast_audio_url, quote_card_id

/trending/{yyyyMMdd}/items/{cardId}
  rank, trending_score

/aggregates/weekly_reports/{uid_yyyyWW}
  user_id, week_key, total_cards, top_category, streak_days, share_count

/ad_config/global
  feed_ad_interval, interstitial_frequency, rewarded_reward_value,
  native_enabled, interstitial_enabled, rewarded_enabled
```

## Audio storage structure
```text
Firebase Storage
/audio/cards/{cardId}/narration_v1.mp3
/audio/daily/{yyyyMMdd}/mini_podcast.mp3
/audio/series/{seriesId}/{index}.mp3
```

## Indexing recommendations
- `cards`: composite indexes on (`is_active`, `category_id`, `created_at desc`), (`is_active`, `scores.trending_score desc`), (`is_active`, `metrics.saves desc`).
- `users/{uid}/progress`: index `last_read_at desc`.
- `daily_content`: key-based doc lookup.

---

# 4. Flutter Project Folder Structure

```text
lib/
  app/
    app.dart
    router.dart
    theme/
    di/
  core/
    constants/
    error/
    network/
    storage/
    analytics/
    utils/
    widgets/
  features/
    auth/
      data/
      domain/
      application/
      presentation/
    feed/
      data/
        datasources/feed_remote_ds.dart
        datasources/feed_local_ds.dart
        repositories/feed_repository_impl.dart
      domain/
        entities/knowledge_card.dart
        repositories/feed_repository.dart
        usecases/get_feed_cards.dart
      application/
        feed_controller.dart
        feed_state.dart
      presentation/
        pages/main_feed_page.dart
        widgets/knowledge_card_widget.dart
        widgets/feed_ad_slot.dart
    categories/
    search/
    favorites/
    audio/
    driving_mode/
    quiz/
    profile/
    series/
    trending/
    daily/
    random/
    settings/
    notifications/
    growth/
    ads/
  l10n/
  main.dart
```

## Why this structure scales
- Feature boundaries reduce merge conflicts and coupling.
- Domain interfaces allow swapping Firebase with another backend later.
- Separate `audio`, `ads`, `growth` features keep monetization and retention evolvable.

---

# 5. UI Screen Design Explanation

## Splash Screen
- Fast brand reveal + auth/bootstrap checks.
- Preload first feed batch and ad config.

## Onboarding
- Choose interests, daily goal, reminder time, audio preference.
- Ask push permission after value proposition.

## Main Feed
- Vertical full-screen cards with smooth snapping.
- Card layers: category chip, question, short answer, expand details, audio controls, save/share/quiz CTA.
- Inline native ad every 7 content cards.

## Categories
- Horizontal swipe tabs + each category has independent cursor state.
- “For You” tab includes blended ranking.

## Search
- Typeahead over question/tags/category.
- Recent searches + trending keywords.

## Favorites
- Folder-based organization.
- Offline availability badges.

## Driving Mode
- High-contrast, large typography, minimal touch targets.
- Autoplay narration + next card auto-advance.

## Quiz Screen
- Quick MCQ/true-false from consumed cards.
- Instant feedback + explanation + streak points.

## Profile Screen
- Stats dashboard: learned count, daily streak, goal progress, weekly report summary.

## Learning Series
- Structured sequence with progress bar and completion badge.

## Trending Knowledge
- Time-windowed top cards (24h / 7d).

## Daily Knowledge
- One curated must-read card + optional mini podcast.

## Random Knowledge
- Shuffle mode to break filter bubbles and increase novelty.

## Mini Audio Player
- Persistent bottom sheet with play/pause, speed, seek, next/prev.

## Settings
- Theme, night mode, autoplay, download on Wi-Fi, notification schedule, language.

---

# 6. Core Data Models

```dart
class KnowledgeCard {
  final String id;
  final String categoryId;
  final String mainQuestion;
  final String shortAnswer;
  final String? detailedExplanation;
  final AudioMeta? audio;
  final int estimatedReadSec;
  final List<String> tags;
  final bool isDailyPick;
  final double trendingScore;
  final DateTime createdAt;
  final Metrics metrics;
}

class AudioMeta {
  final String url;
  final int durationSec;
  final List<double>? waveform;
}

class UserProgress {
  final String cardId;
  final bool isRead;
  final bool isSaved;
  final int readCount;
  final int completedAudioSeconds;
  final double? quizScore;
  final DateTime? lastReadAt;
}

class DailyStats {
  final DateTime date;
  final int cardsRead;
  final int minutesListened;
  final int quizzesTaken;
  final int shares;
  final bool goalCompleted;
}
```

Modeling guidance:
- Keep card payload read-optimized and mostly immutable.
- Store user interactions in user subcollections.
- Prefer optional fields over multiple card types to simplify feed rendering.

---

# 7. Feed Algorithm

## Candidate generation
- Fetch by selected category (or mixed categories for For You).
- Include daily pick and trending injectors.
- Exclude blocked/inactive and already overexposed cards.

## Ranking formula (initial)
`final_score = 0.35 * trending_score + 0.25 * quality_score + 0.20 * recency_score + 0.10 * personal_category_affinity + 0.10 * novelty_score`

## Diversity constraints
- No more than 2 consecutive cards from same category.
- Inject 1 random card every N cards for exploration.

## Pagination
- Page size: 10–15 cards.
- Use Firestore cursor (`startAfterDocument`).
- Prefetch next page when user reaches 70% of current page.

## Read indicators
- Track locally immediately; sync async.
- Badge state: unread / in-progress / learned.

---

# 8. Growth Features Implementation

## Streak engine
- Day considered complete when daily goal reached.
- Grace window by timezone (e.g., +4h after midnight).
- Cloud Function validates streak transitions.

## Share loops
- Generate image cards (question + answer + branding + QR/deep link).
- Share results: quiz score, streak milestone, weekly summary.
- Use dynamic links to open specific content in app.

## Weekly learning summary
- Every week, aggregate stats and push digest notification.
- In-app report card with category breakdown + achievements.

## Mini podcast
- Daily 1–3 minute audio compilation from top cards.
- Triggered in Daily screen and notification.

## Random knowledge widget
- Home screen widget showing rotating fact.
- Deep-link to corresponding card.

## Viral mechanics
- “Challenge a friend” quiz share.
- Streak freeze reward via rewarded ad or achievement.
- New-user onboarding referral badge.

---

# 9. AdMob Integration Strategy

## Placements
- **Native ads in feed**: every 7 cards (`7 content -> 1 ad`).
- **Interstitial**: natural breaks (e.g., after quiz completion every X sessions).
- **Rewarded**: optional value exchange (streak freeze, extra quiz hints, ad-free 30 min).

## UX safety rules
- No interstitial on first session first 5 minutes.
- Cap interstitial frequency per user/day.
- Never interrupt audio in driving mode with interstitial.
- Distinguish ads visually but keep style cohesive.

## Technical implementation
- Remote-configurable ad frequency from `/ad_config/global`.
- Preload ads in background.
- Fallback when ad load fails (content continues).

## Revenue optimization
- A/B test ad interval: 6/7/8 cards.
- Segment by country and retention cohort.
- Track eCPM, fill rate, and churn impact.

---

# 10. Performance Optimization

## UI/rendering
- Use `PageView.builder` or `ScrollablePositionedList` with item extent hints.
- Avoid heavy rebuilds via Riverpod selective listeners.
- Use cached network images and skeleton loaders.

## Data/caching
- Firestore offline persistence ON.
- Local cache (Hive/Isar) for favorites + recent feed + audio metadata.
- Background download for favorited audio on Wi-Fi.

## Audio resilience
- Pre-buffer next card audio.
- Timeout and retry with exponential backoff.
- Graceful fallback to text when audio unavailable.

## Slow internet/offline handling
- Stale-while-revalidate feed: show cached cards instantly, refresh silently.
- Queue offline actions (save/read/share intent) and sync when online.
- Notification fallback: local scheduled reminders when FCM missed.

## Monitoring
- Firebase Crashlytics + Performance Monitoring.
- Custom traces: feed load latency, first interaction time, audio start delay.

## Alternative recommendations
- **State management**: Riverpod preferred over Provider for testability and granular rebuild control.
- **Caching**: Isar for complex local queries; Hive for simplicity.
- **Scaling content**: BigQuery export + Cloud Functions to compute trending and personalization features.

---

# 11. Example Flutter Code Snippets

## 11.1 Knowledge card model (Freezed style)
```dart
@freezed
class KnowledgeCard with _$KnowledgeCard {
  const factory KnowledgeCard({
    required String id,
    required String categoryId,
    required String mainQuestion,
    required String shortAnswer,
    String? detailedExplanation,
    AudioMeta? audio,
    @Default(20) int estimatedReadSec,
    @Default([]) List<String> tags,
    @Default(false) bool isDailyPick,
    @Default(0) double trendingScore,
    required DateTime createdAt,
    required Metrics metrics,
  }) = _KnowledgeCard;

  factory KnowledgeCard.fromJson(Map<String, dynamic> json) =>
      _$KnowledgeCardFromJson(json);
}
```

## 11.2 Feed repository pagination
```dart
class FeedRepositoryImpl implements FeedRepository {
  final FirebaseFirestore _firestore;

  FeedRepositoryImpl(this._firestore);

  @override
  Future<FeedPage> getFeedPage({
    required String categoryId,
    DocumentSnapshot? cursor,
    int limit = 12,
  }) async {
    Query q = _firestore
        .collection('cards')
        .where('is_active', isEqualTo: true)
        .orderBy('scores.trending_score', descending: true)
        .limit(limit);

    if (categoryId != 'for_you') {
      q = q.where('category_id', isEqualTo: categoryId);
    }

    if (cursor != null) {
      q = q.startAfterDocument(cursor);
    }

    final snap = await q.get();
    final cards = snap.docs
        .map((d) => KnowledgeCard.fromJson({...d.data() as Map<String, dynamic>, 'id': d.id}))
        .toList();

    return FeedPage(
      items: cards,
      nextCursor: snap.docs.isEmpty ? null : snap.docs.last,
    );
  }
}
```

## 11.3 Feed controller with ad slot injection
```dart
final feedControllerProvider =
    StateNotifierProvider<FeedController, FeedState>((ref) {
  return FeedController(ref.read);
});

class FeedController extends StateNotifier<FeedState> {
  FeedController(this._read) : super(const FeedState.initial());

  final Reader _read;
  static const int adInterval = 7;

  Future<void> loadNext() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

    final page = await _read(feedRepoProvider).getFeedPage(
      categoryId: state.categoryId,
      cursor: state.cursor,
    );

    final merged = [...state.items, ...page.items];
    final withAds = _injectAdSlots(merged, adInterval);

    state = state.copyWith(
      isLoading: false,
      items: withAds,
      cursor: page.nextCursor,
      hasMore: page.nextCursor != null,
    );
  }
}
```

## 11.4 Audio player service (background capable)
```dart
class AppAudioService {
  final AudioPlayer _player;

  AppAudioService(this._player);

  Future<void> playCard(KnowledgeCard card, {double speed = 1.0}) async {
    final url = card.audio?.url;
    if (url == null) return;

    await _player.setUrl(url);
    await _player.setSpeed(speed);
    await _player.play();
  }

  Future<void> setSpeed(double value) => _player.setSpeed(value);
  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
}
```

## 11.5 Offline favorites sync
```dart
Future<void> syncPendingFavoriteOps() async {
  final pending = await localStore.getPendingFavoriteOps();
  for (final op in pending) {
    try {
      final ref = firestore
          .collection('users')
          .doc(op.uid)
          .collection('favorites')
          .doc(op.cardId);

      if (op.type == FavoriteOpType.add) {
        await ref.set({
          'card_ref': firestore.doc('cards/${op.cardId}'),
          'saved_at': FieldValue.serverTimestamp(),
          'offline_cached': true,
        }, SetOptions(merge: true));
      } else {
        await ref.delete();
      }

      await localStore.markSynced(op.id);
    } catch (_) {
      // keep op for retry with backoff
    }
  }
}
```

## Production readiness checklist
- Enforce typed models + linting + CI.
- Add golden tests for core card UI states.
- Add integration tests for feed pagination and offline sync.
- Add feature flags for risky growth experiments.
