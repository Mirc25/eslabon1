import { onRequest } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import { getFirestore } from "firebase-admin/firestore";

// Initialize Firebase Admin if not already initialized
try {
  initializeApp();
} catch (error) {
  // App already initialized
}

export const sendChatNotificationHTTP2 = onRequest(async (req, res) => {
  try {
    // Updated version 2.0
    // Set CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    console.log("Received request body:", JSON.stringify(req.body, null, 2));

    const { 
      receiverToken, 
      title,
      body,
      data
    } = req.body;
    
    const { 
      chatId, 
      senderId, 
      receiverId,
      senderName,
      senderPhotoUrl 
    } = data || {};

    console.log("Extracted parameters:", {
      receiverToken: receiverToken ? "present" : "missing",
      title: title ? "present" : "missing", 
      body: body ? "present" : "missing",
      chatId,
      senderId,
      receiverId,
      senderName
    });

    if (!receiverToken || !title || !body) {
      console.log("Missing required parameters:", { receiverToken: !!receiverToken, title: !!title, body: !!body });
      res.status(400).json({ error: "Missing required parameters" });
      return;
    }

    // Check if receiver is in active chat
    const db = getFirestore();
    const receiverDoc = await db.collection('users').doc(receiverId).get();
    const receiverData = receiverDoc.data();
    
    // Don't send notification if user is in the same chat
    if (receiverData && receiverData.activeChatId === chatId) {
      console.log("User is in active chat, skipping notification");
      res.status(200).json({ success: true, message: "User in active chat, notification skipped" });
      return;
    }

    const payload = {
      notification: {
        title: title,
        body: body,
        imageUrl: senderPhotoUrl || undefined
      },
      data: {
        notificationType: "chat",
        chatPartnerId: senderId,
        chatPartnerName: senderName,
        chatPartnerPhotoUrl: senderPhotoUrl || "",
        route: "/chat",
        chatId: chatId
      },
      android: {
        notification: {
          imageUrl: senderPhotoUrl || undefined,
          channelId: "chat_notifications",
          priority: "high"
        }
      }
    };

    const messaging = getMessaging();
    const message = {
      token: receiverToken,
      notification: payload.notification,
      data: payload.data,
      android: payload.android
    };
    const response = await messaging.send(message);
    
    console.log("Chat notification sent successfully:", response);
    res.status(200).json({ success: true, response });
    
  } catch (error) {
    console.error("Error sending chat notification:", error);
    res.status(500).json({ error: error.message });
  }
});