import 'package:flutter/material.dart';

class Jamur extends StatelessWidget {
  const Jamur({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jamur')),
      body: const Center(child: Text('Welcome to Jamur page!')),
    );
  }
}
