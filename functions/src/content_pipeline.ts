import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

if (!admin.apps.length) {
  admin.initializeApp();
}

const firestore = admin.firestore();
const storage = admin.storage().bucket();

const DEFAULT_CATEGORIES = [
  'psychology',
  'finance',
  'manipulation techniques',
  'entrepreneurship',
  'cognitive biases',
  'interesting facts',
];

type DraftPayload = {
  category: string;
  question: string;
  shortAnswer: string;
  detailExplanation: string;
  quizQuestion: string;
  quizOptions: string[];
  quizCorrectAnswer: number;
  tags: string[];
  estimatedReadingTime: number;
  qualityScore: number;
  viralityScore: number;
  engagementScore: number;
  dedupeHash: string;
};

export const generateKnowledgeBatch = functions.https.onCall(async (data) => {
  const totalItems = Math.max(50, Math.min(200, Number(data.totalItems) || 50));
  const categories = (Array.isArray(data.categories) && data.categories.length > 0
    ? data.categories
    : DEFAULT_CATEGORIES) as string[];

  const batchId = `batch_${Date.now()}`;
  const perCategory = Math.floor(totalItems / categories.length);
  const remainder = totalItems % categories.length;

  const drafts: DraftPayload[] = [];
  for (let i = 0; i < categories.length; i += 1) {
    const count = perCategory + (i < remainder ? 1 : 0);
    const aiDrafts = await generateCategoryDrafts(categories[i], count);
    drafts.push(...aiDrafts);
  }

  const uniqueDrafts = await deduplicateDrafts(drafts);
  const writeBatch = firestore.batch();

  uniqueDrafts.forEach((draft) => {
    const ref = firestore.collection('moderation_queue').doc();
    writeBatch.set(ref, {
      ...draft,
      batchId,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await writeBatch.commit();
  await firestore.collection('content_batches').doc(batchId).set({
    requestedCount: totalItems,
    insertedCount: uniqueDrafts.length,
    categories,
    status: 'completed',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { batchId, insertedCount: uniqueDrafts.length };
});

export const generateKnowledgeAudio = functions.https.onCall(async (data) => {
  const draftId = String(data.draftId || '');
  if (!draftId) {
    throw new functions.https.HttpsError('invalid-argument', 'draftId is required');
  }

  const draftRef = firestore.collection('moderation_queue').doc(draftId);
  const draftSnap = await draftRef.get();
  if (!draftSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Draft not found');
  }

  const draft = draftSnap.data() as Record<string, any>;
  const narrationText = `${draft.question}\n${draft.shortAnswer}\n${draft.detailExplanation ?? ''}`;

  try {
    const audioBuffer = await synthesizeAudio(narrationText);
    const filePath = `knowledge-audio/${draftId}.mp3`;
    const file = storage.file(filePath);
    await file.save(audioBuffer, { contentType: 'audio/mpeg' });
    await file.makePublic();

    const audioUrl = `https://storage.googleapis.com/${storage.name}/${filePath}`;
    await draftRef.set(
      {
        audioUrl,
        audioGenerationStatus: 'completed',
        audioGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { audioUrl };
  } catch (error) {
    await draftRef.set(
      {
        audioGenerationStatus: 'failed',
        audioGenerationError: String(error),
      },
      { merge: true },
    );
    throw new functions.https.HttpsError('internal', 'Audio generation failed');
  }
});

async function generateCategoryDrafts(category: string, count: number): Promise<DraftPayload[]> {
  const drafts: DraftPayload[] = [];

  // Placeholder for OpenAI/Vertex integration.
  for (let i = 0; i < count; i += 1) {
    const question = `What is a key ${category} insight #${i + 1}?`;
    const shortAnswer = `A concise ${category} principle that improves decision quality.`;
    const detailExplanation = `Detailed explanation for ${category} insight #${i + 1} with practical examples.`;

    drafts.push({
      category,
      question,
      shortAnswer,
      detailExplanation,
      quizQuestion: `Which statement best describes ${category} insight #${i + 1}?`,
      quizOptions: ['Option A', 'Option B', 'Option C', 'Option D'],
      quizCorrectAnswer: 1,
      tags: [category, 'learning', 'ai-generated'],
      estimatedReadingTime: 35,
      qualityScore: 0.72,
      viralityScore: 0.58,
      engagementScore: 0.63,
      dedupeHash: hashKey(`${category}-${question.toLowerCase()}`),
    });
  }

  return drafts;
}

async function deduplicateDrafts(drafts: DraftPayload[]): Promise<DraftPayload[]> {
  const existingHashesSnapshot = await firestore.collection('moderation_queue').select('dedupeHash').limit(1000).get();
  const existingHashes = new Set(existingHashesSnapshot.docs.map((doc) => String(doc.get('dedupeHash') || '')));

  const next = new Map<string, DraftPayload>();
  drafts.forEach((draft) => {
    if (!draft.question.trim() || !draft.shortAnswer.trim()) {
      return;
    }

    if (existingHashes.has(draft.dedupeHash)) {
      return;
    }

    if (!next.has(draft.dedupeHash)) {
      next.set(draft.dedupeHash, draft);
    }
  });

  return [...next.values()];
}

function hashKey(value: string): string {
  let hash = 0;
  for (let i = 0; i < value.length; i += 1) {
    hash = (hash << 5) - hash + value.charCodeAt(i);
    hash |= 0;
  }
  return `${hash}`;
}

async function synthesizeAudio(_text: string): Promise<Buffer> {
  // Placeholder for Google Cloud TTS call. Fallback returns silent/empty MP3 marker bytes.
  return Buffer.from('494433', 'hex');
}
