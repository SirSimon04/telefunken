import 'package:flutter/material.dart';

/// BaseScreen ist ein StatefulWidget, das einen gemeinsamen Hintergrund 
/// und einen Back-Button implementiert.
/// Der eigentliche Inhalt wird als Widget übergeben.
class BaseScreen extends StatelessWidget {
  final Widget child;
  final bool showBackButton;

  const BaseScreen({
    Key? key,
    required this.child,
    this.showBackButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Option: wenn du keinen AppBar nutzen möchtest, kannst du den BackButton auch
      // manuell im Stack platzieren.
      body: Stack(
        children: [
          // Gemeinsamer Hintergrund
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Gemeinsamer Back-Button
          //Der button soll immer im Vordergrund sein
          if (showBackButton)
            Positioned(
              top: 40,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 30, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          // Inhalt des jeweiligen Screens
          child,
        ],
      ),
    );
  }
}
