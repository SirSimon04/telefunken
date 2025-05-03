import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart'; // Ensure CardEntity is imported
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
        'current_players': 0, // Host startet mit 1 Spieler
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
      await resetDeck(gameId);
      await distributeCards(gameId, players);

      gameRef.update({
        'roundNumber': 1,
      });
    } catch (e) {
      print('Error starting game: $e');
      rethrow;
    }
  }

  Future<void> startNewRound(String gameId, String previousWinnerId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      final gameSnapshot = await gameRef.get();
      final gameData = gameSnapshot.data();
      if (gameData == null) {
        print('Error: Game data not found for $gameId');
        return;
      }

      final playersData = await getPlayers(gameId);
      // Ensure players are loaded correctly
      if (playersData.isEmpty) {
        print('Error: No players found for game $gameId');
        return;
      }
      final players = playersData.map((data) => Player.fromMap(data)).toList();
      final currentRound = gameData['roundNumber'] ?? 0;
      final newRoundNumber = currentRound + 1;

      // Determine the starting player for the new round (player after the winner)
      int winnerIndex = players.indexWhere((p) => p.id == previousWinnerId);
      if (winnerIndex == -1) winnerIndex = 0; // Fallback if winner not found
      final startingPlayerIndex = (winnerIndex + 1) % players.length;
      final startingPlayerId = players[startingPlayerIndex].id;

      print('Starting Round $newRoundNumber. Winner was ${players[winnerIndex].name}. Starting player: ${players[startingPlayerIndex].name}');

      // Reset player states in Firestore
      for (var player in players) {
        await updatePlayer(gameId, player.id, {
          'hand': [],
          'hasDrawn': false,
          'isOut': false,
        });
      }

      // Update game state for the new round BEFORE distributing
      await gameRef.update({
        'table': [],
        'discardPile': [], // Will be set by distributeCards
        'roundNumber': newRoundNumber,
        'currentPlayer': startingPlayerId,
        // 'deck' will be updated by distributeCards with the remaining cards
      });

      // Distribute cards using the newly created deck data
      await resetDeck(gameId);
      await distributeCards(gameId, players);

      print("New round setup complete in Firestore for game $gameId.");

    } catch (e) {
      print('Error starting new round: $e');
      rethrow;
    }
  }

  //Distribute cards for a new round
  Future<void> distributeCards(String gameId, List<Player> players) async {
    print("Distributing cards for game $gameId");
    final gameRef = _firestore.collection('games').doc(gameId);

    // Use the provided deck list (already shuffled)
    List<Map<String, dynamic>> currentDeck = await getDeck(gameId);


    if (currentDeck.isEmpty) {
      print('Error: Deck data is missing or empty for distribution.');
      return;
    }

    // Deal 11 cards to each player
    int cardsToDeal = 11;
    for (var player in players) {
        List<Map<String, dynamic>> playerHandData = [];
        for (int i = 0; i < cardsToDeal; i++) {
            if (currentDeck.isNotEmpty) {
                playerHandData.add(currentDeck.removeAt(0)); // Deal from the top
            } else {
                print("Error: Deck ran out of cards during dealing for player ${player.id}.");
                // Decide how to handle this - stop dealing? throw error?
                break;
            }
        }

        // Sort the hand before saving (using CardEntity for robust sorting)
        List<CardEntity> playerHandEntities = playerHandData.map((cardMap) => CardEntity.fromMap(cardMap)).toList();
        const rankOrder = ['Joker', 'Joker1', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
        const suitOrder = ['C', 'D', 'H', 'S']; // Clubs, Diamonds, Hearts, Spades
        playerHandEntities.sort((a, b) {
            final rankCompare = rankOrder.indexOf(a.rank).compareTo(rankOrder.indexOf(b.rank));
            if (rankCompare != 0) return rankCompare;
            // Jokers might not have a suit or have a special one, handle appropriately
            if (a.isJoker() || b.isJoker()) return 0; // Keep Jokers together or define their sort order
            return suitOrder.indexOf(a.suit).compareTo(suitOrder.indexOf(b.suit));
        });

        // Update Firestore hand for the player with sorted map data
        await gameRef.collection('players').doc(player.id).update({
            'hand': playerHandEntities.map((card) => card.toMap()).toList(),
        });
        print("Dealt ${playerHandEntities.length} cards to player ${player.name}");
    }

    await gameRef.update({
      'deck': currentDeck, 
    });
    print("Updated remaining deck (${currentDeck.length} cards) and discard pile in Firestore.");
  }

  //Deck
  Future<List<Map<String, dynamic>>> resetDeck(String gameId) async {
    try {
      final deck = Deck();
      deck.shuffle();
      final deckData = deck.cards.map((card) => card.toMap()).toList();
      final gameRef = _firestore.collection('games').doc(gameId);

      await gameRef.update({'deck': deckData});

      print("Reset and shuffled deck in Firestore for game $gameId. Deck size: ${deckData.length}");
      return deckData; 
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

  // Rundenpunktzahl
  Future<void> updateRoundScores(
    String gameId, int roundNumber, Map<String, int> playerScores) async {
    try {
      await _firestore
          .collection('games')
          .doc(gameId)
          .collection('round_scores')
          .doc(roundNumber.toString())
          .set(playerScores);
    } catch (e) {
      print('Error updating round scores: $e');
    }
  }

  Future<Map<String, int>> getRoundScores(String gameId, int roundNumber) async {
    try {
      final doc = await _firestore
          .collection('games')
          .doc(gameId)
          .collection('round_scores')
          .doc(roundNumber.toString())
          .get();

      if (doc.exists) {
        return Map<String, int>.from(doc.data() as Map<String, dynamic>);
      } else {
        return {};
      }
    } catch (e) {
      print('Error getting round scores: $e');
      return {};
    }
  }
}
