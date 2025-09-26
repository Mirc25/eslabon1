import { initializeApp, getApps } from "firebase-admin/app";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";

if (!getApps().length) {
  initializeApp();
}

const db = getFirestore();

export const ratingNotificationTrigger = onDocumentCreated(
  "ratings/{ratingId}",
  async (event) => {
    logger.log("🌟 Rating creado, enviando notificación", event.params);

    const rating = event.data?.data();
    if (!rating) {
      logger.error("❗ No hay datos de rating");
      return;
    }

    const {
      ratedUserId,
      sourceUserId,
      rating: ratingValue,
      comment,
      type,
      requestId,
      timestamp
    } = rating;

    if (!ratedUserId || !sourceUserId || !ratingValue) {
      logger.warn("⚠️ Datos de rating incompletos", { ratedUserId, sourceUserId, ratingValue });
      return;
    }

    try {
      // Obtener datos del usuario que calificó
      const raterDoc = await db.collection("users").doc(sourceUserId).get();
      const raterData = raterDoc.data();
      const raterName = raterData?.name || raterData?.displayName || "Usuario";

      // Obtener datos del usuario calificado
      const ratedUserDoc = await db.collection("users").doc(ratedUserId).get();
      const ratedUserData = ratedUserDoc.data();
      const fcmToken = ratedUserData?.fcmToken;

      if (!fcmToken) {
        logger.warn("⚠️ No se encontró FCM token para el usuario calificado", { ratedUserId });
        return;
      }

      // Obtener datos de la solicitud
      let requestTitle = "Solicitud de ayuda";
      let originalRequesterId = null;
      if (requestId) {
        try {
          const requestDoc = await db.collection("solicitudes-de-ayuda").doc(requestId).get();
          const requestData = requestDoc.data();
          requestTitle = requestData?.titulo || requestData?.descripcion || requestTitle;
          originalRequesterId = requestData?.userId; // ID del solicitante original
          logger.info("📋 Datos de solicitud obtenidos", { 
            requestId, 
            originalRequesterId, 
            sourceUserId, 
            ratedUserId, 
            type,
            requestTitle 
          });
        } catch (e) {
          logger.warn("No se pudo obtener datos de la solicitud", { requestId, error: e.message });
        }
      }

      // Determine notification content based on who was rated
      const isHelperRating = type === "helper_rating";
      let notificationData;
      if (isHelperRating) {
          // Helper was rated by requester - notify helper and allow them to rate back
          // The helper (ratedUserId) should rate the requester (sourceUserId)
          // So requesterId should be sourceUserId (the one who rated the helper)
          notificationData = {
              title: `¡${raterName} te calificó!`,
              body: `Recibiste ${ratingValue} estrellas. ¿Quieres calificar a ${raterName}?`,
              route: `/rate-requester/${requestId}?requesterId=${sourceUserId}&requesterName=${encodeURIComponent(raterName)}`,
              type: 'rate_requester',
              data: {
                  requestId: requestId || "",
                  requesterId: sourceUserId, // The requester who rated the helper (correct)
                  requesterName: raterName, // The requester's name (correct)
                  ratingId: event.params.ratingId,
                  raterName,
                  rating: ratingValue
              }
          };
          logger.info("🔔 Notificación para helper (puede calificar al requester)", { 
              helperBeingNotified: ratedUserId, // Helper receiving notification
              requesterToRate: sourceUserId, // Requester to be rated by helper
              originalRequesterId,
              sourceUserId,
              ratedUserId,
              route: `/rate-requester/${requestId}?requesterId=${sourceUserId}&requesterName=${encodeURIComponent(raterName)}`
          });
      } else {
          // Requester was rated by helper - notify requester and allow them to rate back
          // The requester (ratedUserId) should rate the helper (sourceUserId)
          // So helperId should be sourceUserId (the one who rated the requester)
          notificationData = {
              title: `¡${raterName} te calificó!`,
              body: `Recibiste ${ratingValue} estrellas. ¿Quieres calificar a ${raterName}?`,
              route: `/rate-helper/${requestId}?helperId=${sourceUserId}&helperName=${encodeURIComponent(raterName)}`,
              type: 'rate_helper',
              data: {
                  requestId: requestId || "",
                  helperId: sourceUserId, // The helper who rated the requester (correct)
                  helperName: raterName, // The helper's name (correct)
                  ratingId: event.params.ratingId,
                  raterName,
                  rating: ratingValue
              }
          };
          logger.info("🔔 Notificación para requester (puede calificar al helper)", { 
              requesterBeingNotified: ratedUserId, // Requester receiving notification
              helperToRate: sourceUserId, // Helper to be rated by requester
              originalRequesterId,
              sourceUserId,
              ratedUserId,
              route: `/rate-helper/${requestId}?helperId=${sourceUserId}&helperName=${encodeURIComponent(raterName)}`
          });
      }

      // Crear notificación en Firestore
      const notification = {
        type: notificationData.type,
        title: notificationData.title,
        body: notificationData.body,
        timestamp: timestamp || new Date(),
        read: false,
        data: {
          notificationType: notificationData.type,
          ratingId: event.params.ratingId,
          requestId: requestId || "",
          raterName,
          rating: ratingValue,
          comment: comment || "",
          ratingType: type || "",
          route: notificationData.route,
          ...notificationData.data
        }
      };

      await db
        .collection("users")
        .doc(ratedUserId)
        .collection("notifications")
        .add(notification);

      // Enviar notificación FCM
      const message = {
        token: fcmToken,
        notification: {
          title: notificationData.title,
          body: notificationData.body,
        },
        data: {
          notificationType: notificationData.type,
          ratingId: event.params.ratingId,
          requestId: requestId || "",
          route: notificationData.route
        },
        android: {
          priority: "high",
          notification: {
            channelId: "default",
            priority: "high"
          }
        }
      };

      // 🔍 DEBUGGING: Log completo del payload FCM antes de enviar
      logger.log("🔍 [FCM] PRE-SEND CHECK", {
        ratedUserId,
        sourceUserId,
        type,
        requestId,
        route: notificationData.route,
        data: message.data
      });

      // Validaciones específicas según el prompt
      if (type === 'helper_rating') {
        logger.log("🔍 [FCM] HELPER_RATING VALIDATION", {
          condition: "helperId === sourceUserId",
          helperId: notificationData.data.requesterId, // En helper_rating, el helper califica al requester
          sourceUserId,
          isValid: notificationData.data.requesterId === sourceUserId,
          ratedUserId_should_not_equal_sourceUserId: ratedUserId !== sourceUserId
        });
      } else if (type === 'requester_rating') {
        logger.log("🔍 [FCM] REQUESTER_RATING VALIDATION", {
          condition: "requesterId === sourceUserId", 
          requesterId: notificationData.data.helperId, // En requester_rating, el requester califica al helper
          sourceUserId,
          isValid: notificationData.data.helperId === sourceUserId,
          ratedUserId_should_not_equal_sourceUserId: ratedUserId !== sourceUserId
        });
      }

      logger.log("🔍 [FCM] PAYLOAD COMPLETO ANTES DE ENVIAR", {
        ratedUserId,
        requestId,
        originalRequesterId,
        sourceUserId,
        raterName,
        rating: ratingValue,
        type,
        route: notificationData.route,
        messageData: message.data,
        notificationTitle: message.notification.title,
        notificationBody: message.notification.body,
        dedupeKey: `${requestId}:${sourceUserId}:${type}`,
        timestamp: new Date().toISOString()
      });

      const response = await getMessaging().send(message);
      logger.log("✅ Notificación de rating enviada", { 
        ratedUserId, 
        raterName, 
        rating: ratingValue, 
        messageId: response,
        notificationType: notificationData.type
      });

    } catch (error) {
      logger.error("🚨 Error enviando notificación de rating", { 
        error: error.message,
        ratedUserId,
        sourceUserId 
      });
    }
  }
);