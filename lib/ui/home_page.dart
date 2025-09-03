import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Pantalla Home'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => context.go('/login'), child: const Text('Ir a Login')),
          const SizedBox(height: 8),
          TextButton(onPressed: () => context.go('/register'), child: const Text('Crear cuenta')),
        ]),
      ),
    );
  }
}
