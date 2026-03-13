import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

if (!admin.apps.length) {
  admin.initializeApp();
}

const firestore = admin.firestore();

export const processReferralInstall = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const referralCode = String(data.referralCode || '').trim().toUpperCase();
  const contentId = String(data.contentId || '').trim() || null;
  if (!referralCode) {
    throw new functions.https.HttpsError('invalid-argument', 'referralCode is required');
  }

  const referringQuery = await firestore
    .collection('referral_profiles')
    .where('referralCode', '==', referralCode)
    .limit(1)
    .get();

  if (referringQuery.empty) {
    throw new functions.https.HttpsError('not-found', 'Referral code not found');
  }

  const referrerDoc = referringQuery.docs[0];
  const referrerUid = referrerDoc.id;
  if (referrerUid === uid) {
    throw new functions.https.HttpsError('failed-precondition', 'Self-referrals are not allowed');
  }

  const installRef = firestore.collection('referral_installs').doc(uid);

  await firestore.runTransaction(async (txn) => {
    const existing = await txn.get(installRef);
    if (existing.exists) {
      const existingReferrer = existing.data()?.referrerId as string | undefined;
      if (existingReferrer === referrerUid) {
        return;
      }
      throw new functions.https.HttpsError('already-exists', 'Referral already claimed');
    }

    const fingerprint = context.rawRequest.headers['x-forwarded-for'] || context.rawRequest.ip || 'unknown';

    txn.set(installRef, {
      userId: uid,
      referrerId: referrerUid,
      referralCode,
      contentId,
      ipHash: hash(String(fingerprint)),
      claimedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'verified',
    });

    txn.set(
      referrerDoc.ref,
      {
        successfulInstalls: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    txn.set(
      firestore.collection('analytics_events').doc(),
      {
        userId: uid,
        eventType: 'referral_install',
        category: 'growth',
        contentId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        sessionId: `referral:${uid}`,
        deviceInfo: {},
        properties: { referrerId: referrerUid, referralCode },
      },
      { merge: false },
    );
  });

  await grantReferralRewards(referrerUid);

  return { ok: true, referrerId: referrerUid };
});

export const recomputeGrowthMetrics = functions.pubsub
  .schedule('every 6 hours')
  .onRun(async () => {
    const now = new Date();
    const dayKey = now.toISOString().split('T')[0] ?? 'unknown';

    const [sharesSnap, installsSnap, referralsSnap, viralContentSnap] = await Promise.all([
      firestore.collection('analytics_events').where('eventType', '==', 'share_action').get(),
      firestore.collection('analytics_events').where('eventType', '==', 'referral_install').get(),
      firestore.collection('referral_installs').get(),
      firestore.collection('content_metrics').orderBy('shareRate', 'desc').limit(20).get(),
    ]);

    const shareCount = sharesSnap.size;
    const installCount = installsSnap.size;
    const uniqueReferrers = new Set(referralsSnap.docs.map((doc) => String(doc.data().referrerId || 'unknown'))).size;

    const shareToInstallRate = shareCount === 0 ? 0 : installCount / shareCount;
    const referralConversionRate = referralsSnap.size == 0 ? 0 : installCount / referralsSnap.size;
    const viralCoefficient = uniqueReferrers == 0 ? 0 : installCount / uniqueReferrers;

    await firestore.collection('growth_metrics').doc(dayKey).set(
      {
        date: dayKey,
        shareCount,
        installCount,
        uniqueReferrers,
        shareToInstallRate,
        referralConversionRate,
        viralCoefficient,
        topViralContent: viralContentSnap.docs.map((d) => ({ contentId: d.id, ...d.data() })),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return null;
  });

export const suggestNotificationWindows = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const sessionsSnap = await firestore.collection('user_sessions').limit(1000).get();

    const perUser: Record<string, { hourCounts: Record<string, number>; categories: Record<string, number> }> = {};

    for (const sessionDoc of sessionsSnap.docs) {
      const userId = String(sessionDoc.data().userId || '');
      if (!userId) continue;

      if (!perUser[userId]) {
        perUser[userId] = { hourCounts: {}, categories: {} };
      }

      const events = await firestore
        .collection('analytics_events')
        .where('userId', '==', userId)
        .orderBy('timestamp', 'desc')
        .limit(80)
        .get();

      events.docs.forEach((eventDoc) => {
        const data = eventDoc.data();
        const date = (data.timestamp as admin.firestore.Timestamp | undefined)?.toDate();
        if (date) {
          const hour = String(date.getUTCHours());
          perUser[userId].hourCounts[hour] = (perUser[userId].hourCounts[hour] ?? 0) + 1;
        }

        const category = String(data.category || 'general');
        perUser[userId].categories[category] = (perUser[userId].categories[category] ?? 0) + 1;
      });
    }

    const batch = firestore.batch();
    for (const [userId, stat] of Object.entries(perUser)) {
      const bestHour = Object.entries(stat.hourCounts).sort((a, b) => b[1] - a[1])[0]?.[0] ?? '18';
      const bestCategory = Object.entries(stat.categories).sort((a, b) => b[1] - a[1])[0]?.[0] ?? 'psychology';

      batch.set(
        firestore.collection('notification_optimization').doc(userId),
        {
          userId,
          bestHourUtc: Number(bestHour),
          preferredCategory: bestCategory,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    await batch.commit();
    return null;
  });

async function grantReferralRewards(referrerUid: string): Promise<void> {
  const profileRef = firestore.collection('referral_profiles').doc(referrerUid);
  const profileSnap = await profileRef.get();
  if (!profileSnap.exists) return;

  const installs = Number(profileSnap.data()?.successfulInstalls || 0);
  const rewards = new Set((profileSnap.data()?.rewards as string[] | undefined) ?? []);

  if (installs >= 1) rewards.add('bonus_streak_badge');
  if (installs >= 3) rewards.add('exclusive_learning_series');
  if (installs >= 5) rewards.add('extra_quiz_pack');

  await profileRef.set(
    {
      rewards: [...rewards],
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function hash(value: string): string {
  let h = 0;
  for (let i = 0; i < value.length; i += 1) {
    h = (h << 5) - h + value.charCodeAt(i);
    h |= 0;
  }
  return String(h);
}
