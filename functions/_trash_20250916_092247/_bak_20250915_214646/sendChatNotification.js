import { onRequest } from "firebase-functions/v2/https";
import admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();

export const sendChatNotification = onRequest({ cors: true }, async (req, res) => {
  try {
    const { chatRoomId, senderId, senderName, recipientId, messageText = "" } = req.body || {};
    if (!chatRoomId || !senderId || !senderName || !recipientId) {
      return res.status(400).send("Faltan parÃƒÆ’Ã‚Â¡metros.");
    }

    const isNewChat = !messageText?.trim();
    const notification = {
      type: isNewChat ? "chat_started" : "chat_message",
      title: isNewChat ? ${senderName} iniciÃƒÆ’Ã‚Â³ un chat contigo : ${senderName} dice:,
      body: isNewChat ? "Toca para abrir el chat" : messageText,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      recipientId,
      data: {
        notificationType: isNewChat ? "chat_started" : "chat_message",
        chatPartnerId: senderId,
        chatPartnerName: senderName,
        chatRoomId,
      },
    };

    await admin
      .firestore()
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
