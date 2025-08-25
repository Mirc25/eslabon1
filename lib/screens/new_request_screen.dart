import 'package:flutter/material.dart';

class NewRequestScreen extends StatelessWidget {
  const NewRequestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nueva solicitud")),
      body: const Center(child: Text("Pantalla para crear solicitud de ayuda")),
    );
  }
}
