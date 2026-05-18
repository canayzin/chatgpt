import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

if (!admin.apps.length) {
  admin.initializeApp();
}

const firestore = admin.firestore();

export const detectAnalyticsAnomalies = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async () => {
    const today = new Date();
    const dayKey = today.toISOString().split('T')[0] ?? 'unknown';

    const [todayDailySnap, recentRetentionSnap, generationBatches] = await Promise.all([
      firestore.collection('analytics_daily').doc(dayKey).get(),
      firestore.collection('retention_metrics').where('date', '!=', null).limit(8).get(),
      firestore
        .collection('content_batches')
        .orderBy('createdAt', 'desc')
        .limit(5)
        .get(),
    ]);

    const alerts: Array<Record<string, unknown>> = [];

    const todayDaily = todayDailySnap.data() ?? {};
    const todaysActive = ((todayDaily.activeUsers as unknown[]) ?? []).length;

    const daus = recentRetentionSnap.docs
      .map((doc) => Number(doc.data().dau || 0))
      .filter((n) => n > 0)
      .sort((a, b) => a - b);

    if (daus.length >= 3) {
      const baseline = average(daus.slice(0, -1));
      if (baseline > 0 && todaysActive > 0 && todaysActive < baseline * 0.7) {
        alerts.push({
          type: 'dau_drop',
          severity: 'high',
          baseline,
          current: todaysActive,
          message: 'DAU dropped more than 30% versus trailing baseline',
        });
      }
    }

    const fatalCrashes = Number(todayDaily.events?.app_crash_fatal || 0);
    if (fatalCrashes > 20) {
      alerts.push({
        type: 'crash_rate_spike',
        severity: 'critical',
        current: fatalCrashes,
        message: 'Fatal crash volume exceeded threshold',
      });
    }

    const failedBatch = generationBatches.docs.find((doc) => doc.data().status === 'failed');
    if (failedBatch) {
      alerts.push({
        type: 'content_generation_failure',
        severity: 'medium',
        batchId: failedBatch.id,
        message: 'Latest content generation batch has failed status',
      });
    }

    if (alerts.isEmpty) return null;

    await firestore.collection('ops_alerts').add({
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      dateKey: dayKey,
      alerts,
      source: 'detectAnalyticsAnomalies',
    });

    return null;
  });

function average(values: number[]): number {
  if (values.length == 0) return 0;
  return values.reduce((sum, val) => sum + val, 0) / values.length;
}
