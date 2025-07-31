// lib/screens/create_request_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';
import '../services/app_services.dart';

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _selectedPriority;
  String? _selectedCategory;
  String? _selectedLocationType;
  String? _selectedProvince;
  String? _selectedCountry;

  bool _isLoadingLocation = false;
  double? _latitude;
  double? _longitude;
  String? _address;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // No es necesario 'late final AppServices _appServices;' aquí
  // ya que showSnackBar es estático y no requiere una instancia.

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _detailsController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        _nameController.text = userData['name'] ?? '';
        _emailController.text = userData['email'] ?? '';
        _phoneController.text = userData['phone'] ?? '';
        setState(() {});
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks.first;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _address = '${place.street}, ${place.locality}, ${place.country}';
      });
      AppServices.showSnackBar(context, 'Ubicación obtenida: $_address', Colors.green);
    } catch (e) {
      AppServices.showSnackBar(context, 'No se pudo obtener la ubicación: $e', Colors.red);
      print('Error al obtener ubicación: $e');
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        AppServices.showSnackBar(context, 'Debes iniciar sesión para crear una solicitud.', Colors.red);
        return;
      }

      if (_selectedLocationType == 'GPS' && (_latitude == null || _longitude == null)) {
        AppServices.showSnackBar(context, 'Por favor, obtén tu ubicación GPS.', Colors.red);
        return;
      }
      if (_selectedLocationType == 'Provincial' && _selectedProvince == null) {
        AppServices.showSnackBar(context, 'Por favor, selecciona una provincia.', Colors.red);
        return;
      }
      if (_selectedLocationType == 'Nacional' && _selectedCountry == null) {
        AppServices.showSnackBar(context, 'Por favor, selecciona un país.', Colors.red);
        return;
      }

      try {
        await _firestore.collection('requests').add({
          'userId': currentUser.uid,
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'description': _descriptionController.text,
          'details': _detailsController.text,
          'priority': _selectedPriority,
          'category': _selectedCategory,
          'locationType': _selectedLocationType,
          'latitude': _latitude,
          'longitude': _longitude,
          'address': _address,
          'province': _selectedProvince,
          'country': _selectedCountry,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'activa',
        });

        AppServices.showSnackBar(context, 'Solicitud creada con éxito.', Colors.green);
        context.pop();
      } catch (e) {
        AppServices.showSnackBar(context, 'Error al crear solicitud: $e', Colors.red);
        print('Error al crear solicitud: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      showLogo: false,
      showAds: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'Crear Solicitud de Ayuda',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Tu Nombre',
                  icon: Icons.person, // ✅ CORREGIDO: Pasando el icono
                  validator: (value) => value!.isEmpty ? 'Ingresa tu nombre' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emailController,
                  labelText: 'Tu Email',
                  icon: Icons.email, // ✅ CORREGIDO: Pasando el icono
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value!.isEmpty || !value.contains('@') ? 'Ingresa un email válido' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Tu Teléfono (opcional)',
                  icon: Icons.phone, // ✅ CORREGIDO: Pasando el icono
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _descriptionController,
                  labelText: 'Descripción Breve de la Ayuda',
                  icon: Icons.short_text, // ✅ CORREGIDO: Pasando el icono
                  maxLines: 3,
                  validator: (value) => value!.isEmpty ? 'Describe la ayuda necesaria' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _detailsController,
                  labelText: 'Detalles Adicionales (opcional)',
                  icon: Icons.notes, // ✅ CORREGIDO: Pasando el icono
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Prioridad de la Solicitud',
                  _selectedPriority,
                  ['Baja', 'Media', 'Alta'],
                  (value) => setState(() => _selectedPriority = value),
                  Icons.priority_high,
                  (value) => value == null ? 'Selecciona una prioridad' : null,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Categoría de Ayuda',
                  _selectedCategory,
                  ['Alimentos', 'Medicamentos', 'Ropa', 'Alojamiento', 'Transporte', 'Otro'],
                  (value) => setState(() => _selectedCategory = value),
                  Icons.category,
                  (value) => value == null ? 'Selecciona una categoría' : null,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Tipo de Ubicación',
                  _selectedLocationType,
                  ['GPS', 'Provincial', 'Nacional', 'Internacional'],
                  (value) => setState(() {
                    _selectedLocationType = value;
                    _latitude = null;
                    _longitude = null;
                    _address = null;
                    _selectedProvince = null;
                    _selectedCountry = null;
                  }),
                  Icons.location_on,
                  (value) => value == null ? 'Selecciona un tipo de ubicación' : null,
                ),
                const SizedBox(height: 16),
                if (_selectedLocationType == 'GPS')
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                        icon: _isLoadingLocation ?
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) :
                              const Icon(Icons.my_location),
                        label: Text(_address ?? 'Obtener Ubicación Actual'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                      if (_address != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Lat: ${_latitude?.toStringAsFixed(6)}, Lon: ${_longitude?.toStringAsFixed(6)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                if (_selectedLocationType == 'Provincial')
                  _buildDropdownField(
                    'Selecciona Provincia',
                    _selectedProvince,
                    ['San Juan', 'Mendoza', 'Córdoba'],
                    (value) => setState(() => _selectedProvince = value),
                    Icons.map,
                    (value) => value == null ? 'Selecciona una provincia' : null,
                  ),
                if (_selectedLocationType == 'Nacional')
                  _buildDropdownField(
                    'Selecciona País',
                    _selectedCountry,
                    ['Argentina', 'Brasil', 'Chile'],
                    (value) => setState(() => _selectedCountry = value),
                    Icons.public,
                    (value) => value == null ? 'Selecciona un país' : null,
                  ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Publicar Solicitud'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String labelText,
    String? currentValue,
    List<String> items,
    ValueChanged<String?> onChanged,
    IconData icon,
    String? Function(String?)? validator,
  ) {
    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: Colors.grey[800],
      style: const TextStyle(color: Colors.white, fontSize: 16),
      iconEnabledColor: Colors.white,
      validator: validator,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}