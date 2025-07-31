// lib/screens/faq_screen.dart
import 'package:flutter/material.dart';
import '../widgets/custom_background.dart'; // Importa tu widget de fondo
import '../widgets/custom_app_bar.dart';   // Importa tu AppBar personalizada

class FaqScreen extends StatelessWidget {
  const FaqScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      showLogo: true, // Puedes decidir si mostrar el logo aquí
      showAds: false, // Puedes decidir si mostrar publicidad aquí
      child: Scaffold(
        backgroundColor: Colors.transparent, // Permite que el fondo sea visible
        appBar: CustomAppBar(
          title: 'Preguntas Frecuentes',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFaqItem(
                question: '¿Qué es Eslabón?',
                answer: 'Eslabón es una aplicación de ayuda solidaria donde los usuarios pueden publicar solicitudes de ayuda geolocalizadas y otros usuarios pueden ofrecerse como voluntarios para brindar esa ayuda.',
              ),
              _buildFaqItem(
                question: '¿Cómo puedo solicitar ayuda?',
                answer: 'Puedes solicitar ayuda creando una nueva solicitud desde la pantalla principal, describiendo tu necesidad y tu ubicación.',
              ),
              _buildFaqItem(
                question: '¿Cómo puedo ofrecer ayuda?',
                answer: 'Puedes ver las solicitudes activas en el mapa y ofrecer tu ayuda a aquellas que te interesen. Una vez que tu oferta sea aceptada, podrás chatear con el solicitante.',
              ),
              _buildFaqItem(
                question: '¿Cómo funciona el sistema de calificación?',
                answer: 'Después de que una ayuda es aceptada y completada, tanto el solicitante como el ayudador pueden calificarse mutuamente. Estas calificaciones contribuyen a la reputación de cada usuario en el ranking.',
              ),
              _buildFaqItem(
                question: '¿Mis datos de ubicación son públicos?',
                answer: 'Tu ubicación solo se comparte con los usuarios que interactúan directamente con tus solicitudes o a quienes ofreces ayuda, para facilitar la coordinación.',
              ),
              // Añade más preguntas y respuestas según sea necesario
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
            child: Text(
              answer,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}