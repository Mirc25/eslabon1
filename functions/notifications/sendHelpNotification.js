import { initializeApp } from "firebase-admin/app";
import { getApps } from "firebase-admin/app";
if (!getApps().length) {
  initializeApp();
}

import { onRequest } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

const db = getFirestore();

export const sendHelpNotification = onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Método no permitido. Solo se acepta POST.');
  }

  const { requestId, requestTitle, receiverId, helperId, helperName, requestData, priority, location } = req.body;

  if (!requestId || !requestTitle || !receiverId || !helperId || !helperName) {
    logger.error("Faltan parámetros obligatorios:", { body: req.body });
    return res.status(400).send("Faltan parámetros obligatorios.");
  }

  let parsedRequestData = {};
  if (requestData) {
    if (typeof requestData === 'string') {
      try {
        parsedRequestData = JSON.parse(requestData);
      } catch (e) {
        logger.error("Error al parsear requestData como string.");
      }
    } else {
      parsedRequestData = requestData;
    }
  }

  const notification = {
    type: 'offer_received',
    title: `¡${helperName} quiere ayudarte!`,
    body: `Toca para ver los detalles.`,
    timestamp: FieldValue.serverTimestamp(),
    read: false,
    recipientId: receiverId,
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
    await db.collection("users").doc(receiverId).collection("notifications").add(notification);
    logger.log("Notificación de ayuda enviada correctamente.");
    res.status(200).send("OK");
  } catch (error) {
    logger.error("Error al guardar la notificación:", { error });
    res.status(500).send("Error interno.");
  }
});
