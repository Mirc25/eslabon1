import { onRequest } from "firebase-functions/v2/https";
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

if (!getApps().length) initializeApp();
const db = getFirestore();

export const sendChatNotification = onRequest({ cors: true }, async (req, res) => {
  try {
    const { chatRoomId, senderId, senderName, recipientId, messageText = "" } = req.body || {};
    if (!chatRoomId || !senderId || !senderName || !recipientId) {
      return res.status(400).send("Faltan parámetros.");
    }

    const isNewChat = !messageText?.trim();
    const notification = {
      type: isNewChat ? "chat_started" : "chat_message",
      title: isNewChat ? `¡${senderName} inició un chat contigo!` : `${senderName} dice:`,
      body: isNewChat ? "Toca para abrir el chat" : messageText,
      timestamp: FieldValue.serverTimestamp(),
      read: false,
      recipientId,
      data: {
        notificationType: isNewChat ? "chat_started" : "chat_message",
        chatPartnerId: senderId,
        chatPartnerName: senderName,
        chatRoomId,
      },
    };

    await db
      .collection("users")
      .doc(recipientId)
      .collection("notifications")
      .add(notification);

    return res.status(200).send("OK");
  } catch (e) {
    console.error(e);
    return res.status(500).send("Error interno.");
  }
});
