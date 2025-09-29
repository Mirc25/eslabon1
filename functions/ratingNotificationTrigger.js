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

    // FIX: Prevenir el envío de notificación si es una auto-calificación.
    // Esto evita que el usuario reciba un enlace para calificarse a sí mismo.
    if (ratedUserId === sourceUserId) {
        logger.error("🚨 Auto-calificación detectada (ratedUserId === sourceUserId). No se enviará notificación de rating para evitar errores de navegación en el cliente.", { ratedUserId, sourceUserId });
        return;
    }
    // FIN DEL FIX

    // FIX: Logs temporales para casos de aceptación
    logger.info("📋 [ACCEPTANCE TEST] ratingNotificationTrigger", {
      type,
      requestId,
      ratedUserId,
      sourceUserId,
      ratingValue
    });

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
      
      // Obtener datos adicionales del usuario que va a ser calificado
      let targetUserName = "Usuario";
      let targetUserId = null;
      
      if (isHelperRating) {
          // Helper was rated by requester - notify helper and allow them to rate back
          // The helper (ratedUserId) should rate the ORIGINAL requester (originalRequesterId)
          targetUserId = originalRequesterId; // El requester original que debe ser calificado
          
          // FIX 2: Detener si el ayudador notificado es el mismo que el solicitante al que se debe calificar (A -> A en el rating inverso).
          if (ratedUserId === targetUserId) {
              logger.error("🚨 Inconsistencia de datos: El ayudador notificado (ratedUserId) es el mismo que el solicitante original (targetUserId). No se enviará notificación de calificación inversa.", { ratedUserId, targetUserId, requestId });
              return;
          }

          if (targetUserId) {
              try {
                  const targetUserDoc = await db.collection("users").doc(targetUserId).get();
                  const targetUserData = targetUserDoc.data();
                  targetUserName = targetUserData?.name || targetUserData?.displayName || "Solicitante";
              } catch (e) {
                  logger.warn("No se pudo obtener datos del requester original", { targetUserId, error: e.message });
              }
          }
          
          notificationData = {
              title: `¡${raterName} te calificó!`,
              body: `Recibiste ${ratingValue} estrellas. ¿Quieres calificar a ${targetUserName}?`,
              route: `/rate-requester/${requestId}?requesterId=${targetUserId}&requesterName=${encodeURIComponent(targetUserName)}`,
              type: 'rate_requester',
              data: {
                  requestId: requestId || "",
                  requesterId: targetUserId, // El requester ORIGINAL que debe ser calificado
                  requesterName: targetUserName, // Nombre del requester original
                  ratingId: event.params.ratingId,
                  raterName,
                  rating: ratingValue
              }
          };
          logger.info("🔔 Notificación para helper (puede calificar al requester ORIGINAL)", { 
              helperBeingNotified: ratedUserId, // Helper receiving notification
              originalRequesterToRate: targetUserId, // Requester ORIGINAL to be rated by helper
              originalRequesterId,
              sourceUserId,
              ratedUserId,
              route: `/rate-requester/${requestId}?requesterId=${targetUserId}&requesterName=${encodeURIComponent(targetUserName)}`
          });
      } else {
          // Requester was rated by helper - notify requester and allow them to rate back
          // The requester (ratedUserId) should rate the helper who rated them (sourceUserId)
          targetUserId = sourceUserId; // El helper que calificó al requester
          targetUserName = raterName; // Ya tenemos el nombre del helper
          
          notificationData = {
              title: `¡${raterName} te calificó!`,
              body: `Recibiste ${ratingValue} estrellas. ¿Quieres calificar a ${targetUserName}?`,
              route: `/rate-helper/${requestId}?helperId=${targetUserId}&helperName=${encodeURIComponent(targetUserName)}`,
              type: 'rate_helper',
              data: {
                  requestId: requestId || "",
                  helperId: targetUserId, // El helper que calificó al requester
                  helperName: targetUserName, // Nombre del helper
                  ratingId: event.params.ratingId,
                  raterName,
                  rating: ratingValue
              }
          };
          logger.info("🔔 Notificación para requester (puede calificar al helper)", { 
              requesterBeingNotified: ratedUserId, // Requester receiving notification
              helperToRate: targetUserId, // Helper to be rated by requester
              originalRequesterId,
              sourceUserId,
              ratedUserId,
              route: `/rate-helper/${requestId}?helperId=${targetUserId}&helperName=${encodeURIComponent(targetUserName)}`
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
          type: notificationData.type,
          ratingId: event.params.ratingId,
          requestId: requestId || "",
          route: notificationData.route,
          // Incluir todos los datos necesarios para navegación
          ...(notificationData.data || {}),
          // Asegurar que los campos críticos estén como strings
          requesterId: String(notificationData.data?.requesterId || ""),
          helperId: String(notificationData.data?.helperId || ""),
          raterName: String(notificationData.data?.raterName || ""),
          rating: String(notificationData.data?.rating || "")
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

      // Enviar notificación adicional para ver el ranking actualizado
      const rankingMessage = {
        token: fcmToken,
        notification: {
          title: "🏆 ¡Tu ranking se actualizó!",
          body: `Recibiste ${ratingValue} estrellas de ${raterName}. ¡Ve tu nueva posición en el ranking!`
        },
        data: {
          type: 'view_ranking',
          route: '/ratings?tab=ranking',
          raterName,
          rating: ratingValue.toString(),
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        }
      };

      const rankingResponse = await getMessaging().send(rankingMessage);
      logger.log("✅ Notificación de ranking enviada", { 
        ratedUserId, 
        raterName, 
        rating: ratingValue, 
        messageId: rankingResponse
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