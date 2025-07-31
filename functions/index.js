// index.js (ES Modules)
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as admin from "firebase-admin"; // ✅ CORREGIDO: Importación de admin

initializeApp();
const db = getFirestore();

/**
 * 🔔 Dispara al crear un documento en /users/{userId}/notifications
 * Esta función es la que realmente envía la notificación FCM al dispositivo.
 */
export const createNotificationTrigger = onDocumentCreated(
  "users/{userId}/notifications/{notificationId}",
  async (event) => {
    const notification = event.data.data(); // Datos de la notificación guardada en Firestore
    const userId = event.params.userId;

    logger.log("Notificación creada para el usuario:", userId, notification);

    if (!notification) {
      logger.error("No se encontró información de la notificación");
      return;
    }

    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken; // Asegúrate de que el token FCM esté guardado aquí

    if (!fcmToken) {
      logger.warn(`No se encontró un token FCM para el usuario ${userId}`);
      return;
    }

    // Extraer campos relevantes para el payload de FCM, asegurando que no sean undefined/null
    const notificationType = notification.type || "";
    const requestId = notification.requestId || "";
    const helperId = notification.helperId || "";
    const requesterId = notification.requesterId || ""; // Para rating_received
    const helperName = notification.helperName || ""; // Para offer_received
    const requesterName = notification.raterName || ""; // Para rating_received
    const requestData = notification.requestData || {}; // Objeto completo de requestData
    const rating = notification.rating; // Para rating_received

    let navigationPath = "";
    let navigationExtra = {};

    // Construir navigationPath y navigationExtra basado en el tipo de notificación
    switch (notificationType) {
      case 'offer_received':
        // Asegúrate de que requestId y helperId no sean vacíos para la ruta
        const safeRequestIdOffer = requestId || 'unknown_request';
        const safeHelperIdOffer = helperId || 'unknown_helper';
        navigationPath = `/rate-helper/${safeRequestIdOffer}`;
        navigationExtra = {
          helperId: safeHelperIdOffer,
          helperName: helperName,
          requestData: requestData, // Pasa el objeto completo
        };
        break;
      case 'rating_received': // Cuando un usuario califica a otro (ej. Ayudador califica Solicitante)
        const safeRequestIdRating = requestId || 'unknown_request';
        const safeRequesterIdRating = requesterId || 'unknown_requester';
        navigationPath = `/rate-requester/${safeRequestIdRating}`;
        navigationExtra = {
          requesterId: safeRequesterIdRating,
          requesterName: requesterName,
          rating: rating,
        };
        break;
      case 'new_request': // Si quieres navegar a los detalles de una nueva solicitud
        const safeRequestIdNewRequest = requestId || 'unknown_request';
        navigationPath = `/request_detail/${safeRequestIdNewRequest}`;
        navigationExtra = {
          requestData: requestData,
        };
        break;
      // Añade otros casos de navegación si tienes más tipos de notificación
      default:
        navigationPath = '/main'; // Ruta por defecto
        break;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: notification.title || "Nueva notificación",
        body: notification.body || "",
      },
      data: {
        // ✅ CAMPOS PLANOS EN EL PAYLOAD 'data' PARA FACILITAR LA LECTURA EN FLUTTER
        'notificationType': notificationType, // El tipo de notificación
        'navigationPath': navigationPath, // La ruta a la que debe navegar Flutter
        'notificationId': event.params.notificationId, // ID del documento de notificación en Firestore
        'requestId': requestId, // Asegura que estos campos estén presentes, incluso si son vacíos
        'helperId': helperId,
        'helperName': helperName,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'rating': rating ? rating.toString() : '', // Convertir a string si es numérico
        'requestData': JSON.stringify(requestData), // ✅ Stringify el objeto complejo
      },
    };

    try {
      const response = await getMessaging().send(message);
      logger.log("Notificación FCM enviada correctamente:", response);
    } catch (error) {
      logger.error("Error al enviar la notificación FCM:", error);
    }
  }
);

/**
 * 📩 Llamada HTTPS para enviar una notificación de ayuda ofrecida
 * Esta función guarda la notificación en Firestore, que luego dispara createNotificationTrigger.
 */
export const sendHelpNotification = onRequest(async (req, res) => {
  // ✅ CORREGIDO: Asegura que los parámetros no sean undefined/null al desestructurar
  const { requesterId = '', requestId = '', helperId = '', helperName = '', requestData = {} } = req.body;

  if (!requesterId || !requestId || !helperId || !helperName) { // requestData puede ser un objeto vacío
    return res.status(400).send("Faltan parámetros obligatorios para sendHelpNotification (requesterId, requestId, helperId, helperName).");
  }

  const notificationToSave = {
    title: "Nueva oferta de ayuda",
    body: `${helperName} ha ofrecido ayuda para tu solicitud "${requestData?.descripcion || ""}"`,
    type: "offer_received", // Este 'type' es leído por createNotificationTrigger
    requestId: requestId,
    helperId: helperId,
    helperName: helperName, // Pasar helperName para que esté disponible en el trigger
    requestData: requestData, // Pasar requestData completo para que esté disponible en el trigger
    timestamp: admin.firestore.FieldValue.serverTimestamp(), // Usar timestamp del servidor
    read: false, // Marcar como no leída por defecto
  };

  try {
    await db
      .collection("users")
      .doc(requesterId)
      .collection("notifications")
      .add(notificationToSave);

    res.status(200).send("Notificación de ayuda enviada correctamente.");
  } catch (error) {
    logger.error("Error al guardar la notificación de ayuda en Firestore:", error);
    res.status(500).send("Error al guardar la notificación.");
  }
});

/**
 * ⭐ Llamada HTTPS para enviar notificación cuando se recibe una calificación
 * Esta función guarda la notificación en Firestore, que luego dispara createNotificationTrigger.
 */
export const sendRatingNotification = onRequest(async (req, res) => {
  // ✅ CORREGIDO: Asegura que los parámetros no sean undefined/null al desestructurar
  const { ratedUserId = '', requestId = '', raterName = '', rating, type = '', requestTitle = '' } = req.body;

  if (!ratedUserId || !requestId || !raterName || rating === undefined || !type || !requestTitle) {
    return res.status(400).send("Faltan parámetros obligatorios para sendRatingNotification.");
  }

  const notificationToSave = {
    title: type === 'helper_rated' ? "¡Has sido calificado!" : "¡Has recibido una calificación!",
    body: `${raterName} te ha calificado con ${rating} estrellas por tu ayuda en "${requestTitle}".`,
    type: type, // 'helper_rated' o 'requester_rated'
    requestId: requestId,
    raterName: raterName,
    rating: rating,
    requestTitle: requestTitle,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    read: false,
  };

  try {
    await db
      .collection("users")
      .doc(ratedUserId)
      .collection("notifications")
      .add(notificationToSave);

    res.status(200).send("Notificación de calificación enviada correctamente.");
  } catch (error) {
    logger.error("Error al guardar la notificación de calificación en Firestore:", error);
    res.status(500).send("Error al guardar la notificación.");
  }
});
