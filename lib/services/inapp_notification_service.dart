// lib/services/inapp_notification_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();
bool _notifInited = false;

Future<void> initLocalNotifs() async {
  if (_notifInited) return;
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const init = InitializationSettings(android: android);
  await fln.initialize(
    init,
    onDidReceiveNotificationResponse: onNotificationResponse,
    onDidReceiveBackgroundNotificationResponse: onNotificationResponseBackground,
  );
  _notifInited = true;
}

@pragma('vm:entry-point')
void onNotificationResponse(NotificationResponse r) async {
  final p = r.payload == null ? <String,dynamic>{} : json.decode(r.payload!);
  final threadId = (p['threadId'] as String?) ?? '';
  switch (r.actionId) {
    case 'REPLY':
      final text = r.input?.trim();
      if (text != null && text.isNotEmpty) {
        await sendQuickReply(threadId, text);
      }
      break;
    case 'MARK_READ':
      await markThreadRead(threadId);
      break;
    default:
      break;
  }
}

@pragma('vm:entry-point')
void onNotificationResponseBackground(NotificationResponse r) {
  onNotificationResponse(r);
}

Future<void> showChatMessageNotif(Map<String, dynamic> data) async {
  await initLocalNotifs();

  final senderName  = (data['senderName'] ?? 'Nuevo mensaje').toString();
  final messageText = (data['messageText'] ?? '').toString();
  final threadId    = (data['threadId'] ?? '').toString();
  final senderId    = (data['senderId'] ?? '').toString();
  final avatarUrl   = (data['senderAvatar'] ?? '').toString();
  final myUid       = (data['recipientUid'] ?? '').toString();
  final whenMs      = int.tryParse((data['sentAt'] ?? '').toString()) ?? DateTime.now().millisecondsSinceEpoch;
  final when        = DateTime.fromMillisecondsSinceEpoch(whenMs);
  final nid         = threadId.hashCode & 0x7fffffff;

  AndroidBitmap<Object>? largeIcon;
  if (avatarUrl.isNotEmpty) {
    try {
      final bytes = await http.readBytes(Uri.parse(avatarUrl));
      largeIcon = ByteArrayAndroidBitmap(bytes);
    } catch (_) {}
  }

  final me = Person(name: 'Tú', key: myUid.isNotEmpty ? myUid : 'me', bot: false);
  final sender = Person(name: senderName, key: senderId, bot: false);

  final style = MessagingStyleInformation(
    me,
    groupConversation: false,
    conversationTitle: senderName,
    messages: [Message(messageText, when, sender)],
  );

  final details = AndroidNotificationDetails(
    'chat_messages',
    'Mensajes',
    channelDescription: 'Mensajes de chat',
    category: AndroidNotificationCategory.message,
    styleInformation: style,
    largeIcon: largeIcon,
    groupKey: 'thread_$threadId',
    importance: Importance.high,
    priority: Priority.high,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction(
        'REPLY',
        'Responder',
        inputs: [AndroidNotificationActionInput(label: 'Escribe…')],
        allowGeneratedReplies: true,
        showsUserInterface: true,
      ),
      const AndroidNotificationAction('MARK_READ', 'Leído'),
    ],
  );

  await fln.show(
    nid,
    senderName,
    messageText,
    NotificationDetails(android: details),
    payload: json.encode({'threadId': threadId}),
  );
}

Future<void> sendQuickReply(String threadId, String text) async {
  try {
    final auth = FirebaseAuth.instance;
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(threadId);
    final chatDoc = await chatRef.get();
    String? otherId;
    if (chatDoc.exists) {
      final d = chatDoc.data() as Map<String, dynamic>? ?? {};
      final a = (d['participants'] as List?)?.map((e)=>e.toString()).toList() ?? <String>[];
      otherId = a.firstWhere((x)=>x != uid, orElse: ()=> (d['otherId'] ?? '') as String? ?? '');
    }

    await chatRef.collection('messages').add({
      'senderId': uid,
      'receiverId': otherId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await chatRef.update({
      'lastMessage': {
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': uid,
      }
    });
  } catch (_) {}
}

Future<void> markThreadRead(String threadId) async {
  try {
    final auth = FirebaseAuth.instance;
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final qs = await FirebaseFirestore.instance
      .collection('users').doc(uid)
      .collection('notifications')
      .where('type', isEqualTo: 'chat_message')
      .where('route', isEqualTo: '/chat/$threadId')
      .limit(10).get();

    for (final doc in qs.docs) {
      await doc.reference.update({'read': true});
    }
  } catch (_) {}
}

class InAppNotificationService {
  static Future<void> createChatNotification({ String? senderUid,
    String? threadId,
    String? chatId,
    required String senderName,
    String messageText = '',
    String? senderId,
    String? senderAvatar,
    int? sentAt,
    String? recipientUid,
  }) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (senderUid != null && me != null && senderUid == me) { return; }
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (senderUid != null && senderUid == myUid) { return; }

    final id = (threadId ?? chatId ?? '').trim();
    final safeId = id.isEmpty ? 'general' : id;

    // Obtener contador de mensajes no leídos
    final unreadCount = await _getUnreadCount(safeId, myUid ?? '');
    
    await showChatMessageNotif({
      'threadId': safeId,
      'senderName': 'Chat $senderName',
      'messageText': unreadCount > 1 ? '$unreadCount mensajes nuevos' : messageText,
      'unreadCount': unreadCount,
      if ((senderId ?? senderUid) != null) 'senderId': (senderId ?? senderUid)!,
      if (senderAvatar != null) 'senderAvatar': senderAvatar,
      if (sentAt != null) 'sentAt': sentAt,
      if (recipientUid != null) 'recipientUid': recipientUid,
    });
  }

  static Future<int> _getUnreadCount(String chatId, String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final lastReadTimestamps = userData['lastReadTimestamps'] as Map<String, dynamic>? ?? {};
      final lastReadTimestamp = lastReadTimestamps[chatId] as Timestamp?;

      Query query = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: userId);

      if (lastReadTimestamp != null) {
        query = query.where('timestamp', isGreaterThan: lastReadTimestamp);
      }

      final unreadMessages = await query.get();
      return unreadMessages.docs.length;
    } catch (e) {
      return 1; // Default to 1 if error
    }
  }
}