import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

if (!admin.apps.length) {
  admin.initializeApp();
}

const firestore = admin.firestore();

type FeedScore = {
  knowledgeId: string;
  score: number;
  components: {
    engagementScore: number;
    categoryPreferenceScore: number;
    recencyBoost: number;
    qualityScore: number;
    viralityScore: number;
  };
};

export const onInteractionEventCreated = functions.firestore
  .document('interaction_events/{eventId}')
  .onCreate(async (snap) => {
    const event = snap.data() as Record<string, any>;
    const uid = String(event.uid || '');
    if (!uid) return;

    const profileRef = firestore.collection('user_profiles').doc(uid);
    const increment = computeEventWeight(String(event.eventType || ''));
    const category = String(event.category || 'general').toLowerCase();

    await profileRef.set(
      {
        categoryAffinity: {
          [category]: admin.firestore.FieldValue.increment(increment),
        },
        lastInteractionAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

export const recomputeUserFeedScores = functions.https.onCall(async (data) => {
  const uid = String(data.uid || '');
  if (!uid) {
    throw new functions.https.HttpsError('invalid-argument', 'uid is required');
  }

  const [profileSnap, knowledgeSnap] = await Promise.all([
    firestore.collection('user_profiles').doc(uid).get(),
    firestore.collection('knowledge_cards').orderBy('createdAt', 'desc').limit(250).get(),
  ]);

  const profile = profileSnap.data() ?? {};
  const categoryAffinity = (profile.categoryAffinity ?? {}) as Record<string, number>;

  const scored: FeedScore[] = knowledgeSnap.docs
    .map((doc) => {
      const card = doc.data() as Record<string, any>;
      const category = String(card.kategori || card.category || 'general').toLowerCase();
      if (!isPrimaryRecommendationCandidate(doc.id, category)) {
        return null;
      }

      const favorites = Number(card.favoriteCount || 0);
      const reads = Number(card.readCount || 0);
      const qualityScore = Number(card.qualityScore || 0);
      const viralityScore = Number(card.viralityScore || 0);
      const engagementScore = Number(card.engagementScore || 0);
      const createdAt = card.createdAt?.toDate?.() as Date | undefined;

      const categoryPreferenceScore = Number(categoryAffinity[category] || 0) * 0.7;
      const recencyBoost = computeRecencyBoost(createdAt ?? new Date(0));

      const score =
        engagementScore * 10 +
        favorites * 1.8 +
        reads * 0.35 +
        categoryPreferenceScore +
        qualityScore * 12 +
        viralityScore * 10 +
        recencyBoost;

      return {
        knowledgeId: doc.id,
        score,
        components: {
          engagementScore,
          categoryPreferenceScore,
          recencyBoost,
          qualityScore,
          viralityScore,
        },
      };
    })
    .filter((item): item is FeedScore => item !== null);

  scored.sort((a, b) => b.score - a.score);

  const writeBatch = firestore.batch();
  scored.slice(0, 150).forEach((item, index) => {
    const ref = firestore.collection('feed_scores').doc(`${uid}_${item.knowledgeId}`);
    writeBatch.set(ref, {
      uid,
      knowledgeId: item.knowledgeId,
      rank: index + 1,
      score: item.score,
      components: item.components,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await writeBatch.commit();
  return { uid, computed: Math.min(scored.length, 150) };
});

function computeEventWeight(eventType: string): number {
  switch (eventType) {
    case 'favorite':
    case 'favorite_add':
      return 2.5;
    case 'favorite_remove':
      return -1.0;
    case 'share':
      return 2.0;
    case 'audio_play':
      return 1.7;
    case 'read':
      return 1.2;
    case 'quiz_complete':
      return 1.3;
    default:
      return 0.6;
  }
}

function computeRecencyBoost(createdAt: Date): number {
  const ageHours = (Date.now() - createdAt.getTime()) / 36e5;
  if (ageHours <= 24) return 16;
  if (ageHours <= 72) return 10;
  if (ageHours <= 168) return 5;
  return 1;
}

function isPrimaryRecommendationCandidate(knowledgeId: string, category: string): boolean {
  if (knowledgeId.startsWith('psy_')) return true;
  return category === 'psikoloji';
}
