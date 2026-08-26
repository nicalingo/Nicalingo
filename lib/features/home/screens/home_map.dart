import 'package:flutter/material.dart';

class HomeMapScreen extends StatelessWidget {
  const HomeMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NicaLingo - Mapa de Niveles'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text('¡Bienvenido al Mapa de Niveles!'),
      ),
    );
  }
}