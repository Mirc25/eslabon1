// lib/screens/request_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
// Si quieres el ícono real de WhatsApp, debes agregar la dependencia font_awesome_flutter
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Importa tu widget de fondo personalizado
import '../widgets/custom_background.dart';
// Importa tu CustomAppBar si la usas
import '../widgets/custom_app_bar.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;

  const RequestDetailScreen({Key? key, required this.requestId}) : super(key: key);

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Función para manejar el botón "Ofrecer Ayuda"
  Future<void> _offerHelp(Map<String, dynamic> requestData) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para ofrecer ayuda.')),
      );
      return;
    }

    final String requesterId = requestData['userId']; // ID del solicitante
    final String requesterEmail = requestData['email']; // Email del solicitante
    final String requesterName = requestData['name']; // Nombre del solicitante

    // Evitar que el usuario se ofrezca ayuda a sí mismo
    if (currentUser.uid == requesterId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes ofrecer ayuda a tu propia solicitud.')),
      );
      return;
    }

    // Obtener el nombre del ayudador (usuario actual)
    String helperName = currentUser.displayName ?? 'Usuario Anónimo';
    if (currentUser.displayName == null || currentUser.displayName!.isEmpty) {
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          helperName = userDoc.data()!['name'] ?? 'Usuario Anónimo';
        }
      } catch (e) {
        print('Error fetching helper name: $e');
      }
    }

    try {
      // Crear un documento en la colección 'offers'
      await _firestore.collection('offers').add({
        'requestId': widget.requestId,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'helperId': currentUser.uid,
        'helperName': helperName,
        'status': 'pending', // 'pending', 'accepted', 'rejected'
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Oferta de ayuda enviada con éxito!')),
      );

      // La notificación push 'new_offer' será disparada por la Cloud Function
      // cuando se cree este documento en 'offers'.

      // Opcional: Redirigir o actualizar la UI después de ofrecer ayuda
      // context.pop(); // Volver a la pantalla anterior
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar la oferta de ayuda: $e')),
      );
      print('Error al enviar la oferta de ayuda: $e');
    }
  }

  // Función para lanzar WhatsApp
  Future<void> _launchWhatsApp(String phoneNumber) async {
    final Uri whatsappUri = Uri.parse('whatsapp://send?phone=$phoneNumber');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
      );
    }
  }

  // Función para lanzar Email
  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la aplicación de correo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      showLogo: true, // Muestra el logo centrado
      showAds: true,  // Muestra la publicidad (si está implementada en CustomBackground)
      child: Scaffold(
        backgroundColor: Colors.transparent, // Permite que el fondo personalizado sea visible
        appBar: CustomAppBar(
          title: 'Detalle de Solicitud',
          leading: IconButton( // Botón de regreso explícito
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('requests').doc(widget.requestId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Solicitud no encontrada.'));
            }

            final requestData = snapshot.data!.data() as Map<String, dynamic>;

            final String requesterName = requestData['name'] ?? 'Usuario Desconocido';
            final String description = requestData['description'] ?? 'Sin descripción.';
            final String? requesterEmail = requestData['email'];
            final String? requesterPhone = requestData['phone'];
            final double? latitude = requestData['latitude'];
            final double? longitude = requestData['longitude'];
            final String? imageUrl = requestData['imageUrl']; // URL de la foto del solicitante

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                          ? NetworkImage(imageUrl)
                          : const AssetImage('assets/default_avatar.png') as ImageProvider, // Placeholder
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      requesterName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Descripción:',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ubicación:',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  // Placeholder para el mapa
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      image: const DecorationImage(
                        image: AssetImage('assets/map_placeholder.png'), // Tu imagen de mapa
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        latitude != null && longitude != null
                            ? 'Lat: ${latitude.toStringAsFixed(4)}, Lon: ${longitude.toStringAsFixed(4)}'
                            : 'Ubicación no disponible',
                        style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Botones de WhatsApp y Correo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (requesterPhone != null && requesterPhone.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _launchWhatsApp(requesterPhone),
                          // Usar Icons.message o FaIcon si font_awesome_flutter está agregado
                          icon: const Icon(Icons.message),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      if (requesterEmail != null && requesterEmail.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _launchEmail(requesterEmail),
                          icon: const Icon(Icons.email),
                          label: const Text('Correo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Botón "Ofrecer Ayuda"
                  Center(
                    child: ElevatedButton(
                      onPressed: () => _offerHelp(requestData),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Ofrecer Ayuda'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}