// Enthält alle Firestore-CRUD-Operationen (Spiel erstellen, joinen, Starten, Spielstatus beobachten, etc.).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telefunken/telefunken/domain/rules/rule_set.dart';

class FirestoreController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Erstelle ein neues Spiel
  Future<String> createGame(String roomName, String hostPlayerName, int playerCount, String ruleSet, int duration, {String? password}) async {
    final gameDoc = await _firestore.collection('games').add({
      'roomName': roomName,
      'host': hostPlayerName,
      'playerCount': playerCount,
      'ruleSet': ruleSet,
      'roundDuration': duration,
      'createdAt': FieldValue.serverTimestamp(),
      'currentPlayer': null,
      'table': [],
      'discardPile': [],
      'isGameStarted': false,
      'password': password, // Optionales Passwort
    });
    return gameDoc.id; // Gibt die Spiel-ID zurück
  }

  // Füge einen Spieler zum Spiel hinzu
  Future<void> addPlayer(String gameId, String playerName) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    final playerRef = gameRef.collection('players').doc(playerName);

    await playerRef.set({
      'name': playerName,
      'hand': [],
      'isAI': false,
      'points': 0,
    });
  }

  // Aktualisiere den Spielstatus
  Future<void> updateGameState(String gameId, Map<String, dynamic> gameState) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    await gameRef.update(gameState);
  }

  // Beobachte Änderungen im Spielstatus
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToGameState(String gameId) {
    final gameRef = _firestore.collection('games').doc(gameId);
    return gameRef.snapshots();
  }

  // Lade die Spieler eines Spiels
  Future<List<Map<String, dynamic>>> getPlayers(String gameId) async {
    final playersSnapshot = await _firestore.collection('games').doc(gameId).collection('players').get();
    return playersSnapshot.docs.map((doc) => doc.data()).toList();
  }
}