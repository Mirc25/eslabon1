import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_service_provider.dart';

class PushNotificationTestScreen extends ConsumerWidget {
  const PushNotificationTestScreen({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationService = ref.read(notificationServiceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de Notificaciones'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '🧪 Pruebas de Navegación de Notificaciones',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Estos botones simulan notificaciones de rating sin usar FCM real:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            // Test Rate Helper
            ElevatedButton.icon(
              onPressed: () async {
                print('🧪 Testing Rate Helper Navigation...');
                await notificationService.testNotificationNavigation(
                  notificationType: 'rate_helper',
                  requestId: 'test_request_123',
                  helperId: 'test_helper_456',
                  helperName: 'Juan Pérez',
                );
              },
              icon: const Icon(Icons.star),
              label: const Text('🧪 Test: Calificar Ayudador'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Rate Requester
            ElevatedButton.icon(
              onPressed: () async {
                print('🧪 Testing Rate Requester Navigation...');
                await notificationService.testNotificationNavigation(
                  notificationType: 'rate_requester',
                  requestId: 'test_request_789',
                  requesterId: 'test_requester_101',
                  requesterName: 'María García',
                );
              },
              icon: const Icon(Icons.rate_review),
              label: const Text('🧪 Test: Calificar Solicitante'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Helper Rated (alternative type)
            ElevatedButton.icon(
              onPressed: () async {
                print('🧪 Testing Helper Rated Navigation...');
                await notificationService.testNotificationNavigation(
                  notificationType: 'helper_rated',
                  requestId: 'test_request_555',
                  helperId: 'test_helper_666',
                  helperName: 'Carlos López',
                );
              },
              icon: const Icon(Icons.thumb_up),
              label: const Text('🧪 Test: Ayudador Calificado'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 30),
            
            const Divider(),
            
            const SizedBox(height: 20),
            
            const Text(
              '📋 Instrucciones:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              '1. Presiona cualquier botón de prueba\n'
              '2. Revisa los logs en la consola\n'
              '3. Verifica si la navegación funciona\n'
              '4. Si funciona aquí pero no con FCM real, el problema está en el timing de FCM',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
