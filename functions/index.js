// index.js
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as admin from "firebase-admin";

initializeApp();
const db = getFirestore();

/**
 * 🔔 Cloud Function que se dispara al crear un documento en /users/{userId}/notifications.
 * Su propósito es enviar una notificación push al dispositivo del usuario.
 */
export const createNotificationTrigger = onDocumentCreated(
  "users/{userId}/notifications/{notificationId}",
  async (event) => {
    logger.log("INICIO createNotificationTrigger", { event });

    const notification = event.data.data();
    const userId = event.params.userId;

    logger.log("Notificación creada para el usuario:", { userId, notification });

    if (!notification) {
      logger.error("No se encontró información de la notificación");
      return;
    }

    const userDocRef = db.collection("users").doc(userId);
    const userDoc = await userDocRef.get();
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      logger.warn(`No se encontró un token FCM para el usuario ${userId}`);
      return;
    }
    
    const notificationDataFromDoc = notification.data || notification;
    const notificationType = notification.type || notificationDataFromDoc.notificationType || "";
    const requestId = notificationDataFromDoc.requestId || "";
    const helperId = notificationDataFromDoc.helperId || "";
    const helperName = notificationDataFromDoc.helperName || "";
    const requesterId = notificationDataFromDoc.requesterId || "";
    const requesterName = notificationDataFromDoc.requesterName || notificationDataFromDoc.raterName || "";
    const requestData = notificationDataFromDoc.requestData || {};
    const rating = notificationDataFromDoc.rating;

    let navigationPath = "";

    switch (notificationType) {
      case "offer_received":
        navigationPath = `/rate-helper/${requestId || "unknown_request"}`;
        break;
      case "helper_rated":
        navigationPath = `/rate-requester/${requestId || "unknown_request"}`;
        break;
      case "new_request":
        navigationPath = `/request_detail/${requestId || "unknown_request"}`;
        break;
      case "chat_message":
        navigationPath = `/chat/${notificationDataFromDoc.chatPartnerId || ""}`;
        break;
      default:
        navigationPath = "/main";
        break;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: notification.title || "Nueva notificación",
        body: notification.body || "",
      },
      data: {
        notificationType,
        navigationPath,
        notificationId: event.params.notificationId,
        requestId,
        helperId,
        helperName,
        requesterId,
        requesterName,
        rating: rating ? rating.toString() : "",
        requestData: JSON.stringify(requestData || {}),
      },
    };

    try {
      const response = await getMessaging().send(message);
      logger.log("Notificación FCM enviada correctamente:", { response });
    } catch (error) {
      logger.error("Error al enviar la notificación FCM:", { error });

      if (error.code === 'messaging/invalid-argument' || error.code === 'messaging/registration-token-not-registered') {
        logger.warn(`El token FCM para el usuario ${userId} ya no es válido. Se eliminará de Firestore.`);
        await userDocRef.update({ fcmToken: FieldValue.delete() });
        logger.warn(`Token FCM eliminado para el usuario ${userId}`);
      }
    }
  }
);

/**
 * 📩 Cloud Function que se activa con una petición HTTP (POST) para crear
 * una notificación de oferta de ayuda.
 */
export const sendHelpNotification = onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Método no permitido. Solo se acepta POST.');
  }
  
  const { requestId, requestTitle, receiverId, helperId, helperName, requestData, priority, location } = req.body;

  if (!requestId || !requestTitle || !receiverId || !helperId || !helperName) {
    logger.error("Faltan parámetros obligatorios en la solicitud:", { body: req.body });
    return res.status(400).send("Faltan parámetros obligatorios: requestId, requestTitle, receiverId, helperId, helperName.");
  }

  let parsedRequestData = {};
  if (requestData) {
    if (typeof requestData === 'string') {
      try {
        parsedRequestData = JSON.parse(requestData);
      } catch (e) {
        logger.error("Error al parsear requestData, se usará como un objeto vacío.", { requestData });
      }
    } else if (typeof requestData === 'object') {
      parsedRequestData = requestData;
    }
  }

  const notificationToSave = {
    type: 'offer_received',
    title: `¡Nueva oferta de ayuda para "${requestTitle}"!`,
    body: `${helperName} ha ofrecido ayuda para tu solicitud.`,
    timestamp: FieldValue.serverTimestamp(),
    read: false,
    recipientId: receiverId, // Usamos receiverId como recipientId para la subcolección
    data: {
      notificationType: 'offer_received',
      requestId,
      requestTitle,
      helperId,
      helperName,
      requestData: parsedRequestData,
      priority,
      location,
    },
  };

  try {
    await db.collection("users").doc(receiverId).collection("notifications").add(notificationToSave);
    logger.log("Notificación de ayuda guardada en Firestore", { notificationToSave });
    res.status(200).send("Notificación de ayuda enviada correctamente.");
  } catch (error) {
    logger.error("Error al guardar la notificación en Firestore:", { error });
    res.status(500).send("Error al guardar la notificación.");
  }
});

/**
 * ⭐ Cloud Function que se activa con una petición HTTP (POST) para crear
 * una notificación de calificación.
 */
export const sendRatingNotification = onRequest(async (req, res) => {
  logger.log("INICIO sendRatingNotification", { body: req.body });

  const { ratedUserId = "", requestId = "", raterName = "", rating, type = "", requestTitle = "", requesterId = "" } = req.body;

  if (!ratedUserId || !requestId || !raterName || rating === undefined || !type || !requestTitle || !requesterId) {
    logger.error("Faltan parámetros obligatorios en la solicitud:", { body: req.body });
    return res.status(400).send("Faltan parámetros obligatorios: ratedUserId, requestId, raterName, rating, type, requestTitle, requesterId.");
  }

  const notificationToSave = {
    title: type === "helper_rated" ? "¡Has sido calificado!" : "¡Has recibido una calificación!",
    body: `${raterName} te ha calificado con ${rating} estrellas por tu ayuda en "${requestTitle}".`,
    type,
    data: {
      notificationType: type,
      requestId,
      requesterId, // ✅ AGREGADO
      requesterName: raterName, // ✅ AGREGADO
      rating: rating.toString(), // ✅ CORREGIDO: Convertir a String explícitamente
      requestTitle,
    },
    timestamp: FieldValue.serverTimestamp(),
    read: false,
    recipientId: ratedUserId,
  };

  try {
    await db.collection("users").doc(ratedUserId).collection("notifications").add(notificationToSave);
    res.status(200).send("Notificación de calificación enviada correctamente.");
  } catch (error) {
    logger.error("Error al guardar la notificación de calificación:", { error, notificationToSave });
    res.status(500).send("Error al guardar la notificación.");
  }
});