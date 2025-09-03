import { initializeApp } from "firebase-admin/app";
import { getApps } from "firebase-admin/app";
if (!getApps().length) {
  initializeApp();
}
import { onRequest } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

const db = getFirestore();

export const sendChatNotification = onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Método no permitido.');
  }

  const { chatRoomId, senderId, senderName, recipientId, messageText } = req.body;

  if (!chatRoomId || !senderId || !senderName || !recipientId || !messageText) {
    logger.error("Faltan datos obligatorios:", { body: req.body });
    return res.status(400).send("Faltan parámetros.");
  }

  const notification = {
    type: 'chat_message',
    title: `${senderName} Dice:`,
    body: messageText,
    timestamp: FieldValue.serverTimestamp(),
    read: false,
    recipientId,
    data: {
      notificationType: 'chat_message',
      chatPartnerId: senderId,
      chatPartnerName: senderName,
      chatRoomId,
    },
  };

  try {
    await db.collection("users").doc(recipientId).collection("notifications").add(notification);
    logger.log("Notificación de chat guardada.");
    res.status(200).send("OK");
  } catch (error) {
    logger.error("Error guardando notificación de chat:", { error });
    res.status(500).send("Error interno.");
  }
});
