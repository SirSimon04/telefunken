import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/game.dart';
import 'package:telefunken/telefunken/presentation/game/telefunken_game.dart';
import 'package:telefunken/telefunken/service/firestore_controller.dart';
import 'base_screen.dart';

class JoinGameScreen extends StatelessWidget {
  JoinGameScreen({Key? key}) : super(key: key);
  final ScrollController _scrollController = ScrollController();

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

        //outsource games that already finished
        games = games.where((doc) {
          var gameData = doc.data() as Map<String, dynamic>;
          return gameData['isGameOver'] != true;
        }).toList();

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

  void _showJoinGameDialog(BuildContext context, String roomId, String room_name, bool requiresPassword, String? correctPassword) async {
    final TextEditingController playerNameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    // Suche die aktuellen Spielernamen aus der Firestore-Datenbank
    final firestoreController = FirestoreController();
    final players = await firestoreController.getPlayers(roomId);

    showDialog(
      context: context,
      builder: (dialogContext) => ScaffoldMessenger(
        child: Builder(
          builder: (scaffoldContext) => Scaffold( // Use another context name
            backgroundColor: Colors.transparent, // Make scaffold background transparent
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(), // Use dialogContext to pop
              child: GestureDetector(
                onTap: () {}, // Prevent taps inside the dialog from closing it
                child: AlertDialog(
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
                      onPressed: () => Navigator.pop(dialogContext), // Use dialogContext
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        String playerName = playerNameController.text.trim();
                        String enteredPassword = passwordController.text.trim();

                        if (playerName.isEmpty) {
                          ScaffoldMessenger.of(scaffoldContext).showSnackBar( // Use scaffoldContext
                            const SnackBar(content: Text("Please enter your name!")),
                          );
                          return;
                        }

                        //check if player name is already taken
                        for (var player in players) {
                          if (player['name'] == playerName) {
                            ScaffoldMessenger.of(scaffoldContext).showSnackBar( // Use scaffoldContext
                              const SnackBar(content: Text("Player name already taken!")),
                            );
                            return;
                          }
                        }

                        if (requiresPassword && enteredPassword != correctPassword) {
                          ScaffoldMessenger.of(scaffoldContext).showSnackBar( // Use scaffoldContext
                            const SnackBar(content: Text("Incorrect password!")),
                          );
                          return;
                        }
                        // Close the dialog before navigating
                        Navigator.pop(dialogContext);
                        // Use the original context for navigation and joining game
                        await _joinGame(context, roomId, playerName);
                      },
                      child: const Text("Join Game"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _joinGame(BuildContext context, String roomId, String playerName) async {
    final firestoreController = FirestoreController();

    // Spieler dem Spiel hinzufügen
    String playerId = await firestoreController.addPlayer(roomId, playerName);

    // Lade Spielinformationen aus Firestore
    final gameSnapshot = await FirebaseFirestore.instance.collection('games').doc(roomId).get();
    if (!gameSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Game not found!")),
      );
      return;
    }

    // Spiel starten
    final game = TelefunkenGame(
      gameId: roomId,
      playerId: playerId,
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
