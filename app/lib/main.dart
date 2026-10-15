import 'package:flutter/material.dart';

void main() {
  runApp(const FramixApp());
}

/// Root widget. Screens arrive with ENG-001 (routing) and ENG-003 (engine state).
class FramixApp extends StatelessWidget {
  const FramixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Scaffold());
  }
}
