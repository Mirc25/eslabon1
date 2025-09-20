import "package:firebase_messaging/firebase_messaging.dart";
import "../local_notifs.dart";

void bindForegroundFCM() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    flnp.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          "default_channel",
          "Default",
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  });
}
