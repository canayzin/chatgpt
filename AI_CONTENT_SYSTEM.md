# 1. Content System Architecture

AI Learn content operations are split into five services that map directly to the requested components and keep compatibility with the existing feed schema:

- **content_generator_service** (Flutter admin + callable Cloud Function): starts category-balanced generation batches (50–200 items).
- **moderation_queue** (`moderation_queue` Firestore collection): stores AI drafts, scores, dedupe hash, and moderation state transitions.
- **admin_content_dashboard** (Flutter screen + controller): review/edit/approve/reject/publish flow.
- **audio_generation_pipeline** (callable Cloud Function + Firebase Storage): TTS audio generation for approved drafts.
- **content_publisher** (Flutter service): writes approved draft into `knowledge_cards` with app-compatible fields and search tokens.

Flow:
AI generation -> moderation queue -> admin review/edit -> publish to `knowledge_cards`.

# 2. Firestore Content Schema

## moderation_queue/{draftId}
- `batchId: string`
- `status: pending|approved|rejected|published`
- `category: string`
- `question: string`
- `shortAnswer: string`
- `detailExplanation: string`
- `quizQuestion: string`
- `quizOptions: string[]`
- `quizCorrectAnswer: number`
- `tags: string[]`
- `estimatedReadingTime: number`
- `qualityScore: number`
- `viralityScore: number`
- `engagementScore: number`
- `dedupeHash: string`
- `reviewNotes?: string`
- `audioUrl?: string`
- `publishedKnowledgeId?: string`
- `createdAt/reviewedAt/publishedAt: timestamp`

## content_batches/{batchId}
- `requestedCount, insertedCount`
- `categories: string[]`
- `status: completed|failed`
- `createdAt`

## knowledge_cards/{knowledgeId} (published)
- existing fields kept: `category`, `question`, `shortAnswer`, `details`, `audioUrl`, `favoriteCount`, `readCount`, `createdAt`
- new content fields: `quizQuestion`, `quizOptions`, `quizCorrectAnswer`, `tags`, `estimatedReadingTime`, `searchTokens`
- ranking metadata: `qualityScore`, `viralityScore`, `engagementScore`
- provenance: `publishedFromBatchId`

# 3. AI Generation Pipeline

1. Admin chooses categories + count in Content Studio.
2. `generateKnowledgeBatch` callable receives config.
3. Function splits count evenly across categories.
4. AI generation step returns normalized drafts.
5. Dedupe step removes duplicates by `dedupeHash` and invalid content.
6. All accepted drafts are inserted into `moderation_queue` as `pending`.
7. Batch metrics stored in `content_batches`.

# 4. Moderation Workflow

Moderation statuses:
- `pending` (auto-generated, awaiting review)
- `approved` (editor approved)
- `rejected` (editor rejected, notes saved)
- `published` (pushed to app collection)

Conflict handling:
- status transitions are explicit writes with timestamps,
- rejected drafts remain queryable for audit,
- published record stores `publishedKnowledgeId` for traceability.

# 5. Admin Content Studio Design

The admin Flutter screen provides:
- segmented moderation queue filters by status,
- draft listing with category/tags,
- actions: Preview/Edit, Approve, Reject, Generate audio, Publish,
- generation dialog for batch size + category mix,
- edit sheet to fix low-quality AI output before approval,
- preview card to verify mobile layout quality.

# 6. Audio Generation Pipeline

1. Editor clicks Generate audio.
2. `generateKnowledgeAudio` callable loads draft text.
3. TTS provider (currently placeholder wrapper) generates MP3 bytes.
4. File uploaded to Firebase Storage path `knowledge-audio/{draftId}.mp3`.
5. Public URL saved to draft as `audioUrl`.
6. Failure writes `audioGenerationStatus: failed` and error field, so review can continue without audio.

# 7. Ranking Metadata Strategy

Prepared at draft and publish time:
- `qualityScore`: content clarity + factual confidence + structure quality.
- `viralityScore`: expected shareability/emotional novelty.
- `engagementScore`: expected read completion and saves.

Near-term use:
- combine with existing `favoriteCount` and `readCount` for trending candidates.

# 8. Batch Content Generation Logic

Generation requirements implemented:
- batch range clamped to 50–200,
- category-balanced distribution (base + remainder split),
- automatic quiz generation fields,
- automatic tags and reading-time field,
- deduplication using stable hash + existing queue lookup,
- invalid/empty core fields filtered out before insert.

# 9. Example Cloud Functions

Implemented callables:
- `generateKnowledgeBatch` for queue generation,
- `generateKnowledgeAudio` for TTS upload pipeline.

Both functions are designed so OpenAI / Vertex / Gemini and Google Cloud TTS can be swapped in without changing Flutter contracts.

# 10. Admin Panel Flutter Structure

Added module:
- `lib/features/content_studio/domain/content_draft_model.dart`
- `lib/features/content_studio/data/admin_content_repository.dart`
- `lib/features/content_studio/services/content_generator_service.dart`
- `lib/features/content_studio/services/audio_generation_service.dart`
- `lib/features/content_studio/services/content_publisher_service.dart`
- `lib/features/content_studio/presentation/admin_content_controller.dart`
- `lib/features/content_studio/presentation/admin_content_dashboard_screen.dart`

Also added route:
- `/admin/content-studio`

# 11. Example Code Snippets

See:
- callable batch generation and dedupe logic in `functions/src/content_pipeline.ts`.
- moderation streams + status updates in `admin_content_repository.dart`.
- publishing approved drafts into mobile `knowledge_cards` schema in `content_publisher_service.dart`.
- admin workflow wiring in `admin_content_controller.dart` and `admin_content_dashboard_screen.dart`.

## Alternative Solutions / Upgrades

- **Quality scoring**: replace static score placeholders with model-graded rubric + human feedback loop.
- **Viral ranking**: blend score priors with real-time behavior (`CTR`, shares, completion, saves).
- **Recommendations**: migrate from category feed to hybrid candidate retrieval + lightweight ranking model.
