import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/presentation/game/telefunken_game.dart';
import 'package:telefunken/telefunken/presentation/screens/next_round_screen.dart';
import 'package:telefunken/telefunken/service/firestore_controller.dart';
import 'base_screen.dart';
import 'dart:async';

class HostGameScreen extends StatefulWidget {
  const HostGameScreen({super.key});

  @override
  _HostGameScreenState createState() => _HostGameScreenState();
}

class _HostGameScreenState extends State<HostGameScreen> {
  final _formKey = GlobalKey<FormState>();
  StreamSubscription? gameStateSubscription; // Add this to manage the subscription

  // Controller und Variablen
  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Dropdowns
  int _selectedPlayers = 2;
  String _selectedRuleSet = 'Standard';
  String _selectedRoundDuration = '60';

  bool _usePassword = false;

  // Mögliche Werte
  final List<int> _playerOptions = [2, 3, 4];
  final List<String> _ruleSetOptions = ['Standard', 'Pro', 'Fun'];
  final List<String> _roundDurationOptions = ['30', '60', '90', '120']; // in Sekunden

  @override
  void dispose() {
    _playerNameController.dispose();
    _roomNameController.dispose();
    _passwordController.dispose();
    gameStateSubscription?.cancel(); // Cancel the subscription when the widget is disposed
    super.dispose();
  }

  Future<void> _startGame() async {
    if (_formKey.currentState!.validate()) {
      // Eingaben validieren
      String playerName = _playerNameController.text.trim();
      String roomName = _roomNameController.text.trim();
      String? password = _usePassword ? _passwordController.text.trim() : null;
      int maxPlayers = _selectedPlayers;
      String ruleSet = _selectedRuleSet;
      int roundDuration = int.parse(_selectedRoundDuration);

      final firestoreController = FirestoreController();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        String gameId = await firestoreController.createGame(
          roomName,
          playerName,
          maxPlayers,
          ruleSet,
          roundDuration,
          password: password,
        );

        String playerId = await firestoreController.addPlayer(gameId, playerName);

        Navigator.pop(context);

        // Navigiere zur Spieloberfläche
        final game = TelefunkenGame(
          gameId: gameId,
          playerId: playerId,
          playerName: playerName,
          firestoreController: firestoreController,
          onNextRound: (playerNames, roundScores, totalScores) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NextRoundScreen(
                  playerNames: playerNames,
                  roundScores: roundScores,
                  totalScores: totalScores,
                ),
              ),
            );
          },
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              body: GameWidget(game: game),
            ),
          ),
        );

        gameStateSubscription?.cancel();
        gameStateSubscription = firestoreController.listenToGameState(gameId).listen((snapshot) async {
          final data = snapshot.data();
          if (data != null && data['current_players'] == maxPlayers && !data['isGameStarted']) {
            await Future.delayed(const Duration(milliseconds: 500));
            await firestoreController.startGame(gameId);
            await firestoreController.updateGameState(gameId, {
              'isGameStarted': true,
            });
          }
        });
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating game: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      child: Container(
        padding: const EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  "Host a Game",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _playerNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _roomNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a room name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                value: _selectedPlayers,
                decoration: const InputDecoration(
                  labelText: 'Number of Players',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                items: _playerOptions.map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlayers = value ?? _selectedPlayers;
                  });
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedRuleSet,
                decoration: const InputDecoration(
                  labelText: 'Rule Set',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                items: _ruleSetOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRuleSet = value ?? _selectedRuleSet;
                  });
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedRoundDuration,
                decoration: const InputDecoration(
                  labelText: 'Round Duration (sec)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                items: _roundDurationOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRoundDuration = value ?? _selectedRoundDuration;
                  });
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Require Password",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Switch(
                    value: _usePassword,
                    onChanged: (value) {
                      setState(() {
                        _usePassword = value;
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                ],
              ),
              if (_usePassword) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (_usePassword && (value == null || value.trim().isEmpty)) {
                      return 'Please enter a password';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 40),
              Center(
                child: ElevatedButton(
                  onPressed: _startGame,
                  child: const Text("Start Game"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
