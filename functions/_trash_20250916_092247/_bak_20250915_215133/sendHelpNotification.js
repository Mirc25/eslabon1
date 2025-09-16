import { onRequest } from "firebase-functions/v2/https";
import admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();

export const sendHelpNotification = onRequest({ cors: true }, async (req, res) => {
  try {
    const {
      requestId,
      receiverId,
      helperId,
      helperName,
      requestTitle,
      requestData,
      priority,
      location
    } = req.body || {};

    if (!requestId || !receiverId || !helperId || !helperName) {
      return res.status(400).send("Faltan parÃƒÆ’Ã‚Â¡metros obligatorios.");
    }
    const safeTitle = requestTitle || requestData?.title || "Nueva solicitud";

    const notification = {
      type: "offer_received",
      title: Ãƒâ€šÃ‚Â¡ quiere ayudarte!,
      body: Toca para ver los detalles de \"\".,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      recipientId: receiverId,
      data: {
        notificationType: "offer_received",
        requestId,
        requestTitle: safeTitle,
        helperId,
        helperName,
        requestData: requestData || {},
        priority: priority ?? null,
        location: location ?? null,
      },
    };

    await admin
      .firestore()
      .collection("users")
      .doc(receiverId)
      .collection("notifications")
      .add(notification);

    return res.status(200).send("OK");
  } catch (e) {
    console.error(e);
    return res.status(500).send("Error interno.");
  }
});
