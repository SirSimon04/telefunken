import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/domain/entities/player.dart';
//import 'package:telefunken/telefunken/domain/rules/rule_set.dart';
import 'package:telefunken/telefunken/presentation/game/telefunken_game.dart';
import 'package:telefunken/telefunken/service/firestore_controller.dart';
import 'package:uuid/uuid.dart';

class PlayOfflineScreen extends StatefulWidget {
  const PlayOfflineScreen({Key? key}) : super(key: key);

  @override
  _PlayOfflineScreenState createState() => _PlayOfflineScreenState();
}

class _PlayOfflineScreenState extends State<PlayOfflineScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controller und Variablen
  final TextEditingController _playerNameController = TextEditingController();
  int _selectedPlayers = 2; // Standardanzahl
  String _selectedRuleSet = 'Standard'; // Beispielregelwerk
  String _selectedRoundDuration = '60'; // Rundendauer in Sekunden

  // Mögliche Werte
  final List<int> _playerOptions = [2, 3, 4];
  final List<String> _ruleSetOptions = ['Standard', 'Pro', 'Fun'];
  final List<String> _roundDurationOptions = ['30', '60', '90', '120']; // in Sekunden

  @override
  void dispose() {
    _playerNameController.dispose();
    super.dispose();
  }

  void _startOfflineGame() {
    if (_formKey.currentState!.validate()) {
      // Alle Eingaben validiert
      String playerName = _playerNameController.text.trim();
      int maxPlayers = _selectedPlayers;
      //String ruleSet = _selectedRuleSet;
      //int roundDuration = int.parse(_selectedRoundDuration);

      // Spieler erstellen
      List<Player> players = List.generate(
        maxPlayers,
        (index) => Player(
          id: Uuid().v4(),
          name: index == 0 ? playerName : 'AI Player ${index + 1}',
          isAI: index != 0,
        ),
      );

      // Regelwerk erstellen
      //RuleSet selectedRuleSet = RuleSet.fromName(ruleSet);


      // GameLogic initialisieren
      final game = TelefunkenGame(
        gameId: '2233123123',
        playerId: '${players[0].id}',
        playerName: playerName,
        firestoreController: FirestoreController(),
      );

      // Navigiere zum TelefunkenGame
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            body: GameWidget(game: game),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play Offline'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Configure Offline Game",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _playerNameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                value: _selectedPlayers,
                decoration: const InputDecoration(
                  labelText: 'Number of Players',
                ),
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
                ),
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
                ),
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
              const SizedBox(height: 40),
              Center(
                child: ElevatedButton(
                  onPressed: _startOfflineGame,
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