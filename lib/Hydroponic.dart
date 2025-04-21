import 'package:flutter/material.dart';

class Hydroponic extends StatelessWidget {
  const Hydroponic({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hydroponic')),
      body: const Center(child: Text('Welcome to Hydroponic page')),
    );
  }
}
