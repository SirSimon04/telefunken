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
    try {
      final gameDoc = await _firestore.collection('games').add({
        'room_name': roomName,
        'owner': hostPlayerName,
        'current_players': 0,  // Host startet mit 1 Spieler
        'max_players': maxPlayers,
        'rules': ruleSet,
        'round_duration': duration,
        'created_at': FieldValue.serverTimestamp(),
        'password': password,
        'isGameStarted': false,
        'deck': [],
        'table': [],
        'discardPile': [],
        'currentPlayer': hostPlayerName,
      });

      return gameDoc.id;
    } catch (e) {
      print('Error creating game: $e');
      rethrow;
    }
  }

  Future<void> startGame(String gameId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      final gameSnapshot = await gameRef.get();
      final maxPlayers = gameSnapshot.data()?['max_players'] ?? 0;

      List<Map<String, dynamic>> playersData = [];
      while (playersData.length < maxPlayers) {
        playersData = await getPlayers(gameId);
        await Future.delayed(const Duration(milliseconds: 500));
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

      const rankOrder = ['Joker' 'Joker1', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
      const suitOrder = ['C', 'D', 'H', 'S'];
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
        'roundNumber': 1,
      });
    } catch (e) {
      print('Error starting game: $e');
      rethrow;
    }
  }

//Deck
  Future<void> resetDeck(String gameId) async {
    try {
      final deck = Deck();
      deck.shuffle();
      final gameRef = _firestore.collection('games').doc(gameId);
      await gameRef.collection('deck').doc('deck').set({
        'cards': deck.cards.map((card) => card.toMap()).toList(),
      });
    } catch (e) {
      print('Error resetting deck: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getDeck(String gameId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      final gameSnapshot = await gameRef.get();
      final deck = gameSnapshot.data()?['deck'] as List<dynamic>?;
      if (deck != null && deck.isNotEmpty) {
        return deck.map((card) => Map<String, dynamic>.from(card)).toList();
      } else {
        print('Deck data is missing or empty.');
        return [];
      }
    } catch (e) {
      print('Error fetching deck: $e');
      return [];
    }
  }

//Spieler
  Future<String> addPlayer(String gameId, String playerName) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      final playerId = Uuid().v4();

      await gameRef.update({
        'current_players': FieldValue.increment(1),
      });

      final playerRef = gameRef.collection('players').doc(playerId);
      await playerRef.set({
        'id': playerId,
        'name': playerName,
        'hand': [],
        'isAI': false,
        'coins': 7,
        'points': 0,
      });

      return playerId;
    } catch (e) {
      print('Error adding player: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPlayers(String gameId) async {
    try {
      final playersSnapshot = await _firestore.collection('games').doc(gameId).collection('players').get();
      return playersSnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching players: $e');
      return [];
    }
  }

  Future<void> removePlayer(String gameId, String playerId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      final playerRef = gameRef.collection('players').doc(playerId);

      await gameRef.update({
        'current_players': FieldValue.increment(-1),
      });

      await playerRef.delete();
    } catch (e) {
      print('Error removing player: $e');
      rethrow;
    }
  }

  Future<void> updatePlayerHand(String gameId, String playerId, List<Map<String, dynamic>> hand) async {
    try {
      final playerRef = _firestore.collection('games').doc(gameId).collection('players').doc(playerId);
      await playerRef.update({'hand': hand});
    } catch (e) {
      print('Error updating player hand: $e');
      rethrow;
    }
  }

  Future<void> updatePlayerPoints(String gameId, String playerId, int points) async {
    try {
      final playerRef = _firestore.collection('games').doc(gameId).collection('players').doc(playerId);
      await playerRef.update({'points': points});
    } catch (e) {
      print('Error updating player points: $e');
      rethrow;
    }
  }

  // Beobachte Änderungen im Spielstatus
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToGameState(String gameId) {
    final gameRef = _firestore.collection('games').doc(gameId);
    return gameRef.snapshots();
  }  
  
  Stream<List<Map<String, dynamic>>> listenToPlayersUpdate(String gameId) {
    final playersRef = _firestore.collection('games').doc(gameId).collection('players');
    return playersRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }
  
  Future<void> createDrawEvent(
      String gameId, String playerId, Map<String, dynamic> card, String source) async {
    try {
      final drawEventsRef = _firestore
          .collection('games')
          .doc(gameId)
          .collection('draw_events')
          .doc(); // Auto-ID für jedes Event

      await drawEventsRef.set({
        'gameId': gameId,
        'playerId': playerId,
        'card': card,
        'source': source,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating draw event: $e');
      rethrow;
    }
  }

  Stream<Map<String, dynamic>?> listenToCardDraw(String gameId) {
    return _firestore
        .collection('games')
        .doc(gameId)
        .collection('draw_events')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      } else {
        return null;
      }
    });
  }


  Future<void> updatePlayer(String gameId, String playerId, Map<String, dynamic> playerData) async {
    try {
      final playerRef = _firestore.collection('games').doc(gameId).collection('players').doc(playerId);
      await playerRef.update(playerData);
    } catch (e) {
      print('Error updating player: $e');
      rethrow;
    }
  }
  
  // Spielstatus aktualisieren
  Future<void> updateGameState(String gameId, Map<String, dynamic> gameState) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      await gameRef.update(gameState);
    } catch (e) {
      print('Error updating game state: $e');
      rethrow;
    }
  }

  // Hole das komplette Spiel-Dokument
  Future<DocumentSnapshot<Map<String, dynamic>>> getGame(String gameId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      return await gameRef.get();
    } catch (e) {
      print('Error fetching game: $e');
      rethrow;
    }
  }
}
