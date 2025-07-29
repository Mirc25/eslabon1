// index.js (ES Modules)
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();
const db = getFirestore();

/**
 * 🔔 Dispara al crear un documento en /users/{userId}/notifications
 */
export const createNotificationTrigger = onDocumentCreated(
  "users/{userId}/notifications/{notificationId}",
  async (event) => {
    const notification = event.data.data();
    const userId = event.params.userId;

    logger.log("Notificación creada para el usuario:", userId, notification);

    if (!notification) {
      logger.error("No se encontró información de la notificación");
      return;
    }

    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      logger.warn(`No se encontró un token FCM para el usuario ${userId}`);
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
        requestId: notification.requestId || "",
        helperId: notification.helperId || "",
        requesterId: notification.requesterId || "",
        requestData: JSON.stringify(notification.requestData || {}),
      },
    };

    try {
      const response = await getMessaging().send(message);
      logger.log("Notificación enviada correctamente:", response);
    } catch (error) {
      logger.error("Error al enviar la notificación:", error);
    }
  }
);

/**
 * 📩 Llamada HTTPS para enviar una notificación de ayuda ofrecida
 */
export const sendHelpNotification = onRequest(async (req, res) => {
  const { requesterId, requestId, helperId, helperName, requestData } = req.body;

  if (!requesterId || !requestId || !helperId || !helperName) {
    return res.status(400).send("Faltan parámetros obligatorios.");
  }

  const notification = {
    title: "Nueva oferta de ayuda",
    body: `${helperName} ha ofrecido ayuda para tu solicitud "${requestData?.description || ""}"`,
    type: "new_offer",
    requestId,
    helperId,
    requestData,
    timestamp: Date.now(),
  };

  try {
    await db
      .collection("users")
      .doc(requesterId)
      .collection("notifications")
      .add(notification);

    res.status(200).send("Notificación de ayuda enviada correctamente.");
  } catch (error) {
    logger.error("Error al guardar la notificación de ayuda:", error);
    res.status(500).send("Error al guardar la notificación.");
  }
});

/**
 * ⭐ Llamada HTTPS para enviar notificación cuando se recibe una calificación
 */
export const sendRatingNotification = onRequest(async (req, res) => {
  const { ratedUserId, requestId, raterName } = req.body;

  if (!ratedUserId || !requestId || !raterName) {
    return res.status(400).send("Faltan parámetros obligatorios.");
  }

  const notification = {
    title: "¡Has recibido una calificación!",
    body: `${raterName} te ha calificado por tu ayuda.`,
    type: "rating_received",
    requestId,
    timestamp: Date.now(),
  };

  try {
    await db
      .collection("users")
      .doc(ratedUserId)
      .collection("notifications")
      .add(notification);

    res.status(200).send("Notificación de calificación enviada correctamente.");
  } catch (error) {
    logger.error("Error al guardar la notificación de calificación:", error);
    res.status(500).send("Error al guardar la notificación.");
  }
});
