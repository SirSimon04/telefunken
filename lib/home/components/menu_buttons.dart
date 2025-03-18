import 'package:flutter/material.dart';

class MainMenuButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/join'),
          child: Text("Join Game"),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/host'),
          child: Text("Host Game"),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/offline'),
          child: Text("Play Offline"),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          child: Text("Settings"),
        ),
      ],
    );
  }
}
