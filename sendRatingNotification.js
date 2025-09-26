import { initializeApp } from "firebase-admin/app";
import { getApps } from "firebase-admin/app";
if (!getApps().length) {
  initializeApp();
}

import { onRequest } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

const db = getFirestore();

export const sendRatingNotification = onRequest(async (req, res) => {
  logger.log("INICIO sendRatingNotification", { body: req.body });

  const { ratedUserId = "", requestId = "", raterName = "", rating, type = "", requestTitle = "", requesterId = "", helperId = "", reviewComment = "" } = req.body;

  if (!ratedUserId || !requestId || !raterName || rating === undefined || !type || !requestTitle) {
    logger.error("Faltan parÃ¡metros obligatorios en la solicitud:", { body: req.body });
    return res.status(400).send("Faltan parÃ¡metros obligatorios.");
  }

  // Determinar la ruta según el tipo de calificación
  let route = '';
  if (type === 'rate_helper') {
    route = `/rate-helper/${requestId}`;
    if (helperId && raterName) {
      route += `?helperId=${helperId}&helperName=${encodeURIComponent(raterName)}`;
    }
  } else if (type === 'rate_requester') {
    route = `/rate-requester/${requestId}`;
    if (requesterId && raterName) {
      route += `?requesterId=${requesterId}&requesterName=${encodeURIComponent(raterName)}`;
    }
  }

  const notification = {
    title: `¡Tienes una nueva calificación!`,
    body: `${raterName} te ha calificado con ${rating} estrellas.`,
    type,
    route, // Agregar el campo route para navegación correcta
    data: {
      notificationType: type,
      requestId,
      requesterId,
      requesterName: raterName,
      helperId,
      rating: rating.toString(),
      reviewComment,
      requestTitle,
    },
    timestamp: FieldValue.serverTimestamp(),
    read: false,
    recipientId: ratedUserId,
  };

  try {
    await db.collection("users").doc(ratedUserId).collection("notifications").add(notification);
    res.status(200).send("OK");
  } catch (error) {
    logger.error("Error al guardar la notificaciÃ³n de calificaciÃ³n:", { error });
    res.status(500).send("Error interno.");
  }
});
