import { onRequest } from "firebase-functions/v2/https";
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

if (!getApps().length) initializeApp();
const db = getFirestore();

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
      return res.status(400).send("Faltan parámetros obligatorios.");
    }
    
    // FIX CRÍTICO: Prevenir la notificación si el ayudador es el mismo que el solicitante (Auto-oferta). 
    if (receiverId === helperId) { 
        console.error(`ERROR: Auto-oferta detectada. RequesterId (${receiverId}) es igual a HelperId (${helperId}). No se enviará notificación.`); 
        return res.status(400).send("Auto-oferta no permitida."); 
    } 
    // FIN DEL FIX CRÍTICO

    const safeTitle = requestTitle || requestData?.title || "Nueva solicitud";

    const notification = {
      type: "offer_received",
      title: `¡${helperName} quiere ayudarte!`,
      body: `Toca para ver los detalles de "${safeTitle}".`,
      timestamp: FieldValue.serverTimestamp(),
      read: false,
      recipientId: receiverId,
      data: {
        notificationType: "offer_received",
        type: "offer_received",
        route: `/request/${requestId}`,       // <- RUTA EXPLÍCITA AL DETALLE
        requestId,
        requestTitle: safeTitle,
        helperId,
        helperName,
        requestData: requestData || {},
        priority: priority ?? null,
        location: location ?? null,
      },
    };

    await db
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
