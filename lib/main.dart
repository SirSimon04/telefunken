import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    GameWidget(
      game: HomeScreen(),
    ),
  );
}
