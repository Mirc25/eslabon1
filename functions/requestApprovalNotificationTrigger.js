import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";

if (!getApps().length) initializeApp();
const db = getFirestore();

// Envía notificación sólo cuando la solicitud pasa a 'approved'
export const requestApprovalNotificationTrigger = onDocumentUpdated(
  "solicitudes-de-ayuda/{requestId}",
  async (event) => {
    try {
      const requestId = event.params.requestId;
      const before = event.data?.before?.data() || {};
      const after = event.data?.after?.data() || {};

      const prevStatus = String(before?.moderation?.status || "");
      const nextStatus = String(after?.moderation?.status || "");
      const estado = String(after?.estado || "activa");

      // Solo notificar si cambió a 'approved' y está activa
      if (prevStatus === nextStatus || nextStatus !== "approved" || estado !== "activa") {
        return;
      }

      const title = String(after.title || after.titulo || "Solicitud verificada cerca de ti");
      const ownerId = String(after.userId || "");
      const reqLat = Number(after.latitude ?? after.lat ?? NaN);
      const reqLon = Number(after.longitude ?? after.lng ?? NaN);
      const reqProv = String(after.provincia || after.province || "");
      const description = String(after.description || after.descripcion || after.detalle || "");

      if (isNaN(reqLat) || isNaN(reqLon)) {
        logger.warn("Solicitud aprobada sin coordenadas válidas; se omite push", { requestId });
        return;
      }

      // Usuarios con push habilitado (se puede optimizar con índices/segmentación)
      const usersSnap = await db.collection("users")
        .where("pushNotificationsEnabled", "==", true)
        .get();

      if (usersSnap.empty) {
        logger.warn("No hay usuarios con push habilitado para notificar aprobación", { requestId });
        return;
      }

      const tokens = [];
      let notifiedCount = 0;

      // Recoger FCM tokens simples (mejorable con filtro de distancia)
      usersSnap.forEach((doc) => {
        const data = doc.data() || {};
        const uid = doc.id;
        const token = data.fcmToken;
        // Evitar notificar al dueño en el broadcast; tendrá notificación específica
        if (!uid || uid === ownerId) return;
        if (token) {
          tokens.push(token);
          notifiedCount++;
        }
      });

      if (tokens.length === 0) {
        logger.warn("Sin tokens FCM válidos para notificar", { requestId });
        return;
      }

      let requesterName = "";
      try {
        if (ownerId) {
          const ownerDoc = await db.collection("users").doc(ownerId).get();
          if (ownerDoc.exists) {
            const ownerData = ownerDoc.data() || {};
            requesterName = String(ownerData.name || ownerData.displayName || ownerData.firstName || ownerData.username || ownerData.email || "");
          }
        }
      } catch (e) {
        logger.warn("No se pudo obtener nombre del solicitante", { ownerId, error: e?.message });
      }

      const firstName = requesterName ? requesterName.split(" ")[0] : "Alguien";

      const payload = {
        notification: {
          title: `✅ Verificada: ${title}`,
          body: `${firstName} publicó una solicitud verificada cerca de ti.`,
        },
        data: {
          type: "help_request_approved",
          requestId,
          requestTitle: title,
          requestDescription: description,
          requesterId: ownerId,
          requesterName: firstName,
          route: `/request/${requestId}`,
          latitude: isNaN(reqLat) ? "" : String(reqLat),
          longitude: isNaN(reqLon) ? "" : String(reqLon),
          provincia: reqProv || "",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "eslabon_channel",
            priority: "high",
            color: "#000000",
          },
        },
      };

      const messaging = getMessaging();
      const response = await messaging.sendEachForMulticast({ tokens, ...payload });
      logger.info("✅ Push de solicitud aprobada enviado", { requestId, notifiedCount, successCount: response.successCount, failureCount: response.failureCount });

      // Notificación dirigida al dueño (solicitante) para confirmar aprobación
      if (ownerId) {
        try {
          const ownerNotification = {
            type: "request_approved",
            title: `✅ Tu solicitud fue aprobada`,
            body: `La solicitud "${title}" ahora es visible para todos.`,
            timestamp: new Date(),
            read: false,
            data: {
              type: "request_approved",
              notificationType: "request_approved",
              requestId,
              route: `/request/${requestId}`,
            },
          };
          await db.collection("users").doc(ownerId).collection("notifications").add(ownerNotification);
          logger.info("✅ Notificación de aprobación creada para el dueño", { ownerId, requestId });
        } catch (e) {
          logger.warn("⚠️ No se pudo crear la notificación para el dueño", { ownerId, error: e?.message });
        }
      }
    } catch (error) {
      logger.error("🚨 Error en requestApprovalNotificationTrigger", { error: error.message });
    }
  }
);