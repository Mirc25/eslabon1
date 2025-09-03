import 'package:flutter/material.dart';

class MyOffersScreen extends StatelessWidget {
  const MyOffersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis ofertas")),
      body: const Center(child: Text("Pantalla de ofertas enviadas")),
    );
  }
}

