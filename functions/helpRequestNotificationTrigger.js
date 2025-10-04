import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";

if (!getApps().length) initializeApp();
const db = getFirestore();

// Haversine distance in km
function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (v) => (v * Math.PI) / 180;
  const R = 6371; // Earth radius km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

export const helpRequestNotificationTrigger = onDocumentCreated(
  "solicitudes-de-ayuda/{requestId}",
  async (event) => {
    try {
      const requestId = event.params.requestId;
      const requestData = event.data?.data() || {};
      const estado = String(requestData.estado || "activa");
      const title = String(requestData.title || requestData.titulo || "Nueva solicitud de ayuda");
      const ownerId = String(requestData.userId || "");
      const reqLat = Number(requestData.latitude ?? requestData.lat ?? NaN);
      const reqLon = Number(requestData.longitude ?? requestData.lng ?? NaN);
      const reqProv = String(requestData.provincia || requestData.province || "");

      // Notificar sólo si está activa
      if (estado !== "activa") {
        logger.info("Solicitud no activa; se omite push", { requestId, estado });
        return;
      }

      logger.info("🔔 Nueva solicitud de ayuda creada", { requestId, title, ownerId, reqLat, reqLon, reqProv });

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

      usersSnap.forEach((doc) => {
        const u = doc.data() || {};
        const uid = doc.id;
        if (!uid || uid === ownerId) return; // evitar notificar al dueño

        const sortingPref = String(u.sortingPreference || "");
        const userProv = String(u.province || "");
        const userLat = Number(u.latitude ?? NaN);
        const userLon = Number(u.longitude ?? NaN);
        const searchRadius = Number(u.searchRadius ?? 3); // km (por defecto 3 km)

        let matches = false;
        if (sortingPref === "Cercano" || sortingPref === "Más cercanos" || sortingPref === "Mas cercanos" || sortingPref === "Nearby") {
          if (!isNaN(userLat) && !isNaN(userLon) && !isNaN(reqLat) && !isNaN(reqLon)) {
            const dist = haversineKm(userLat, userLon, reqLat, reqLon);
            matches = dist <= searchRadius;
          }
        } else if (sortingPref === "Provincial") {
          matches = userProv && reqProv && userProv === reqProv;
        } else if (sortingPref === "Nacional") {
          matches = true;
        } else {
          // Preferencia indefinida: si tenemos coordenadas del usuario y de la solicitud, usar un radio por defecto
          if (!isNaN(userLat) && !isNaN(userLon) && !isNaN(reqLat) && !isNaN(reqLon)) {
            const dist = haversineKm(userLat, userLon, reqLat, reqLon);
            matches = dist <= 3; // radio por defecto 3 km
          }
        }

        if (!matches) return;

        const token = u.fcmToken;
        if (token) {
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
          title: `Solicitud cercana: ${title}`,
          body: "Hay una nueva solicitud de ayuda cerca de tu ubicación.",
        },
        data: {
          type: "help_nearby",
          notificationType: "help_nearby",
          requestId: String(requestId),
          requestTitle: String(title),
          route: `/request/${requestId}`,
          latitude: isNaN(reqLat) ? "" : String(reqLat),
          longitude: isNaN(reqLon) ? "" : String(reqLon),
          provincia: reqProv || "",
        },
        android: {
          priority: "high",
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