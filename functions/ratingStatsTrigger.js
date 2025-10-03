import { initializeApp, getApps } from "firebase-admin/app";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

if (!getApps().length) initializeApp();
const db = getFirestore();

export const ratingStatsTrigger = onDocumentCreated("ratings/{ratingId}", async (event) => {
  const rating = event.data?.data();
  if (!rating) return;

  const ratedUserId = rating.ratedUserId ?? rating.targetUserId;
  const sourceUserId = rating.sourceUserId;
  const ratingValue = rating.rating ?? rating.value;
  const type = rating.type;

  if (!ratedUserId || !sourceUserId || typeof ratingValue !== "number") return;
  if (ratedUserId === sourceUserId) return; // Evitar auto-rating

  const userRef = db.collection("users").doc(ratedUserId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const cur = snap.exists ? snap.data() : {};
    const ratingCount = (cur.ratingCount || 0) + 1;
    const ratingSum = (cur.ratingSum || 0) + ratingValue;
    const averageRating = ratingSum / ratingCount;
    tx.set(userRef, { ratingCount, ratingSum, averageRating }, { merge: true });
  });

  const inc = FieldValue.increment(1);
  if (type === "helper_rating") {
    await db.collection("users").doc(ratedUserId).update({ helpedCount: inc }).catch(() => {});
    await db.collection("users").doc(sourceUserId).update({ receivedHelpCount: inc }).catch(() => {});
  } else if (type === "requester_rating") {
    await db.collection("users").doc(ratedUserId).update({ receivedHelpCount: inc }).catch(() => {});
    await db.collection("users").doc(sourceUserId).update({ helpedCount: inc }).catch(() => {});
  }
});