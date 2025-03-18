import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:telefunken/home/components/menu_buttons.dart';
import 'package:telefunken/home/main_menu_overlay.dart';
import 'screens/home_screen.dart';
import 'screens/game_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/join_game_screen.dart';
import 'screens/host_game_screen.dart';
import 'screens/play_offline_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static const String homeRoute = '/';
  static const String gameRoute = '/game';
  static const String settingsRoute = '/settings';
  static const String joinRoute = '/join';
  static const String hostRoute = '/host';
  static const String playOfflineRoute = '/offline';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telefunken',
      initialRoute: homeRoute,
      routes: {
        '/': (context) => Stack(
        children: [
          GameWidget(game: HomeScreen()),   // 🔹 Das Spiel
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: MainMenuButtons(),  // 🔹 Die Buttons aus der separaten Klasse!
          ),
        ],
      ),
        //gameRoute: (context) => GameScreen(),
        settingsRoute: (context) => SettingsScreen(),
        joinRoute: (context) => JoinGameScreen(),
        hostRoute: (context) => HostGameScreen(),
        playOfflineRoute: (context) => PlayOfflineScreen(),
      }
    );
  }
}

