import 'package:flutter/material.dart';

class DetailScreen extends StatelessWidget {
  final int seq;

  const DetailScreen({super.key, required this.seq});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('화장실 상세')),
      body: Center(child: Text('화장실 seq: $seq')),
    );
  }
}
