import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:telefunken/telefunken/presentation/screens/home/components/menu_buttons.dart';
import 'package:telefunken/telefunken/presentation/screens/next_round_screen.dart';
import 'telefunken/presentation/screens/home/home_screen.dart';
import 'telefunken/presentation/screens/settings_screen.dart';
import 'telefunken/presentation/screens/join_game_screen.dart';
import 'telefunken/presentation/screens/host_game_screen.dart';
import 'telefunken/presentation/screens/play_offline_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'config/firebase_options.dart';
import 'config/navigator_key.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(Provider.value(value: FirebaseFirestore.instance, child: MyApp()));
}

class MyApp extends StatelessWidget {
  static const String homeRoute = '/';
  static const String gameRoute = '/game';
  static const String settingsRoute = '/settings';
  static const String joinRoute = '/join';
  static const String hostRoute = '/host';
  static const String playSingleRoute = '/singlePlayer';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Telefunken',
      initialRoute: homeRoute,
      routes: {
        '/': (context) => Stack(
        children: [
          GameWidget(
            game: HomeScreen(),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: MainMenuButtons(),
          ),
        ],
      ),
        settingsRoute: (context) => SettingsScreen(),
        joinRoute: (context) => JoinGameScreen(),
        hostRoute: (context) => HostGameScreen(),
        playSingleRoute: (context) => PlayOfflineScreen(),
      }
    );
  }
}

