import { onRequest } from "firebase-functions/v2/https";
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";

if (!getApps().length) initializeApp();
const db = getFirestore();

/**
 * Función HTTP para enviar notificaciones de rating o de propósito general de forma manual o para pruebas.
 * Espera el siguiente cuerpo de solicitud (request.body):
 * {
 *   "ratedUserId": "ID_DEL_USUARIO_QUE_RECIBE_LA_NOTIFICACION",
 *   "fcmToken": "TOKEN_FCM_DEL_USUARIO",
 *   "title": "Título de la notificación",
 *   "body": "Cuerpo del mensaje",
 *   "route": "/ruta/de/navegacion",
 *   "data": { // Campos opcionales para datos específicos de la app
 *     "type": "rating_general",
 *     "requestId": "ID_DE_SOLICITUD",
 *     // ... cualquier otro dato necesario para la navegación
 *   }
 * }
 */
export const sendRatingNotification = onRequest({ cors: true }, async (req, res) => {
  try {
    const {
      ratedUserId,
      fcmToken,
      title,
      body,
      route,
      data
    } = req.body || {};

    // 1. Validación de parámetros mínimos
    if (!ratedUserId || !fcmToken || !title || !body || !route) {
      logger.error("❗ Faltan parámetros obligatorios en el payload de sendRatingNotification.", req.body);
      return res.status(400).send("Faltan parámetros obligatorios (ratedUserId, fcmToken, title, body, route).");
    }

    // 2. Crear notificación en Firestore
    const notification = {
      type: data?.type || 'rating_general',
      title: title,
      body: body,
      timestamp: FieldValue.serverTimestamp(),
      read: false,
      data: {
        notificationType: data?.type || 'rating_general',
        route: route,
        ...data
      }
    };

    await db
      .collection("users")
      .doc(ratedUserId)
      .collection("notifications")
      .add(notification);

    // 3. Enviar notificación FCM
    const message = {
      token: fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        notificationType: notification.type,
        route: notification.data.route,
        // Incluir todos los datos recibidos en el payload
        ...notification.data
      },
      android: {
        priority: "high",
        notification: {
          channelId: "default",
          priority: "high"
        }
      }
    };

    const response = await getMessaging().send(message);
    logger.log("✅ Notificación de rating HTTP enviada", { ratedUserId, messageId: response });

    return res.status(200).send("OK");
  } catch (error) {
    logger.error("🚨 Error en sendRatingNotification", { error: error.message, body: req.body });
    return res.status(500).send("Error interno.");
  }
});