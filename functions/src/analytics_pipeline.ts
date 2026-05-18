import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

if (!admin.apps.length) {
  admin.initializeApp();
}

const firestore = admin.firestore();

export const onAnalyticsEventCreated = functions.firestore
  .document('analytics_events/{eventId}')
  .onCreate(async (snap) => {
    const event = snap.data() as Record<string, any>;
    const eventType = String(event.eventType || 'unknown');
    const userId = String(event.userId || 'anonymous');
    const contentId = (event.contentId as string | undefined) ?? null;
    const category = String(event.category || 'unknown');

    const writeBatch = firestore.batch();

    const date = normalizeDate(event.timestamp);
    const dailyRef = firestore.collection('analytics_daily').doc(date);
    writeBatch.set(
      dailyRef,
      {
        date,
        totalEvents: admin.firestore.FieldValue.increment(1),
        [`events.${eventType}`]: admin.firestore.FieldValue.increment(1),
        activeUsers: admin.firestore.FieldValue.arrayUnion(userId),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const sessionId = String(event.sessionId || 'unknown');
    const sessionRef = firestore.collection('user_sessions').doc(sessionId);
    writeBatch.set(
      sessionRef,
      {
        userId,
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
        eventCount: admin.firestore.FieldValue.increment(1),
      },
      { merge: true },
    );

    if (contentId) {
      const metricRef = firestore.collection('content_metrics').doc(contentId);
      const inc = admin.firestore.FieldValue.increment(1);
      writeBatch.set(
        metricRef,
        {
          contentId,
          category,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          ...(eventType == 'knowledge_view' ? { viewCount: inc } : {}),
          ...(eventType == 'knowledge_complete' ? { completionCount: inc } : {}),
          ...(eventType == 'favorite_add' ? { favoriteCount: inc } : {}),
          ...(eventType == 'share_action' ? { shareCount: inc } : {}),
          ...(eventType == 'quiz_complete'
            ? {
                quizAttempts: inc,
                quizCorrectTotal: admin.firestore.FieldValue.increment(Number(event.properties?.correct || 0)),
                quizQuestionTotal: admin.firestore.FieldValue.increment(Number(event.properties?.total || 0)),
              }
            : {}),
          ...(eventType == 'audio_play' ? { audioPlayCount: inc } : {}),
          ...(eventType == 'audio_complete' ? { audioCompleteCount: inc } : {}),
        },
        { merge: true },
      );
    }

    const userMetricRef = firestore.collection('user_analytics').doc(userId);
    writeBatch.set(
      userMetricRef,
      {
        userId,
        lastEventAt: admin.firestore.FieldValue.serverTimestamp(),
        totalEvents: admin.firestore.FieldValue.increment(1),
        [`events.${eventType}`]: admin.firestore.FieldValue.increment(1),
        [`categories.${category}`]: admin.firestore.FieldValue.increment(1),
      },
      { merge: true },
    );

    await writeBatch.commit();
  });

export const recomputeAnalyticsRollups = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const metricsSnap = await firestore.collection('content_metrics').get();
    const batch = firestore.batch();

    metricsSnap.docs.forEach((doc) => {
      const data = doc.data();
      const viewCount = Number(data.viewCount || 0);
      const completionCount = Number(data.completionCount || 0);
      const favoriteCount = Number(data.favoriteCount || 0);
      const shareCount = Number(data.shareCount || 0);
      const quizAttempts = Number(data.quizAttempts || 0);
      const quizCorrectTotal = Number(data.quizCorrectTotal || 0);
      const quizQuestionTotal = Number(data.quizQuestionTotal || 0);

      const completionRate = viewCount == 0 ? 0 : completionCount / viewCount;
      const favoriteRate = viewCount == 0 ? 0 : favoriteCount / viewCount;
      const shareRate = viewCount == 0 ? 0 : shareCount / viewCount;
      const quizSuccessRate = quizQuestionTotal == 0 ? 0 : quizCorrectTotal / quizQuestionTotal;

      batch.set(
        doc.ref,
        {
          completionRate,
          favoriteRate,
          shareRate,
          quizSuccessRate,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    await batch.commit();

    await recomputeRetentionMetrics();
    return null;
  });

async function recomputeRetentionMetrics(): Promise<void> {
  const now = new Date();
  const since7 = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  const eventsSnap = await firestore
    .collection('analytics_events')
    .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(since7))
    .get();

  const dauMap = new Map<string, Set<string>>();
  const wauUsers = new Set<string>();

  eventsSnap.docs.forEach((doc) => {
    const data = doc.data();
    const userId = String(data.userId || 'anonymous');
    const ts = (data.timestamp as admin.firestore.Timestamp | undefined)?.toDate() ?? new Date();
    const day = ts.toISOString().split('T')[0] ?? 'unknown';

    wauUsers.add(userId);
    if (!dauMap.has(day)) dauMap.set(day, new Set<string>());
    dauMap.get(day)!.add(userId);
  });

  const batch = firestore.batch();
  for (const [day, users] of dauMap.entries()) {
    batch.set(
      firestore.collection('retention_metrics').doc(day),
      {
        date: day,
        dau: users.size,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  const weekKey = now.toISOString().split('T')[0] ?? 'week';
  batch.set(
    firestore.collection('retention_metrics').doc(`week_${weekKey}`),
    {
      wau: wauUsers.size,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await batch.commit();
}

function normalizeDate(timestamp: unknown): string {
  if (timestamp && typeof timestamp === 'object' && 'toDate' in (timestamp as Record<string, unknown>)) {
    const date = (timestamp as admin.firestore.Timestamp).toDate();
    return date.toISOString().split('T')[0] ?? 'unknown';
  }

  return new Date().toISOString().split('T')[0] ?? 'unknown';
}
