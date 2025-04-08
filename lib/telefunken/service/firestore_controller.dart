// Enthält alle Firestore-CRUD-Operationen (Spiel erstellen, joinen, Starten, Spielstatus beobachten, etc.).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telefunken/telefunken/domain/entities/deck.dart';
import 'package:telefunken/telefunken/domain/entities/player.dart';
import 'package:uuid/uuid.dart';

class FirestoreController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Erstelle ein neues Spiel
  Future<String> createGame(
    String roomName,
    String hostPlayerName,
    int maxPlayers,
    String ruleSet,
    int duration, {
    String? password,
  }) async {
    final gameDoc = await _firestore.collection('games').add({
      'room_name': roomName,
      'owner': hostPlayerName,
      'current_players': 0,
      'max_players': maxPlayers,
      'rules': ruleSet,
      'round_duration': duration,
      'created_at': FieldValue.serverTimestamp(),
      'password': password,
      'isGameStarted': false,
      'deck': [],
      'table': [],
      'discardPile': [],
      'currentPlayer': '',
    });

    return gameDoc.id;
  }

  Future<void> startGame(String gameId) async {
    final gameRef = _firestore.collection('games').doc(gameId);

    // Wait until all players have joined
    final gameSnapshot = await gameRef.get();
    final maxPlayers = gameSnapshot.data()?['max_players'] ?? 0;

    List<Map<String, dynamic>> playersData = [];
    while (playersData.length < maxPlayers) {
      playersData = await getPlayers(gameId);
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay to avoid excessive polling
    }

    final players = playersData.map((data) => Player.fromMap(data)).toList();
    players.shuffle();

    final deck = Deck();
    deck.shuffle();

    int playerIndex = 0;
    int cardsToDeal = players.length * 11 + 1;
    for (int i = 0; i < cardsToDeal; i++) {
      final card = deck.dealOne();
      players[playerIndex].addCardToHand(card);
      playerIndex = (playerIndex + 1) % players.length;
    }

    const rankOrder = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
    const suitOrder = ['Joker', 'C', 'D', 'H', 'S'];
    for (var player in players) {
      player.hand.sort((a, b) {
        final rankCompare = rankOrder.indexOf(a.rank).compareTo(rankOrder.indexOf(b.rank));
        if (rankCompare != 0) return rankCompare;
        return suitOrder.indexOf(a.suit).compareTo(suitOrder.indexOf(b.suit));
      });
    }

    for (var player in players) {
      await gameRef.collection('players').doc(player.id).update({
        'hand': player.hand.map((card) => card.toMap()).toList(),
      });
    }

    await gameRef.update({
      'current_players': players.length,
      'deck': deck.cards.map((card) => card.toMap()).toList(),
      'table': [],
      'discardPile': [],
      'currentPlayer': players[0].id,
      'isGameStarted': true,
    });
  }

// Aktualisiere den Spielstatus
  Future<void> updateGameState(String gameId, Map<String, dynamic> gameState) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    await gameRef.update(gameState);
  }

//Deck
  Future<void> resetDeck(String gameId) async {
    final deck = Deck();
    deck.shuffle();
    final gameRef = _firestore.collection('games').doc(gameId);
    await gameRef.collection('deck').doc('deck').set({
      'cards': deck.cards.map((card) => card.toMap()).toList(),
    });
  }

  Future<List<Map<String, dynamic>>> getDeck(String gameId) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    final gameSnapshot = await gameRef.get();
    final deck = gameSnapshot.data()?['deck'] as List<dynamic>?;

    if (deck != null && deck.isNotEmpty) {
      try {
        return deck.map((card) => Map<String, dynamic>.from(card)).toList();
      } catch (e) {
        print('Error processing deck data: $e');
        return [];
      }
    } else {
      print('Deck data is missing or empty in Firestore.');
      return [];
    }
  }

//Spieler
  Future<String> addPlayer(String gameId, String playerName) async {
    final gameRef = _firestore.collection('games').doc(gameId);

    // Spieler zur Liste hinzufügen
    await gameRef.update({
      'current_players': FieldValue.increment(1),
    });

    // Spieler-Details speichern
    final playerId = Uuid().v4();
    final playerRef = gameRef.collection('players').doc(playerId);
    await playerRef.set({
      'id': playerId,
      'name': playerName,
      'hand': [],
      'isAI': false,
      'points': 0,
    });

    return playerId;
  }

  Future<List<Map<String, dynamic>>> getPlayers(String gameId) async {
    final playersSnapshot = await _firestore.collection('games').doc(gameId).collection('players').get();
    return playersSnapshot.docs.map((doc) => doc.data()).toList();
  }

// Beobachte Änderungen im Spielstatus
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToGameState(String gameId) {
    final gameRef = _firestore.collection('games').doc(gameId);
    return gameRef.snapshots();
  }

//stop listening to gamestate
  Future<void> stopListeningToGameState(String gameId) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    await gameRef.snapshots().first;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getGame(String gameId) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    return await gameRef.get();
  }
}