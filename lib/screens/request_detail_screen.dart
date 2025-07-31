// lib/screens/request_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../services/app_services.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  final Map<String, dynamic>? requestData; // Datos de la solicitud pasados por extra (opcional)

  const RequestDetailScreen({Key? key, required this.requestId, this.requestData}) : super(key: key);

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final AppServices _appServices;

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth);
  }

  // ✅ CORREGIDO: Aceptar requestData como nullable
  Future<void> _offerHelp(Map<String, dynamic>? requestData) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      AppServices.showSnackBar(context, 'Debes iniciar sesión para ofrecer ayuda.', Colors.red);
      return;
    }
    // ✅ CORREGIDO: Comprobar si requestData es nulo antes de acceder a sus campos
    if (requestData == null) {
      AppServices.showSnackBar(context, 'Error: Datos de la solicitud no disponibles.', Colors.red);
      return;
    }

    final String requesterId = requestData['userId'];
    final String requesterEmail = requestData['email'];
    final String requesterName = requestData['name'];

    if (requesterId == null || requesterEmail == null || requesterName == null) {
      AppServices.showSnackBar(context, 'Error: Datos del solicitante incompletos en la solicitud.', Colors.red);
      return;
    }

    if (currentUser.uid == requesterId) {
      AppServices.showSnackBar(context, 'No puedes ofrecer ayuda a tu propia solicitud.', Colors.red);
      return;
    }

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
      await _firestore.collection('offers').add({
        'requestId': widget.requestId,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'helperId': currentUser.uid,
        'helperName': helperName,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      AppServices.showSnackBar(context, '¡Oferta de ayuda enviada con éxito!', Colors.green);

    } catch (e) {
      AppServices.showSnackBar(context, 'Error al enviar la oferta de ayuda: $e', Colors.red);
      print('Error al enviar la oferta de ayuda: $e');
    }
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final Uri whatsappUri = Uri.parse('whatsapp://send?phone=$phoneNumber');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    } else {
      AppServices.showSnackBar(context, 'No se pudo abrir WhatsApp.', Colors.red);
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      AppServices.showSnackBar(context, 'No se pudo abrir la aplicación de correo.', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      showLogo: true,
      showAds: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'Detalle de Solicitud',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: FutureBuilder<DocumentSnapshot>(
          future: widget.requestData != null
              ? Future.value(null)
              : _firestore.collection('requests').doc(widget.requestId).get(),
          builder: (context, snapshot) {
            Map<String, dynamic>? requestData;

            if (widget.requestData != null) {
              requestData = widget.requestData;
            } else if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Solicitud no encontrada.'));
            } else {
              requestData = snapshot.data!.data() as Map<String, dynamic>;
            }

            if (requestData == null) {
              return const Center(child: Text('Datos de solicitud no disponibles.'));
            }

            final String requesterName = requestData['name'] ?? 'Usuario Desconocido';
            final String description = requestData['description'] ?? 'Sin descripción.';
            final String? requesterEmail = requestData['email'];
            final String? requesterPhone = requestData['phone'];
            final double? latitude = requestData['latitude'];
            final double? longitude = requestData['longitude'];
            final String? imageUrl = requestData['imageUrl'];

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
                          : const AssetImage('assets/default_avatar.png') as ImageProvider,
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
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      image: const DecorationImage(
                        image: AssetImage('assets/map_placeholder.png'),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (requesterPhone != null && requesterPhone.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _launchWhatsApp(requesterPhone),
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
                  Center(
                    child: ElevatedButton(
                      onPressed: () => _offerHelp(requestData), // Pasa requestData directamente
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