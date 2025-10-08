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

function decideStatus(ss, thresholds) {
  const adult = ssToScore(ss.adult);
  const racy = ssToScore(ss.racy);
  const violence = ssToScore(ss.violence);
  const medical = ssToScore(ss.medical);
  const spoof = ssToScore(ss.spoof);

  if (adult >= thresholds.adult_reject_at) return { status: 'rejected', reason: 'adult' };
  if (racy >= thresholds.racy_reject_at) return { status: 'rejected', reason: 'racy' };
  if (violence >= thresholds.violence_review_at) return { status: 'manual_review', reason: 'violence' };
  if (medical >= thresholds.medical_review_at) return { status: 'manual_review', reason: 'medical' };
  if (spoof >= thresholds.spoof_review_at) return { status: 'manual_review', reason: 'spoof' };
  return { status: 'approved', reason: 'safe' };
}

export const moderateImageUpload = onObjectFinalized({
  cpu: 1,
  memory: '256MiB',
  // Ajusta la región a la del bucket/proyecto si corresponde
  region: 'us-central1',
  // minInstances: 1, // opcional para evitar cold starts
}, async (event) => {
  const obj = event.data;
  const bucketName = obj.bucket;
  const name = obj.name || '';
  const contentType = obj.contentType || '';
  // Solo procesamos imágenes subidas a pending/*
  if (!name.startsWith('pending/') || !contentType.startsWith('image/')) return;

  const storage = getStorage().bucket(bucketName);
  const db = getFirestore();
  const config = await loadModerationConfig();

  const docPath = obj.metadata?.docPath;
  const fileUri = `gs://${bucketName}/${name}`;

  let safe;
  try {
    const [result] = await client.safeSearchDetection(fileUri);
    safe = result?.safeSearchAnnotation;
  } catch (err) {
    console.error('[MOD][IMG] Vision error:', err);
    safe = null;
  }

  let decision = { status: 'manual_review', reason: 'no_safesearch' };
  if (safe) decision = decideStatus(safe, config.thresholds);

  const destPrefix = decision.status === 'approved'
    ? 'public/'
    : (decision.status === 'manual_review' ? 'quarantine/' : 'rejected/');
  const destName = name.replace('pending/', destPrefix);

  try {
    await storage.file(name).move(destName);
    console.log(`[MOD][IMG] Moved ${name} -> ${destName} (${decision.status})`);
  } catch (e) {
    console.error('[MOD][IMG] Move failed:', e);
  }

  if (docPath) {
    try {
      const updateData = {
        moderation: {
          status: decision.status,
          reason: decision.reason,
          updatedAt: FieldValue.serverTimestamp(),
        },
        media: {
          imagePath: destName,
        },
      };
      // Mantener compatibilidad con UI existente: poblar 'imagenes' cuando esté aprobado
      if (decision.status === 'approved') {
        updateData.imagenes = FieldValue.arrayUnion(destName);
      }
      await db.doc(docPath).set(updateData, { merge: true });
      console.log(`[MOD][IMG] Updated doc ${docPath} → ${decision.status}`);
    } catch (e) {
      console.error('[MOD][IMG] Firestore update failed:', e);
    }
  } else {
    console.warn('[MOD][IMG] Missing metadata.docPath; only storage moved');
  }
});