import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/presentation/screens/base_screen.dart';
import 'package:telefunken/telefunken/presentation/screens/game_screen.dart';
import '../game/telefunken_game.dart';
import '../../domain/entities/player.dart';
import '../../domain/rules/standard_rule_set.dart';

class PlayOfflineScreen extends StatefulWidget {
  const PlayOfflineScreen({super.key});

  @override
  _PlayOfflineScreenState createState() => _PlayOfflineScreenState();
}

class _PlayOfflineScreenState extends State<PlayOfflineScreen> {
  int _numPlayers = 2;
  int _numAIPlayers = 0;
  Duration _roundDuration = Duration(seconds: 30);
  String _selectedRuleSet = 'Standard';

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Singleplayer Spielmodus", style: TextStyle(color: Colors.white, fontSize: 24)),
            SizedBox(height: 20),
            Text("Anzahl der Spieler:", style: TextStyle(color: Colors.white)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPlayerButton(2),
                _buildPlayerButton(3),
                _buildPlayerButton(4),
              ],
            ),
            SizedBox(height: 20),
            Text("Anzahl der KI-Spieler:", style: TextStyle(color: Colors.white)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_numPlayers, (index) => _buildAIPlayerButton(index)),
            ),
            SizedBox(height: 20),
            Text("Rundendauer:", style: TextStyle(color: Colors.white)),
            DropdownButton<Duration>(
              value: _roundDuration,
              dropdownColor: Colors.black,
              items: [
                DropdownMenuItem(
                  value: Duration(seconds: 30),
                  child: Text("30 Sekunden", style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: Duration(seconds: 60),
                  child: Text("60 Sekunden", style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: Duration(seconds: 90),
                  child: Text("90 Sekunden", style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _roundDuration = value!;
                });
              },
            ),
            SizedBox(height: 20),
            Text("Regelwerk:", style: TextStyle(color: Colors.white)),
            DropdownButton<String>(
              value: _selectedRuleSet,
              dropdownColor: Colors.black,
              items: [
                DropdownMenuItem(
                  value: 'Standard',
                  child: Text("Standard", style: TextStyle(color: Colors.white)),
                ),
                // Weitere Regelwerke hier hinzufügen
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRuleSet = value!;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startGame,
              child: Text("Spiel starten"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerButton(int numPlayers) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _numPlayers = numPlayers;
          _numAIPlayers = 0; // Reset AI players when changing number of players
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _numPlayers == numPlayers ? Colors.blue : Colors.grey,
      ),
      child: Text("$numPlayers"),
    );
  }

  Widget _buildAIPlayerButton(int numAIPlayers) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _numAIPlayers = numAIPlayers;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _numAIPlayers == numAIPlayers ? Colors.blue : Colors.grey,
      ),
      child: Text("$numAIPlayers"),
    );
  }

  void _startGame() {
    //generate AI Agents for the amount of aiPlayers
    List<Player> aiPlayers = List.generate(_numAIPlayers, (index) => Player(name: 'AI Player ${index + 1}', id: _numPlayers + index, isAI: true));

    //add the human players
    List<Player> players = List.generate(_numPlayers - 1, (index) => Player(name: 'Player ${index + 2}', id: index + 1));

    players.add(Player(name: 'You', id: 0));
    //add the AI players to the players list
    players.addAll(aiPlayers);

    TelefunkenGame telefunkengame = TelefunkenGame(
      playerName: 'You',
      playerCount: players.length,
      roundDuration: _roundDuration,
      ruleSet: StandardRuleSet(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(game: telefunkengame),
      ),
    );

    //Join game sollte später durch den Firebase Controller aufgerufen werden und in gamelogic implementiert werden
    Future.forEach(players, (Player player) async {
      await Future.delayed(Duration(seconds: (1)));
      telefunkengame.joinGame(player);
    });

  }
}