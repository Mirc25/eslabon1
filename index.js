import { onRequest } from 'firebase-functions/v2/https';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

try { initializeApp(); } catch {}
const db = getFirestore();
const messaging = getMessaging();

const ok  = (res, data='OK') => res.status(200).send(data);
const bad = (res, msg, code=400) => res.status(code).json({ error: msg });
const allowCors = (h) => (req,res)=>{ res.set({
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Methods':'POST, OPTIONS',
  'Access-Control-Allow-Headers':'Content-Type, Authorization'
}); if(req.method==='OPTIONS') return ok(res); return h(req,res); };

export const sendHelpNotification = onRequest({ cors:false }, allowCors(async (req,res)=>{
  if(req.method!=='POST') return bad(res,'Use POST');
  const { requestId, receiverId, helperId, helperName, requestTitle, fcmToken } = req.body || {};
  if(!requestId || !receiverId || !helperId || !helperName || !requestTitle)
    return bad(res,'Faltan campos obligatorios: requestId, receiverId, helperId, helperName, requestTitle');
  try {
    await db.collection('notifications').add({ type:'help', requestId, receiverId, helperId, helperName, requestTitle, createdAt: Date.now() });
  } catch(e){ console.error(e); return bad(res,'Error al guardar la notificación',500); }
  if (fcmToken) { try {
    await messaging.send({ token:fcmToken, notification:{ title:'Nueva oferta de ayuda', body:`${helperName} se ofreció en: ${requestTitle}` }, data:{ type:'help', requestId, helperId } });
  } catch (e) { console.warn('FCM opcional falló:', e?.message || e); } }
  return ok(res,'Help OK');
}));

export const sendChatNotification = onRequest({ cors:false }, allowCors(async (req,res)=>{
  if(req.method!=='POST') return bad(res,'Use POST');
  const { chatRoomId, senderId, senderName, recipientId, messageText } = req.body || {};
  if(!chatRoomId || !senderId || !senderName || !recipientId || !messageText)
    return bad(res,'Faltan datos obligatorios: chatRoomId, senderId, senderName, recipientId, messageText');
  try {
    await db.collection('notifications').add({ type:'chat', chatRoomId, senderId, senderName, recipientId, messageText, createdAt: Date.now() });
  } catch(e){ console.error(e); return bad(res,'Error al guardar notificación de chat',500); }
  return ok(res,'Chat OK');
}));

export const sendPanicNotification = onRequest({ cors:false }, allowCors(async (req,res)=>{
  if(req.method!=='POST') return bad(res,'Use POST');
  const { userId, location } = req.body || {};
  if(!userId) return bad(res,'Falta userId');
  try {
    await db.collection('notifications').add({ type:'panic', userId, location: location || null, createdAt: Date.now() });
  } catch(e){ console.error(e); return bad(res,'Error al guardar notificación de pánico',500); }
  return ok(res,'Panic OK');
}));

export const sendRatingNotification = onRequest({ cors:false }, allowCors(async (req,res)=>{
  if(req.method!=='POST') return bad(res,'Use POST');
  const { raterId, ratedUserId, ratingValue, context } = req.body || {};
  if(!raterId || !ratedUserId || ratingValue==null)
    return bad(res,'Faltan datos obligatorios: raterId, ratedUserId, ratingValue');
  try {
    await db.collection('notifications').add({ type:'rating', raterId, ratedUserId, ratingValue:Number(ratingValue), context: context || null, createdAt: Date.now() });
  } catch(e){ console.error(e); return bad(res,'Error al guardar notificación de rating',500); }
  return ok(res,'Rating OK');
}));