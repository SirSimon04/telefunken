import 'package:flutter/material.dart';
import 'package:telefunken/main.dart';

class MainMenuOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          bottom: 100, // Abstand vom unteren Rand
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, MyApp.joinRoute),
                child: Text("Join Game"),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, MyApp.hostRoute),
                child: Text("Host Game"),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, MyApp.playOfflineRoute),
                child: Text("Play Offline"),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, MyApp.settingsRoute),
                child: Text("Settings"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
