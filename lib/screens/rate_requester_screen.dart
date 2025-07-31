// lib/screens/rate_requester_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

// Importa tu widget de fondo personalizado
import '../widgets/custom_background.dart';
// Importa tu CustomAppBar si la usas
import '../widgets/custom_app_bar.dart';

class RateRequesterScreen extends ConsumerStatefulWidget {
  final String requestId;
  // Opcional: puedes recibir el ID del solicitante directamente si la notificación ya lo trae.
  // Pero aquí lo obtendremos de la request para robustez.
  // final String? requesterId;

  const RateRequesterScreen({
    Key? key,
    required this.requestId,
    // this.requesterId,
  }) : super(key: key);

  @override
  ConsumerState<RateRequesterScreen> createState() => _RateRequesterScreenState();
}

class _RateRequesterScreenState extends ConsumerState<RateRequesterScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double _currentRating = 3.0; // Valor inicial de la calificación

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyRated(); // Opcional: para evitar doble calificación
  }

  // Opcional: Verificar si el ayudador ya calificó a este solicitante para esta solicitud
  Future<void> _checkIfAlreadyRated() async {
    final User? currentUser = _auth.currentUser; // El ayudador
    if (currentUser == null) return;

    // Obtener el ID del solicitante desde la solicitud
    final requestDoc = await _firestore.collection('requests').doc(widget.requestId).get();
    if (!requestDoc.exists || requestDoc.data() == null) return;
    final requesterId = requestDoc.data()!['userId'];

    if (requesterId == null) return;

    final QuerySnapshot existingRatings = await _firestore
        .collection('ratings')
        .where('requestId', isEqualTo: widget.requestId)
        .where('raterUserId', isEqualTo: currentUser.uid) // El ayudador
        .where('ratedUserId', isEqualTo: requesterId) // El solicitante
        .where('type', isEqualTo: 'requester_rating')
        .limit(1)
        .get();

    if (existingRatings.docs.isNotEmpty) {
      print('Ya has calificado a este solicitante para esta solicitud.');
      // Puedes deshabilitar el botón de envío o mostrar un mensaje al usuario.
    }
  }

  Future<void> _submitRating(
      Map<String, dynamic> requesterData, Map<String, dynamic> requestData) async {
    final User? currentUser = _auth.currentUser; // El ayudador (quien califica)
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para calificar.')),
      );
      return;
    }

    final String requesterId = requestData['userId']; // El solicitante (quien es calificado)
    if (requesterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se pudo identificar al solicitante.')),
      );
      return;
    }

    // Evitar que el usuario se califique a sí mismo si por alguna razón la ruta lleva aquí
    if (currentUser.uid == requesterId) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes calificar tu propia solicitud aquí.')),
      );
      return;
    }

    // Obtener el nombre del ayudador (usuario actual)
    String raterUserName = currentUser.displayName ?? 'Usuario';
    if (currentUser.displayName == null || currentUser.displayName!.isEmpty) {
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          raterUserName = userDoc.data()!['name'] ?? 'Usuario';
        }
      } catch (e) {
        print('Error fetching rater name: $e');
      }
    }

    try {
      // Guardar la calificación en la colección 'ratings'
      await _firestore.collection('ratings').add({
        'requestId': widget.requestId,
        'ratedUserId': requesterId, // El solicitante es el calificado
        'raterUserId': currentUser.uid, // El ayudador es quien califica
        'rating': _currentRating,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'requester_rating', // Indica que el ayudador califica al solicitante
        'raterUserName': raterUserName,
        'ratedUserName': requesterData['name'] ?? 'Solicitante',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calificación enviada con éxito.')),
      );

      // Las Cloud Functions (updateUserRating y sendRatingNotifications)
      // se encargarán automáticamente de:
      // 1. Actualizar el promedio de calificación del solicitante.
      // 2. Enviar la notificación 'rating_received' al solicitante.

      context.go('/'); // Redirige a la pantalla principal
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
        appBar: const CustomAppBar(title: 'Calificar Solicitante'),
        body: FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait([
            _firestore.collection('requests').doc(widget.requestId).get(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || !snapshot.data![0].exists || snapshot.data![0].data() == null) {
              return const Center(child: Text('Solicitud no encontrada o datos incompletos.'));
            }

            final requestData = snapshot.data![0].data() as Map<String, dynamic>;
            final String requesterId = requestData['userId']; // ID del solicitante desde la request

            if (requesterId == null) {
              return const Center(child: Text('Error: No se pudo obtener el ID del solicitante.'));
            }

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(requesterId).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (userSnapshot.hasError) {
                  return Center(child: Text('Error al cargar datos del solicitante: ${userSnapshot.error}'));
                }
                if (!userSnapshot.hasData || !userSnapshot.data!.exists || userSnapshot.data!.data() == null) {
                  return const Center(child: Text('Datos del solicitante no encontrados.'));
                }

                final requesterData = userSnapshot.data!.data() as Map<String, dynamic>;

                final String requesterName = requesterData['name'] ?? 'Solicitante Desconocido';
                final String? requesterPhotoUrl = requesterData['photoUrl'];
                final String requestDescription = requestData['description'] ?? 'Sin descripción.';

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center, // Centra el contenido
                    children: [
                      const SizedBox(height: 20),
                      // Nombre y foto del solicitante
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: requesterPhotoUrl != null && requesterPhotoUrl.isNotEmpty
                            ? NetworkImage(requesterPhotoUrl)
                            : const AssetImage('assets/default_avatar.png') as ImageProvider,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        requesterName,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Estrellas para calificar
                      const Text(
                        'Califica al solicitante:',
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
                      // Botón "Enviar Calificación"
                      ElevatedButton(
                        onPressed: () => _submitRating(requesterData, requestData),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
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
            );
          },
        ),
      ),
    );
  }
}