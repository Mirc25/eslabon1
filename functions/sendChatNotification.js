// functions/sendChatNotification.js

import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import admin from 'firebase-admin';

// Asegúrate de inicializar Firebase Admin SDK si aún no lo has hecho
if (!admin.apps.length) {
    admin.initializeApp();
}

export const sendChatNotification = onDocumentCreated('chats/{chatId}/messages/{messageId}', async (event) => {
    const snap = event.data;
    const context = event.params;
    const message = snap.data();
    const senderId = message.senderId;
    const receiverId = message.receiverId;
    const chatId = context.chatId;

    if (!message.text) {
      return null;
    }

    // Log temprano para depuración del token del receptor
    console.log('Fetching receiver token for user:', receiverId);

    // Obtener los datos del receptor, incluyendo el chat actual y el token FCM
    const receiverDoc = await admin.firestore().collection('users').doc(receiverId).get();
    if (!receiverDoc.exists) {
      console.log('Receiver user not found.');
      return null;
    }
    const receiverData = receiverDoc.data();
    const receiverToken = receiverData.fcmToken;

    // Supresión si el receptor está en el chat activo actual
    const activeChat = receiverData.activeChatId || receiverData.currentChatId;
    if (activeChat === chatId) {
      console.log('Receiver currently in active chat, skipping push.', { receiverId, chatId, activeChat });
      return null;
    }

    // Log de presencia de token FCM del receptor
    console.log('Receiver FCM token:', receiverToken ? 'present' : 'missing');

    // Si no hay token del receptor, finalizar limpiamente
    if (!receiverToken) {
      console.log('Receiver FCM token missing, skipping push.');
      return null;
    }

    // Eliminado temporalmente el filtro de chat activo para garantizar el envío del push

    // Obtener los datos del remitente para la notificación
    const senderDoc = await admin.firestore().collection('users').doc(senderId).get();
    if (!senderDoc.exists) {
      console.log('Sender user not found.');
      return null;
    }
    const senderData = senderDoc.data();
    const senderName = senderData.name || senderData.displayName || senderData.email || 'Usuario';
    const senderAvatarUrl = senderData.profilePicture || ''; // Usar un valor predeterminado si no hay URL
    
    console.log('Sender data:', { senderId, senderName, senderData });

    // Construir la carga útil de la notificación
    const payload = {
      notification: {
        title: `Mensaje de ${senderName}`,
        body: message.text,
      },
      data: {
        type: 'chat',
        notificationType: 'chat_message',
        chatPartnerId: senderId,
        chatPartnerName: senderName,
        chatPartnerAvatar: senderAvatarUrl,
        chatRoomId: chatId,
        chatId: chatId,
        // La ruta a la que la aplicación navegará al hacer clic en la notificación
        route: `/chat/${chatId}?partnerId=${senderId}&partnerName=${senderName}&partnerAvatar=${encodeURIComponent(senderAvatarUrl)}`,
      },
      android: {
        notification: {
          // Usar la URL de la imagen como ícono
          imageUrl: senderAvatarUrl,
          // La configuración para agrupar notificaciones podría ir aquí si fuera necesario
          // tag: chatId,
        },
      },
    };

    try {
      if (receiverToken) {
        await admin.messaging().sendToDevice(receiverToken, payload);
        console.log('Notification sent successfully to:', receiverId);
      }
    } catch (error) {
      console.error('Error sending notification:', error);
    }

    return null;
});