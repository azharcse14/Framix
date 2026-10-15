import 'package:flutter/widgets.dart';

void main() {
  runApp(const FramixApp());
}

/// Root widget. The app shell (theme, localization, routing) arrives with ENG-001/ENG-003.
class FramixApp extends StatelessWidget {
  const FramixApp({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
