// lib/screens/terms_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'terms_and_conditions'.tr(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título y Jurisdicción
              Text(
                'terminos_de_uso_titulo'.tr(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'jurisdiccion_titulo'.tr(),
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                'ultima_actualizacion'.tr(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Aceptación del Contrato
              _buildSectionTitle('aceptacion_contrato_titulo'.tr()),
              Text(
                'aceptacion_contrato_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Identificación de las Partes
              _buildSectionTitle('identificacion_partes_titulo'.tr()),
              Text(
                'prestador_servicio'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'usuario_def'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Objeto de la Aplicación
              _buildSectionTitle('objeto_app_titulo'.tr()),
              Text(
                'objeto_app_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              _buildBulletedList([
                'objeto_app_lista_1'.tr(),
                'objeto_app_lista_2'.tr(),
                'objeto_app_lista_3'.tr(),
                'objeto_app_lista_4'.tr(),
              ]),
              Text(
                'sin_relacion_laboral'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Requisitos de Registro
              _buildSectionTitle('requisitos_registro_titulo'.tr()),
              Text(
                'registro_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              _buildBulletedList([
                'registro_lista_1'.tr(),
                'registro_lista_2'.tr(),
                'registro_lista_3'.tr(),
              ]),
              Text(
                'suspension_cuenta'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Contratos Digitales
              _buildSectionTitle('contratos_digitales_titulo'.tr()),
              Text(
                'contratos_digitales_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Obligaciones del Usuario
              _buildSectionTitle('obligaciones_usuario_titulo'.tr()),
              _buildBulletedList([
                'obligaciones_usuario_lista_1'.tr(),
                'obligaciones_usuario_lista_2'.tr(),
                'obligaciones_usuario_lista_3'.tr(),
                'obligaciones_usuario_lista_4'.tr(),
              ]),
              const SizedBox(height: 16),

              // Geolocalización
              _buildSectionTitle('geolocalizacion_titulo'.tr()),
              Text(
                'geolocalizacion_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              _buildBulletedList([
                'geolocalizacion_lista_1'.tr(),
                'geolocalizacion_lista_2'.tr(),
              ]),
              Text(
                'datos_ubicacion_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              
              // Sistema de Calificaciones y Ranking
              _buildSectionTitle('calificaciones_ranking_titulo'.tr()),
              Text(
                'calificaciones_ranking_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              Text(
                'ocultar_calificaciones'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              Text(
                'no_calificaciones_falsas'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Exención de Responsabilidad
              _buildSectionTitle('exencion_responsabilidad_titulo'.tr()),
              Text(
                'sin_control_ayudas'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              _buildBulletedList([
                'no_responsable_ilicitos'.tr(),
                'asumir_responsabilidad'.tr(),
                'recomendaciones_seguridad'.tr(),
              ]),
              const SizedBox(height: 16),
              
              // Exposición de Datos
              _buildSectionTitle('exposicion_datos_titulo'.tr()),
              Text(
                'datos_visibles_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              _buildBulletedList([
                'datos_no_revelados'.tr(),
                'no_responsable_uso_indebido'.tr(),
              ]),
              const SizedBox(height: 16),

              // Prohibición de Contacto con Menores
              _buildSectionTitle('prohibicion_menores_titulo'.tr()),
              _buildBulletedList([
                'prohibicion_menores_lista_1'.tr(),
                'prohibicion_menores_lista_2'.tr(),
                'prohibicion_menores_lista_3'.tr(),
              ]),
              Text(
                'consecuencias_prohibicion'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              Text(
                'colaboracion_justicia'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Protección de Datos Personales
              _buildSectionTitle('proteccion_datos_titulo'.tr()),
              Text(
                'ley_datos_personales'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              Text(
                'derechos_usuario'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              Text(
                'base_datos_registrada'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              Text(
                'datos_necesarios_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Seguridad de la Información
              _buildSectionTitle('seguridad_informacion_titulo'.tr()),
              Text(
                'seguridad_informacion_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Propiedad Intelectual
              _buildSectionTitle('propiedad_intelectual_titulo'.tr()),
              Text(
                'propiedad_intelectual_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Cambios en los Términos
              _buildSectionTitle('cambios_terminos_titulo'.tr()),
              Text(
                'cambios_terminos_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Jurisdicción Final
              _buildSectionTitle('jurisdiccion_final_titulo'.tr()),
              Text(
                'jurisdiccion_final_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Referencias Globales
              _buildSectionTitle('referencias_globales_titulo'.tr()),
              Text(
                'referencias_globales_texto'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'fin_documento'.tr(),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBulletedList(List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 16, color: Colors.white70)),
                Expanded(
                  child: Text(item, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}