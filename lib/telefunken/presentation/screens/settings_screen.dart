import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'base_screen.dart';

class SettingsScreen extends StatelessWidget{
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: Text("Hier kommt der Settings Screen", style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }
}