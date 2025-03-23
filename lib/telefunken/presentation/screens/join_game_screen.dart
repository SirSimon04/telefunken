import 'package:flutter/foundation.dart'; // Für kDebugMode
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_screen.dart';

class JoinGameScreen extends StatelessWidget {
  const JoinGameScreen({Key? key}) : super(key: key);

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
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: kDebugMode ? _buildMockList() : _buildFirestoreList(),
            ),
          ),
        ],
      ),
    );
  }

  /// **Firestore-Daten (Produktiv-Modus)**
  Widget _buildFirestoreList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('hosted_games').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Fehler beim Laden der Spiele!", style: TextStyle(color: Colors.white)));
        }
        
        var games = snapshot.data?.docs ?? [];

        if (games.isEmpty) {
          return const Center(
            child: Text("Keine Spiele gefunden", style: TextStyle(color: Colors.white, fontSize: 18)),
          );
        }

        return _buildGameList(games.map((doc) => doc.data() as Map<String, dynamic>).toList());
      },
    );
  }

  /// **Mock-Daten für Debug-Modus**
  Widget _buildMockList() {
    List<Map<String, dynamic>> mockGames = [
      {
        "room_name": "Poker Night",
        "current_players": 3,
        "max_players": 6,
        "rules": "Texas Hold'em",
        "password": null,
        "id": "1"
      },
      {
        "room_name": "Mafia Game",
        "current_players": 4,
        "max_players": 10,
        "rules": "Classic",
        "password": "secret",
        "id": "2"
      }
    ];

    return _buildGameList(mockGames);
  }

  /// **Gemeinsame Methode zum Bauen der Game-Liste**
  Widget _buildGameList(List<Map<String, dynamic>> games) {
    return Scrollbar(
      thickness: 6,
      radius: const Radius.circular(10),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: games.length,
        separatorBuilder: (context, index) => const Divider(color: Colors.grey),
        itemBuilder: (context, index) {
          var game = games[index];
          return ListTile(
            title: Text(game['room_name'], style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              "${game['current_players']}/${game['max_players']} Players • ${game['rules']}",
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: Icon(
              game['password'] != null ? Icons.lock : Icons.lock_open,
              color: Colors.white,
            ),
            onTap: () {
              _showJoinGameDialog(
                context,
                game['id'],
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

  void _showJoinGameDialog(BuildContext context, String roomId, String roomName, bool requiresPassword, String? correctPassword) {
    final TextEditingController playerNameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Join $roomName"),
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
                    const SnackBar(content: Text("Bitte gib deinen Namen ein!")),
                  );
                  return;
                }

                if (requiresPassword && enteredPassword != correctPassword) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Falsches Passwort!")),
                  );
                  return;
                }

                await _joinGame(roomId, playerName);
                Navigator.pop(context);
              },
              child: const Text("Join Game"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _joinGame(String roomId, String playerName) async {
    final roomRef = FirebaseFirestore.instance.collection('hosted_games').doc(roomId);

    await roomRef.update({
      'players': FieldValue.arrayUnion([playerName])
    });
  }
}
