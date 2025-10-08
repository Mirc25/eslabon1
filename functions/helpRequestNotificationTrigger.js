import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";

if (!getApps().length) initializeApp();
const db = getFirestore();

// Filtro geográfico estricto: enviar solo a usuarios dentro de su radio (searchRadius)

export const helpRequestNotificationTrigger = onDocumentCreated(
  "solicitudes-de-ayuda/{requestId}",
  async (event) => {
    try {
      const requestId = event.params.requestId;
      const requestData = event.data?.data() || {};
      const estado = String(requestData.estado || "activa");
      const moderationStatus = String(requestData?.moderation?.status || "pending");
      const title = String(requestData.title || requestData.titulo || "Nueva solicitud de ayuda");
      const ownerId = String(requestData.userId || "");
      const reqLat = Number(requestData.latitude ?? requestData.lat ?? NaN);
      const reqLon = Number(requestData.longitude ?? requestData.lng ?? NaN);
      const reqProv = String(requestData.provincia || requestData.province || "");
      const description = String(requestData.description || requestData.descripcion || requestData.detalle || "");

      // Notificar sólo si está activa y aprobada (evitar notificar en 'pending')
      if (estado !== "activa" || moderationStatus !== "approved") {
        logger.info("Solicitud no activa; se omite push", { requestId, estado });
        return;
      }

      logger.info("🔔 Nueva solicitud de ayuda creada", { requestId, title, ownerId, reqLat, reqLon, reqProv });

      // Validación: requerimos coordenadas válidas de la solicitud para aplicar filtro geográfico
      if (isNaN(reqLat) || isNaN(reqLon)) {
        logger.warn("❗ Solicitud sin coordenadas válidas; se omite push para evitar notificaciones fuera de rango", { requestId });
        return;
      }

      // Obtener usuarios candidatos (evitar recorrer toda la colección en producción: limitar por flags)
      const usersSnap = await db.collection("users")
        .where("pushNotificationsEnabled", "==", true)
        .get();

      if (usersSnap.empty) {
        logger.warn("No hay usuarios con push habilitado");
        return;
      }

      const tokens = [];
      let notifiedCount = 0;

      // Obtener nombre del solicitante para personalizar el título
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

      // Haversine para calcular distancia en km
      const toRad = (deg) => (deg * Math.PI) / 180;
      const distanceKm = (lat1, lon1, lat2, lon2) => {
        const R = 6371; // km
        const dLat = toRad(lat2 - lat1);
        const dLon = toRad(lon2 - lon1);
        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                  Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
                  Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
      };

      usersSnap.forEach((doc) => {
        const u = doc.data() || {};
        const uid = doc.id;
        if (!uid || uid === ownerId) return; // evitar notificar al dueño

        const pushEnabled = !!u.pushNotificationsEnabled;
        const token = u.fcmToken;
        const userLat = Number(u.latitude ?? NaN);
        const userLon = Number(u.longitude ?? NaN);
        const radiusKm = Number(u.searchRadius ?? 3.0);

        // Requiere ubicación válida del usuario para aplicar radio
        if (!pushEnabled || !token || isNaN(userLat) || isNaN(userLon)) {
          return;
        }

        const dist = distanceKm(userLat, userLon, reqLat, reqLon);
        if (dist <= radiusKm) {
          tokens.push(token);
          notifiedCount += 1;
        }
      });

      if (tokens.length === 0) {
        logger.info("No hay FCM tokens para notificar tras filtros aplicados", { requestId });
        return;
      }

      const payload = {
        notification: {
          // Título personalizado: «(Nombre) necesita ayuda cerca de ti»
          title: `(${firstName}) necesita ayuda cerca de ti`,
          // Cuerpo: descripción de la solicitud (fallback si no hay)
          body: description || "Hay una nueva solicitud de ayuda cerca de tu ubicación.",
        },
        data: {
          type: "help_nearby",
          notificationType: "help_nearby",
          requestId: String(requestId),
          requestTitle: String(title),
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
            // Intento de acento oscuro; el sistema decide el fondo final
            color: "#000000",
          },
        },
      };

      const messaging = getMessaging();
      const response = await messaging.sendEachForMulticast({
        tokens,
        ...payload,
      });
      logger.info("✅ Push de solicitud cercana enviado", { requestId, notifiedCount, successCount: response.successCount, failureCount: response.failureCount });
    } catch (error) {
      logger.error("🚨 Error en helpRequestNotificationTrigger", { error: error.message });
    }
  }
);