// lib/screens/help_history_screen.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/widgets/custom_app_bar.dart';
import 'package:eslabon_flutter/widgets/spinning_image_loader.dart';

class HelpHistoryScreen extends StatefulWidget {
  const HelpHistoryScreen({super.key});

  @override
  State<HelpHistoryScreen> createState() => _HelpHistoryScreenState();
}

class _HelpHistoryScreenState extends State<HelpHistoryScreen> {
  late final String currentUserId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    currentUserId = user?.uid ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Usuario no autenticado.')),
      );
    }
    
    return CustomBackground(
      showAds: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'history'.tr(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const SizedBox(height: 8),
              TabBar(
                indicatorColor: Colors.amber,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: 'offers_sent'.tr()),   // Ayudas Emitidas
                  Tab(text: 'help_requests'.tr()),  // Solicitudes Publicadas
                ],
                isScrollable: false,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    // Historial como Ayudante (Ofertas enviadas)
                    HelpHistoryAsHelper(userId: currentUserId),
                    // Historial como Solicitante (Solicitudes creadas)
                    HelpHistoryAsRequester(userId: currentUserId),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// WIDGET DE TARJETA ESTILIZADA PARA EL HISTORIAL
// -----------------------------------------------------------
class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String requestId;
  final bool isHelper;

  const _HistoryCard({
    required this.data,
    required this.requestId,
    required this.isHelper,
  });

  String get _status {
    final status = data['estado'] ?? 'activa';
    return status.toUpperCase();
  }
  
  Color get _statusColor {
    switch(_status) {
      case 'ACEPTADA': return Colors.amberAccent;
      case 'FINALIZADA': return Colors.greenAccent;
      case 'EXPIRADA': return Colors.redAccent;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final description = data['titulo'] ?? data['descripcion'] ?? 'Solicitud sin título';
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate()) : 'N/A';
    
    // Obtiene el nombre del partner (solicitante si soy helper, o ayudante si soy solicitante)
    final partnerName = isHelper 
        ? (data['requesterName'] ?? 'Solicitante')
        : (data['acceptedHelperName'] ?? 'Pendiente');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: InkWell(
        onTap: () {
          // Navega a los detalles de la solicitud
          context.pushNamed('request_detail', pathParameters: {'requestId': requestId}, extra: data);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      description,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isHelper ? 'Solicitado por: $partnerName' : 'Ayudante: $partnerName',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                'Publicado: $date',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// -----------------------------------------------------------


// -----------------------------------------------------------
// TAB 1: Historial como ayudante (Ayudas Emitidas)
// -----------------------------------------------------------
class HelpHistoryAsHelper extends StatelessWidget {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  const HelpHistoryAsHelper({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Busca solicitudes donde el ID del usuario está en el campo 'helperId'
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('solicitudes-de-ayuda')
          .where('helperId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: SpinningImageLoader());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('Aún no has participado como ayudante.', style: TextStyle(color: Colors.white70)));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return _HistoryCard(
              data: data,
              requestId: doc.id,
              isHelper: true,
            );
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------
// TAB 2: Historial como solicitante (Solicitudes Publicadas)
// -----------------------------------------------------------
class HelpHistoryAsRequester extends StatelessWidget {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  const HelpHistoryAsRequester({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Busca solicitudes que el usuario creó
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('solicitudes-de-ayuda')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: SpinningImageLoader());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('Aún no has creado solicitudes de ayuda.', style: TextStyle(color: Colors.white70)));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return _HistoryCard(
              data: data,
              requestId: doc.id,
              isHelper: false,
            );
          },
        );
      },
    );
  }
}