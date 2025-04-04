import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/game.dart';
import 'package:telefunken/telefunken/domain/entities/player.dart';
import 'package:telefunken/telefunken/domain/logic/game_logic.dart';
import 'package:telefunken/telefunken/domain/rules/rule_set.dart';
import 'package:telefunken/telefunken/presentation/game/telefunken_game.dart';
import 'package:telefunken/telefunken/service/firestore_controller.dart';
import 'base_screen.dart';

class JoinGameScreen extends StatelessWidget {
  JoinGameScreen({Key? key}) : super(key: key);
  ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 60, bottom: 20),
            child: Text(
              "Join a Game",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _buildFirestoreList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirestoreList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('games').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading games!", style: TextStyle(color: Colors.white)));
        }

        var games = snapshot.data?.docs ?? [];

        if (games.isEmpty) {
          return const Center(
            child: Text("No games found", style: TextStyle(color: Colors.white, fontSize: 18)),
          );
        }

        return _buildGameList(snapshot, games.map((doc) => doc.data() as Map<String, dynamic>).toList());
      },
    );
  }

  Widget _buildGameList(AsyncSnapshot<QuerySnapshot> snapshot, List<Map<String, dynamic>> games) {
    return Scrollbar(
      controller: _scrollController,
      thickness: 6,
      thumbVisibility: true,
      radius: const Radius.circular(10),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: games.length,
        separatorBuilder: (context, index) => const Divider(
          color: Colors.grey,
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          var game = games[index];
          return ListTile(
            title: Text(game['room_name'], style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              "${game['current_players']}/${game['max_players']} Players • ${game['rules']} • ${game['owner']}",
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: Icon(
              game['password'] != null ? Icons.lock : Icons.lock_open,
              color: Colors.white,
            ),
            onTap: () {
              if(game['current_players'] >= game['max_players']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Game is full!")),
                );
                return;
              } 

              _showJoinGameDialog(
                context,
                snapshot.data!.docs[index].id,
                game['room_name'],
                game['password'] != null,
                game['password'],
              );
            },
          );
        },
      ),
    );
  }

  void _showJoinGameDialog(BuildContext context, String roomId, String room_name, bool requiresPassword, String? correctPassword) {
    final TextEditingController playerNameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Join $room_name"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: playerNameController,
                decoration: const InputDecoration(labelText: "Player Name"),
              ),
              const SizedBox(height: 10),
              if (requiresPassword)
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: "Password"),
                  obscureText: true,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                String playerName = playerNameController.text.trim();
                String enteredPassword = passwordController.text.trim();

                if (playerName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter your name!")),
                  );
                  return;
                }

                if (requiresPassword && enteredPassword != correctPassword) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Incorrect password!")),
                  );
                  return;
                }

                await _joinGame(context, roomId, playerName);
              },
              child: const Text("Join Game"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _joinGame(BuildContext context, String roomId, String playerName) async {
    final firestoreController = FirestoreController();

    // Spieler dem Spiel hinzufügen
    await firestoreController.addPlayer(roomId, playerName);

    // Lade Spielinformationen aus Firestore
    final gameSnapshot = await FirebaseFirestore.instance.collection('games').doc(roomId).get();
    if (!gameSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Game not found!")),
      );
      return;
    }

    // Spieler aus Firestore laden
    final playersSnapshot = await FirebaseFirestore.instance
        .collection('games')
        .doc(roomId)
        .collection('players')
        .get();

    // Spiel starten
    final game = TelefunkenGame(
      gameId: roomId,
      playerName: playerName,
      firestoreController: firestoreController,
    );

    // Navigiere zur Spielansicht
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
