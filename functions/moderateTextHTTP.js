import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { loadModerationConfig } from './moderationConfig.js';

if (!getApps().length) {
  initializeApp();
}

async function analyzeWithPerspective(text, apiKey) {
  if (!apiKey) {
    return { scores: {}, error: 'missing_api_key' };
  }
  const url = `https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze?key=${apiKey}`;
  const body = {
    comment: { text },
    languages: ['es', 'en'],
    requestedAttributes: {
      TOXICITY: {},
      SEXUALLY_EXPLICIT: {},
      IDENTITY_ATTACK: {},
      INSULT: {},
      PROFANITY: {},
    },
  };
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  const attrs = json.attributeScores || {};
  const score = (k) => attrs[k]?.summaryScore?.value ?? 0;
  return {
    scores: {
      toxicity: score('TOXICITY'),
      sexual: score('SEXUALLY_EXPLICIT'),
      hate: score('IDENTITY_ATTACK'),
      insult: score('INSULT'),
      profanity: score('PROFANITY'),
    },
    error: json.error ? json.error.message : null,
  };
}

function decideTextStatus(scores, thresholds) {
  if (scores.sexual >= thresholds.sexual_reject_at) return { status: 'rejected', reason: 'sexual' };
  if (scores.hate >= thresholds.hate_review_at) return { status: 'manual_review', reason: 'hate' };
  if (scores.toxicity >= thresholds.toxicity_review_at) return { status: 'manual_review', reason: 'toxicity' };
  return { status: 'approved', reason: 'clean' };
}

export const moderateTextAndSet = onCall({ region: 'us-central1' }, async (request) => {
  const { docPath, text } = request.data || {};
  if (!docPath || typeof text !== 'string') {
    return { ok: false, error: 'invalid_request' };
  }
  const db = getFirestore();
  const cfg = await loadModerationConfig();
  const analysis = await analyzeWithPerspective(text, cfg.perspectiveApiKey);
  const decision = decideTextStatus(analysis.scores, cfg.thresholds);

  await db.doc(docPath).set({
    moderation: {
      status: decision.status,
      reason: decision.reason,
      scores: analysis.scores,
      updatedAt: FieldValue.serverTimestamp(),
    },
  }, { merge: true });

  return { ok: true, status: decision.status, reason: decision.reason, scores: analysis.scores };
});