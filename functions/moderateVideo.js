import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onObjectFinalized } from 'firebase-functions/v2/storage';
import vision from '@google-cloud/vision';
import { loadModerationConfig, ssToScore } from './moderationConfig.js';

if (!getApps().length) {
  initializeApp();
}

const client = new vision.ImageAnnotatorClient();

function decideStatusFromThumb(ss, thresholds) {
  const adult = ssToScore(ss.adult);
  const racy = ssToScore(ss.racy);
  const violence = ssToScore(ss.violence);
  const medical = ssToScore(ss.medical);
  const spoof = ssToScore(ss.spoof);

  if (adult >= thresholds.adult_reject_at) return { status: 'rejected', reason: 'adult_thumb' };
  if (racy >= thresholds.racy_reject_at) return { status: 'rejected', reason: 'racy_thumb' };
  if (violence >= thresholds.violence_review_at) return { status: 'manual_review', reason: 'violence_thumb' };
  if (medical >= thresholds.medical_review_at) return { status: 'manual_review', reason: 'medical_thumb' };
  if (spoof >= thresholds.spoof_review_at) return { status: 'manual_review', reason: 'spoof_thumb' };
  return { status: 'approved', reason: 'safe_thumb' };
}

export const moderateVideoUpload = onObjectFinalized({
  cpu: 1,
  memory: '256MiB',
  region: 'us-central1',
}, async (event) => {
  const obj = event.data;
  const bucketName = obj.bucket;
  const name = obj.name || '';
  const contentType = obj.contentType || '';
  if (!name.startsWith('pending/') || !contentType.startsWith('video/')) return;

  const storage = getStorage().bucket(bucketName);
  const db = getFirestore();
  const config = await loadModerationConfig();

  const docPath = obj.metadata?.docPath;
  const thumbPath = obj.metadata?.thumbnailPath; // recomendado: setear en metadata al subir

  let decision = { status: 'manual_review', reason: 'no_thumbnail' };

  if (thumbPath) {
    try {
      const [result] = await client.safeSearchDetection(`gs://${bucketName}/${thumbPath}`);
      const safe = result?.safeSearchAnnotation;
      if (safe) {
        decision = decideStatusFromThumb(safe, config.thresholds);
      } else {
        decision = { status: 'manual_review', reason: 'thumb_no_safesearch' };
      }
    } catch (e) {
      console.error('[MOD][VID] Vision error for thumbnail:', e);
      decision = { status: 'manual_review', reason: 'thumb_error' };
    }
  }

  const destPrefix = decision.status === 'approved'
    ? 'public/'
    : (decision.status === 'manual_review' ? 'quarantine/' : 'rejected/');
  const destName = name.replace('pending/', destPrefix);

  try {
    await storage.file(name).move(destName);
    console.log(`[MOD][VID] Moved ${name} -> ${destName} (${decision.status})`);
  } catch (e) {
    console.error('[MOD][VID] Move failed:', e);
  }

  if (docPath) {
    try {
      await db.doc(docPath).set({
        moderation: {
          status: decision.status,
          reason: decision.reason,
          updatedAt: FieldValue.serverTimestamp(),
        },
        media: {
          videoPath: destName,
          thumbnailPath: thumbPath || null,
        },
      }, { merge: true });
      console.log(`[MOD][VID] Updated doc ${docPath} → ${decision.status}`);
    } catch (e) {
      console.error('[MOD][VID] Firestore update failed:', e);
    }
  } else {
    console.warn('[MOD][VID] Missing metadata.docPath; only storage moved');
  }
});