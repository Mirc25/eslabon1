import { initializeApp } from "firebase-admin/app";
import { getApps } from "firebase-admin/app";
if (!getApps().length) {
  initializeApp();
}

import { onRequest } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";

const db = getFirestore();

export const sendPanicNotification = onRequest(async (req, res) => {
  const { userId, userName, userPhone, userEmail, userPhotoUrl, latitude, longitude } = req.body;

  if (!userId || !latitude || !longitude) {
    return res.status(400).send("Faltan datos obligatorios.");
  }

  const getDistance = (lat1, lon1, lat2, lon2) => {
    const R = 6371e3;
    const ÃƒÆ’Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â 1 = lat1 * Math.PI / 180;
    const ÃƒÆ’Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â 2 = lat2 * Math.PI / 180;
    const ÃƒÆ’Ã…Â½ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â  = (lat2 - lat1) * Math.PI / 180;
    const ÃƒÆ’Ã…Â½ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â» = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(ÃƒÆ’Ã…Â½ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â  / 2) ** 2 + Math.cos(ÃƒÆ’Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â 1) * Math.cos(ÃƒÆ’Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â 2) * Math.sin(ÃƒÆ’Ã…Â½ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â» / 2) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  };

  const users = await db.collection("users").get();
  const fcmTokens = [];

  users.forEach(doc => {
    const data = doc.data();
    if (doc.id !== userId && data.latitude && data.longitude && data.fcmToken) {
      const d = getDistance(latitude, longitude, data.latitude, data.longitude);
      if (d <= 10000) fcmTokens.push(data.fcmToken);
    }
  });

  if (fcmTokens.length === 0) {
    return res.status(200).send("No se encontraron usuarios cercanos.");
  }

  const payload = {
    notification: {
      title: `ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡Alerta de pÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡nico de ${userName}!`,
      body: `Este usuario necesita ayuda urgente.`,
      sound: 'panic_alert.mp3',
    },
    data: {
      type: 'panic_alert',
      userId,
      latitude: latitude.toString(),
      longitude: longitude.toString(),
    },
  };

  try {
    await getMessaging().sendEachForMulticast({ tokens: fcmTokens, ...payload });
    res.status(200).send("Alerta enviada.");
  } catch (error) {
    logger.error("Error al enviar alerta:", { error });
    res.status(500).send("Error interno.");
  }
});
