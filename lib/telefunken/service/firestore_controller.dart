import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/domain/entities/deck.dart';
import 'package:telefunken/telefunken/domain/entities/player.dart';
import 'package:uuid/uuid.dart';

class FirestoreController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createGame(
    String roomName,
    String hostPlayerName,
    int maxPlayers,
    String ruleSet,
    int duration, {
    String? password,
    String? hostPlayerId,
  }) async {
    try {
      final gameDoc = await _firestore.collection('games').add({
        'room_name': roomName,
        'owner': hostPlayerName,
        'ownerId': hostPlayerId,
        'current_players': 0,
        'max_players': maxPlayers,
        'rules': ruleSet,
        'round_duration': duration,
        'created_at': FieldValue.serverTimestamp(),
        'password': password,
        'isGameStarted': false,
        'isGameOver': false,
        'deck': [],
        'table': [],
        'discardPile': [],
        'currentPlayer': hostPlayerId,
        'readyPlayers': [],
        'roundNumber': 0,
      });

      return gameDoc.id;
    } catch (e) {
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
      rethrow;
    }
  }

  Future<void> startNewRound(String gameId, String previousWinnerId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      final gameSnapshot = await gameRef.get();
      final gameData = gameSnapshot.data();
      if (gameData == null) {
        return;
      }

      final playersData = await getPlayers(gameId);
      if (playersData.isEmpty) {
        return;
      }
      final players = playersData.map((data) => Player.fromMap(data)).toList();
      final currentRound = gameData['roundNumber'] ?? 0;
      final newRoundNumber = currentRound + 1;

      int winnerIndex = players.indexWhere((p) => p.id == previousWinnerId);
      if (winnerIndex == -1) winnerIndex = 0; // Fallback
      final startingPlayerIndex = (winnerIndex + 1) % players.length;
      final startingPlayerId = players[startingPlayerIndex].id;

      for (var player in players) {
        await updatePlayer(gameId, player.id, {
          'hand': [],
          'hasDrawn': false,
          'isOut': false,
        });
      }

      await gameRef.update({
        'table': [],
        'discardPile': [],
        'roundNumber': newRoundNumber,
        'currentPlayer': startingPlayerId,
      });

      await resetDeck(gameId);
      await distributeCards(gameId, players);

    } catch (e) {
      rethrow;
    }
  }

  Future<void> distributeCards(String gameId, List<Player> players) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    List<Map<String, dynamic>> currentDeck = await getDeck(gameId);

    if (currentDeck.isEmpty) {
      return;
    }

    int cardsToDeal = 11;
    for (var player in players) {
        List<Map<String, dynamic>> playerHandData = [];
        for (int i = 0; i < cardsToDeal; i++) {
            if (currentDeck.isNotEmpty) {
                playerHandData.add(currentDeck.removeAt(0));
            } else {
                break;
            }
        }

        List<CardEntity> playerHandEntities = playerHandData.map((cardMap) => CardEntity.fromMap(cardMap)).toList();
        const rankOrder = ['Joker', 'Joker1', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
        const suitOrder = ['C', 'D', 'H', 'S'];
        playerHandEntities.sort((a, b) {
            final rankCompare = rankOrder.indexOf(a.rank).compareTo(rankOrder.indexOf(b.rank));
            if (rankCompare != 0) return rankCompare;
            if (a.isJoker() || b.isJoker()) return 0;
            return suitOrder.indexOf(a.suit).compareTo(suitOrder.indexOf(b.suit));
        });

        await gameRef.collection('players').doc(player.id).update({
            'hand': playerHandEntities.map((card) => card.toMap()).toList(),
        });
    }

    await gameRef.update({
      'deck': currentDeck,
    });
  }

  Future<List<Map<String, dynamic>>> resetDeck(String gameId) async {
    try {
      final deck = Deck();
      deck.shuffle();
      final deckData = deck.cards.map((card) => card.toMap()).toList();
      final gameRef = _firestore.collection('games').doc(gameId);

      await gameRef.update({'deck': deckData});
      return deckData;
    } catch (e) {
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
        return [];
      }
    } catch (e) {
      return [];
    }
  }

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
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPlayers(String gameId) async {
    try {
      final playersSnapshot = await _firestore.collection('games').doc(gameId).collection('players').get();
      return playersSnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
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
      rethrow;
    }
  }

  Future<void> updatePlayerHand(String gameId, String playerId, List<Map<String, dynamic>> hand) async {
    try {
      final playerRef = _firestore.collection('games').doc(gameId).collection('players').doc(playerId);
      await playerRef.update({'hand': hand});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePlayerPoints(String gameId, String playerId, int points) async {
    try {
      final playerRef = _firestore.collection('games').doc(gameId).collection('players').doc(playerId);
      await playerRef.update({'points': points});
    } catch (e) {
      rethrow;
    }
  }

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
          .doc();

      await drawEventsRef.set({
        'gameId': gameId,
        'playerId': playerId,
        'card': card,
        'source': source,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
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
      rethrow;
    }
  }

  Future<void> updateGameState(String gameId, Map<String, dynamic> gameState) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      await gameRef.update(gameState);
    } catch (e) {
      rethrow;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getGame(String gameId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      return await gameRef.get();
    } catch (e) {
      rethrow;
    }
  }

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
      rethrow;
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
      return {};
    }
  }

  Future<void> markPlayerReadyForRematch(String gameId, String playerId) async {
    final gameRef = _firestore.collection('games').doc(gameId);

    try {
      await _firestore.runTransaction((transaction) async {
        final gameSnapshot = await transaction.get(gameRef);
        if (!gameSnapshot.exists) {
          throw Exception("Game does not exist!");
        }
        final gameData = gameSnapshot.data()!;
        final maxPlayers = gameData['max_players'] as int;
        List<dynamic> readyPlayers = List.from(gameData['readyPlayers'] ?? []);

        if (!readyPlayers.contains(playerId)) {
          readyPlayers.add(playerId);
          transaction.update(gameRef, {
            'readyPlayers': readyPlayers,
          });

          if (readyPlayers.length == maxPlayers) {
            // Call resetGameForRematch within the transaction
            await resetGameForRematch(gameId, transaction: transaction);
          }
        }
      });

    } catch (e) {
      rethrow;
    }
  }

  // Added optional transaction parameter
  Future<void> resetGameForRematch(String gameId, {Transaction? transaction}) async {
    final gameRef = _firestore.collection('games').doc(gameId);

    try {
       DocumentSnapshot<Map<String, dynamic>> gameSnapshot;
       if (transaction != null) {
         gameSnapshot = await transaction.get(gameRef);
       } else {
         gameSnapshot = await gameRef.get();
       }

       final gameData = gameSnapshot.data();
       if (gameData == null) {
         return;
       }
       final String originalOwnerId = gameData['ownerId'] ?? '';

      final updates = {
        'roundNumber': 1,
        'isGameOver': false,
        'winner': null,
        'table': [],
        'discardPile': [],
        'readyPlayers': [],
        'currentPlayer': originalOwnerId,
      };

      if (transaction != null) {
        transaction.update(gameRef, updates);
      } else {
        await gameRef.update(updates);
      }

      final playersSnapshot = await gameRef.collection('players').get();
      for (var playerDoc in playersSnapshot.docs) {
        final playerUpdates = {
          'points': 0,
          'hand': [],
          'isOut': false,
          'hasDrawn': false,
        };
        if (transaction != null) {
          transaction.update(playerDoc.reference, playerUpdates);
        } else {
          await playerDoc.reference.update(playerUpdates);
        }
      }

      if (transaction == null) {
         await resetDeck(gameId);
         final playersData = await getPlayers(gameId);
         final players = playersData.map((data) => Player.fromMap(data)).toList();
         await distributeCards(gameId, players);
      }


    } catch (e) {
      rethrow;
    }
  }
}
