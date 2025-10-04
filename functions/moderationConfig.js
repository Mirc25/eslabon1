import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

if (!getApps().length) {
  initializeApp();
}

const DEFAULTS = {
  thresholds: {
    // SafeSearch mapping: VERY_UNLIKELY(0), UNLIKELY(1), POSSIBLE(2), LIKELY(3), VERY_LIKELY(4)
    adult_reject_at: 3,      // LIKELY → rejected
    racy_reject_at: 3,       // LIKELY → rejected
    violence_review_at: 3,   // LIKELY → manual_review
    medical_review_at: 3,    // LIKELY → manual_review
    spoof_review_at: 2,      // POSSIBLE → manual_review
    // Perspective
    toxicity_review_at: 0.82,
    sexual_reject_at: 0.75,
    hate_review_at: 0.75,
  },
};

export async function loadModerationConfig() {
  try {
    const db = getFirestore();
    const snap = await db.doc('config/moderation').get();
    if (snap.exists) {
      const data = snap.data();
      return {
        thresholds: { ...DEFAULTS.thresholds, ...(data?.thresholds || {}) },
        perspectiveApiKey: data?.perspectiveApiKey || process.env.PERSPECTIVE_API_KEY,
      };
    }
  } catch (e) {
    console.error('[MOD][CONFIG] Failed to load config, using defaults:', e);
  }
  return { thresholds: DEFAULTS.thresholds, perspectiveApiKey: process.env.PERSPECTIVE_API_KEY };
}

export function ssToScore(label) {
  switch (label) {
    case 'VERY_UNLIKELY': return 0;
    case 'UNLIKELY': return 1;
    case 'POSSIBLE': return 2;
    case 'LIKELY': return 3;
    case 'VERY_LIKELY': return 4;
    default: return 0;
  }
}