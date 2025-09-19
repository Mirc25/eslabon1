import { initializeApp, getApps } from "firebase-admin/app";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";

if (!getApps().length) {
  initializeApp();
}

export const createNotificationTrigger = onDocumentCreated(
  "users/{userId}/notifications/{notificationId}",
  async (event) => {
    logger.log("🔔 Notificación creada", event.params);

    const db = getFirestore();

    const notification = event.data?.data();
    const userId = event.params.userId;

    if (!notification) {
      logger.error("❗ No hay datos de notificación");
      return;
    }

    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      logger.warn("⚠️ No se encontró FCM token para el usuario", { userId });
      return;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: notification.title || "Nueva notificación",
        body: notification.body || "",
      },
      data: {
        notificationType: notification.type || "",
      },
    };

    try {
      const response = await getMessaging().send(message);
      logger.log("✅ Notificación FCM enviada", response);
    } catch (error) {
      logger.error("🚨 Error enviando FCM", { error });
    }
  }
);


