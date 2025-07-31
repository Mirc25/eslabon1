// lib/screens/rate_offer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

// Importa tu widget de fondo personalizado
import '../widgets/custom_background.dart';
// Importa tu CustomAppBar si la usas
import '../widgets/custom_app_bar.dart';

class RateOfferScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String helperId; // El ID del usuario que hizo la oferta

  const RateOfferScreen({
    Key? key,
    required this.requestId,
    required this.helperId,
  }) : super(key: key);

  @override
  ConsumerState<RateOfferScreen> createState() => _RateOfferScreenState();
}

class _RateOfferScreenState extends ConsumerState<RateOfferScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double _currentRating = 3.0; // Valor inicial de la calificación

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyRated(); // Opcional: para evitar doble calificación
  }

  // Opcional: Verificar si ya se calificó esta oferta
  Future<void> _checkIfAlreadyRated() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Puedes necesitar una forma más robusta de identificar una calificación única para esta oferta/ayudador
    // Por ejemplo, un campo 'offerId' en la colección 'ratings' si se crea uno.
    final QuerySnapshot existingRatings = await _firestore
        .collection('ratings')
        .where('requestId', isEqualTo: widget.requestId)
        .where('raterUserId', isEqualTo: currentUser.uid)
        .where('ratedUserId', isEqualTo: widget.helperId)
        .where('type', isEqualTo: 'helper_rating')
        .limit(1)
        .get();

    if (existingRatings.docs.isNotEmpty) {
      // Si ya hay una calificación, puedes deshabilitar el botón o mostrar un mensaje.
      // Por ahora, solo informamos.
      print('Esta oferta ya ha sido calificada por este solicitante.');
    }
  }

  Future<void> _submitRating(
      Map<String, dynamic> helperData, Map<String, dynamic> requestData) async {
    final User? currentUser = _auth.currentUser; // El solicitante
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para calificar.')),
      );
      return;
    }

    // Asegurarse de que el usuario actual es el solicitante de la petición
    if (currentUser.uid != requestData['userId']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Solo el solicitante puede calificar esta oferta.')),
      );
      return;
    }

    try {
      // Guardar la calificación en la colección 'ratings'
      await _firestore.collection('ratings').add({
        'requestId': widget.requestId,
        'ratedUserId': widget.helperId, // El ayudador es el calificado
        'raterUserId': currentUser.uid, // El solicitante es quien califica
        'rating': _currentRating,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'helper_rating', // Indica que el solicitante califica al ayudador
        'raterUserName': requestData['name'] ?? 'Solicitante',
        'ratedUserName': helperData['name'] ?? 'Ayudador',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calificación enviada con éxito.')),
      );

      // Las Cloud Functions (updateUserRating y sendRatingNotifications)
      // se encargarán automáticamente de:
      // 1. Actualizar el promedio de calificación del ayudador.
      // 2. Enviar la notificación 'rating_received' al ayudador.
      // 3. Enviar la notificación 'invite_rate_requester' al ayudador
      //    para que califique al solicitante (si es parte del flujo).

      context.go('/'); // Redirige a la pantalla principal o al historial
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar calificación: $e')),
      );
      print('Error al enviar calificación: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      showLogo: true,
      showAds: false, // Puedes ajustar si quieres publicidad aquí
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CustomAppBar(title: 'Calificar Oferta'),
        body: FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait([
            _firestore.collection('users').doc(widget.helperId).get(),
            _firestore.collection('requests').doc(widget.requestId).get(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData ||
                snapshot.data![0].data() == null ||
                snapshot.data![1].data() == null) {
              return const Center(child: Text('Datos no encontrados.'));
            }

            final helperData = snapshot.data![0].data() as Map<String, dynamic>;
            final requestData = snapshot.data![1].data() as Map<String, dynamic>;

            final String helperName = helperData['name'] ?? 'Ayudador Desconocido';
            final String? helperPhotoUrl = helperData['photoUrl'];
            final String requestDescription = requestData['description'] ?? 'Sin descripción.';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center, // Centra el contenido
                children: [
                  const SizedBox(height: 20),
                  // Nombre y foto del ayudador
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: helperPhotoUrl != null && helperPhotoUrl.isNotEmpty
                        ? NetworkImage(helperPhotoUrl)
                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    helperName,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  // Detalles breves del pedido
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detalles de la Solicitud:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          requestDescription,
                          style: const TextStyle(fontSize: 16),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Puedes añadir más detalles de la solicitud aquí si son relevantes
                        // Text('Ubicación: ${requestData['location'] ?? 'N/A'}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Estrellas para calificar
                  const Text(
                    'Califica la ayuda recibida:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _currentRating.floor() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () {
                          setState(() {
                            _currentRating = (index + 1).toDouble();
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu calificación: ${_currentRating.round()}/5',
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 32),
                  // Botón "Enviar calificación"
                  ElevatedButton(
                    onPressed: () => _submitRating(helperData, requestData),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary, // Un color de acento
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('Enviar Calificación'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}