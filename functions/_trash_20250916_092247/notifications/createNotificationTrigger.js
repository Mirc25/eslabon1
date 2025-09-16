// createNotificationTrigger.js
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";

export const createNotificationTrigger = onDocumentCreated(
  "users/{userId}/notifications/{notificationId}",
  async (event) => {
    logger.log("ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã¢â‚¬â„¢Ãƒâ€šÃ‚Â NotificaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n creada", event.params);

    const db = getFirestore(); // ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ InicializaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n segura

    const notification = event.data.data();
    const userId = event.params.userId;

    if (!notification) {
      logger.error("ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚ÂÃƒâ€¦Ã¢â‚¬â„¢ No hay datos de notificaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n");
      return;
    }

    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      logger.warn("ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã‚Â¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â No FCM token found");
      return;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: notification.title || "Nueva notificaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n",
        body: notification.body || "",
      },
      data: {
        notificationType: notification.type || "",
      },
    };

    try {
      const response = await getMessaging().send(message);
      logger.log("ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NotificaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n FCM enviada:", response);
    } catch (error) {
      logger.error("ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒâ€šÃ‚Â¥ Error enviando FCM:", error);
    }
  }
);
