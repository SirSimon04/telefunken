import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/config/navigator_key.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/service/firestore_controller.dart';

import '../entities/deck.dart';
import '../entities/player.dart';
import '../rules/rule_set.dart';

class GameLogic {
  final String gameId;
  final FirestoreController firestoreController;

  late List<Player> players = [];
  late int maxPlayers;
  late RuleSet ruleSet;
  late Deck deck = Deck();
  final List<List<CardEntity>> table = [];
  final List<CardEntity> discardPile = [];

  late int currentPlayerIndex = 0;
  late int roundNumber;
  late List<List<CardEntity>> currentMoves = [];
  late bool paused = false;
  late bool gameOver = false;
  late bool hasDrawnCard = false;
  VoidCallback? onNextRoundStarted;

  GameLogic({
    required this.gameId,
    required this.firestoreController,
  });

  // ---------------------
  // INITIAL SETUP
  // ---------------------
  Future<void> syncWithFirestore() async {
    try {
      final gameSnapshot = await firestoreController.getGame(gameId);
      if (!gameSnapshot.exists) return;

      final gameData = gameSnapshot.data()!;
      ruleSet = RuleSet.fromName(gameData['rules']);
      maxPlayers = gameData['max_players'] ?? 0;

      roundNumber = gameData['roundNumber'] ?? 1;

      final playersData = await firestoreController.getPlayers(gameId);
      players = playersData.map((pData) => Player.fromMap(pData)).toList();

      final index = players.indexWhere((p) => p.id == gameData['currentPlayer']);
      if (index >= 0) {
        currentPlayerIndex = index;
      }

      hasDrawnCard = players[currentPlayerIndex].getHasDrawn();

      final deckData = await firestoreController.getDeck(gameId);
      if (deckData.isNotEmpty) {
        deck.cards
          ..clear()
          ..addAll(deckData.map((card) => CardEntity.fromMap(card)));
      }

      final tableData = gameData['table'];
      table.clear();
      if (tableData is Map<String, dynamic>) {
        table.addAll(
          tableData.values.map((group) {
            if (group is List<dynamic>) {
              return group.map((c) => CardEntity.fromMap(c)).toList();
            }
            throw Exception('Invalid table group format in Map');
          }),
        );
      } else if (tableData is List<dynamic>) {
        table.addAll(
          tableData.map((group) {
            if (group is List<dynamic>) {
              return group.map((c) => CardEntity.fromMap(c)).toList();
            }
            throw Exception('Invalid table group format in List');
          }),
        );
      }

      final discardPileData = gameData['discardPile'] as List<dynamic>? ?? [];
      discardPile
        ..clear()
        ..addAll(
          discardPileData.map((card) => CardEntity.fromMap(card)),
        );
    } catch (e) {
      // Consider logging this error instead of printing
      // log.error('Error syncing with Firestore: $e');
    }
  }

  // ---------------------
  // TURN / ROUND MANAGEMENT
  // ---------------------
  int getDeckLength() => deck.getLength();

  int getRoundNumber() => roundNumber;

  void nextTurn() async {
    hasDrawnCard = false;
    await firestoreController.updatePlayer(
      gameId,
      players[currentPlayerIndex].id,
      {
        'hasDrawn': false,
        'isOut': players[currentPlayerIndex].isOut(),
      },
    );

    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;

    hasDrawnCard = false;

    await firestoreController.updateGameState(gameId, {
      'currentPlayer': players[currentPlayerIndex].id,
    });

    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> nextRound() async {
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (context) {
          Future.delayed(const Duration(seconds: 10), () {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          });

          return AlertDialog(
            title: Text('Round $roundNumber Starting!'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next round begins!'), // Placeholder, consider passing winner name
                  const SizedBox(height: 15),
                  Text('Current Scores:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  DataTable(
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('Player')),
                      DataColumn(label: Text('Points'), numeric: true),
                    ],
                    rows: players.map((player) {
                      return DataRow(cells: [
                        DataCell(Text(player.name)),
                        DataCell(Text(player.getPoints().toString())),
                      ]);
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // Consider logging this error
      // log.error("Error: navigatorKey.currentContext is null. Cannot show dialog.");
    }
    await Future.delayed(const Duration(seconds: 11));

    onNextRoundStarted?.call();
  }

  // ---------------------
  // CARD ACTIONS
  // ---------------------
  void drawCard(String source) async {
    if (hasDrawnCard) return;

    CardEntity drawnCard;
    if (source == 'deck') {
      if (deck.isEmpty()) return; // Check if deck is empty
      drawnCard = deck.dealOne();
    } else if (source == 'discardPile' && discardPile.isNotEmpty) {
      if (players[currentPlayerIndex].getCoins() < 1) {
        return;
      }
      drawnCard = discardPile.removeLast();
      players[currentPlayerIndex].removeCoin();
    } else {
      return;
    }

    players[currentPlayerIndex].addCardToHand(drawnCard);
    hasDrawnCard = true;
    players[currentPlayerIndex].setDrawed(true);

    try {
      await firestoreController.updatePlayer(
        gameId,
        players[currentPlayerIndex].id,
        {
          'hand': players[currentPlayerIndex]
              .hand
              .map((card) => card.toMap())
              .toList(),
          'coins': players[currentPlayerIndex].getCoins(),
          'hasDrawn': true, // Update hasDrawn status in Firestore
        },
      );
      await firestoreController.updateGameState(gameId, {
        'discardPile': discardPile.map((card) => card.toMap()).toList(),
        'deck': deck.cards.map((card) => card.toMap()).toList(),
      });
      await firestoreController.createDrawEvent(
        gameId,
        players[currentPlayerIndex].id,
        drawnCard.toMap(),
        source,
      );
    } catch (e) {
      // Consider logging this error
      // log.error('Error updating game state after draw: $e');
    }
  }

  // ---------------------
  // MOVE VALIDATION
  // ---------------------
  bool validateMove(List<CardEntity> cards, [bool addToMoves = true]) {
    if (!hasDrawnCard) return false;
    if (ruleSet.validateMove(cards)) {
      if (addToMoves) {
        currentMoves.add(cards);
      }
      return true;
    }
    return false;
  }

  Future<bool> validateDiscard(CardEntity card) async {
    if (!hasDrawnCard) return false;

    if (card.rank == '2' || card.rank == 'Joker') {
      return false;
    }

    bool canDiscard = false;
    bool playerIsOut = players[currentPlayerIndex].isOut();

    if (currentMoves.isEmpty) {
      // Simple discard without playing moves
      canDiscard = true;
    } else {
      // Discarding after playing moves
      canDiscard = playerIsOut || ruleSet.validateRoundCondition(currentMoves, roundNumber);
    }

    if (!canDiscard) return false;

    // Perform discard
    discardPile.add(card);
    players[currentPlayerIndex].removeCardFromHand(card);

    // Update player hand in Firestore
    await firestoreController.updatePlayer(
      gameId,
      players[currentPlayerIndex].id,
      {
        'hand': players[currentPlayerIndex].hand.map((c) => c.toMap()).toList(),
        'isOut': playerIsOut || currentMoves.isNotEmpty, // Update isOut if moves were played
      },
    );

    // Add moves to table if any were made this turn
    if (currentMoves.isNotEmpty) {
      addCurrentMovesToTable(); // This updates Firestore table
      removeCurrentMovesFromPlayersHand(); // Clears local currentMoves
      players[currentPlayerIndex].setOut(true); // Update local state
    }

    // Update discard pile in Firestore
    await _updateDiscardPile();

    // Check for win, otherwise proceed to next turn
    if (!await checkForWin()) {
      nextTurn();
    }
    hasDrawnCard = false; // Reset draw status for next turn
    return true;
  }

  void addCurrentMovesToTable() async {
    for (var move in currentMoves) {
      table.add(move);
    }
    final tableMap = {
      for (int i = 0; i < table.length; i++)
        i.toString(): table[i].map((card) => card.toMap()).toList(),
    };
    await firestoreController.updateGameState(gameId, {'table': tableMap});
  }

  bool removeMove(List<CardEntity> group) {
    final index = currentMoves.indexWhere((g) =>
        listEquals(g.map((c) => c.toString()).toList()..sort(),
            group.map((c) => c.toString()).toList()..sort()));

    if (index != -1) {
      currentMoves.removeAt(index);
      return true;
    }
    return false;
  }

  // ---------------------
  // WIN CHECK & SCORING
  // ---------------------
  Future<bool> checkForWin() async {
    if (players[currentPlayerIndex].hand.isNotEmpty) return false;
    final roundWinnerId = players[currentPlayerIndex].id;

    calculatePoints(); // This updates Firestore player points and round scores
    await Future.delayed(const Duration(seconds: 2)); // Allow time for score display/animation

    if (roundNumber == ruleSet.lastRoundNumber()) {
      final winner = getWinnigPlayer();
      await firestoreController.updateGameState(gameId, {
        'winner': winner.name,
        'isGameOver': true,
      });
      return true; // Game over
    } else {
      // Start next round (updates Firestore round number, currentPlayer, etc.)
      firestoreController.startNewRound(gameId, roundWinnerId);
      return true; // Round over, but game continues
    }
  }

  void calculatePoints() async {
    final roundPenaltyPoints = <String, int>{};
    for (var player in players) {
      if (player.id == players[currentPlayerIndex].id && player.hand.isEmpty) {
        roundPenaltyPoints[player.id] = 0;
        continue;
      }

      int points = 0;
      for (var card in player.hand) {
        if (card.rank == '2') {
          points += 20;
        } else if (card.rank == 'A') {
          points += 15;
        } else if (card.rank == 'Joker') {
          points += 50;
        } else if (['3', '4', '5', '6', '7'].contains(card.rank)) {
          points += 5;
        } else {
          // 8, 9, 10, J, Q, K
          points += 10;
        }
      }
      player.addPoints(points); // Update local player points
      roundPenaltyPoints[player.id] = points;

      // Update total points in Firestore for the player
      await firestoreController.updatePlayer(gameId, player.id, {
        'points': player.points,
      });
    }
    // Send the map of ROUND penalty points to Firestore
    await firestoreController.updateRoundScores(gameId, roundNumber, roundPenaltyPoints);
  }

  Player getWinnigPlayer() {
    // Assumes lowest score wins
    var winner = players[0];
    for (var p in players) {
      if (p.points < winner.points) winner = p;
    }
    return winner;
  }

  // ---------------------
  // HELPERS
  // ---------------------
  Future<void> _updateDiscardPile() async {
    await firestoreController.updateGameState(gameId, {
      'discardPile': discardPile.map((c) => c.toMap()).toList(),
    });
  }

  void removeCurrentMovesFromPlayersHand() async {
    currentMoves.clear();
  }

  // ---------------------
  // LISTENERS
  // ---------------------
  void listenToGameState() {
    firestoreController.listenToGameState(gameId).listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data()!;

      final cpIndex = players.indexWhere((p) => p.id == data['currentPlayer']);
      if (cpIndex >= 0) {
        currentPlayerIndex = cpIndex;
      }

      final tableData = data['table'];
      table.clear();
      if (tableData is Map<String, dynamic>) {
        table.addAll(
          tableData.values.map((group) {
            if (group is List<dynamic>) {
              return group.map((c) => CardEntity.fromMap(c)).toList();
            }
            throw Exception('Invalid table group format in Map');
          }),
        );
      } else if (tableData is List<dynamic>) {
        table.addAll(
          tableData.map((group) {
            if (group is List<dynamic>) {
              return group.map((c) => CardEntity.fromMap(c)).toList();
            }
            throw Exception('Invalid table group format in List');
          }),
        );
      }

      discardPile.clear();
      final discardData = data['discardPile'];
      if (discardData is List<dynamic>) {
        discardPile.addAll(discardData.map((card) => CardEntity.fromMap(card as Map<String, dynamic>)));
      } else {
        // Consider logging error
      }

      final deckData = data['deck'];
      if (deckData is List<dynamic>) {
        try {
          deck.cards
            ..clear()
            ..addAll(deckData.map((card) => CardEntity.fromMap(card as Map<String, dynamic>)));
        } catch (e) {
          // Consider logging error
        }
      }

      final newRoundNumber = data['roundNumber'] ?? roundNumber;
      if (newRoundNumber != roundNumber && newRoundNumber > 0) {
        roundNumber = newRoundNumber;
        nextRound(); // Trigger the round transition dialog/logic
      } else {
        roundNumber = newRoundNumber; // Sync round number if it hasn't triggered nextRound
      }

      paused = data['isGamePaused'] ?? false;
      gameOver = data['isGameOver'] ?? false;
    });
  }

  void listenToPlayerUpdates() {
    firestoreController.listenToPlayersUpdate(gameId).listen((playersData) {
      // Update local player list, preserving order might be important
      final updatedPlayers = playersData.map((p) => Player.fromMap(p)).toList();

      // Update existing players and add new ones (safer if order matters)
      for (var updatedPlayer in updatedPlayers) {
        final index = players.indexWhere((p) => p.id == updatedPlayer.id);
        if (index != -1) {
          players[index] = updatedPlayer; // Update existing
        } else {
          players.add(updatedPlayer); // Add new (shouldn't happen mid-game?)
        }
      }
      // Remove players no longer in the update (if players can leave mid-game)
      players.removeWhere((p) => !updatedPlayers.any((up) => up.id == p.id));

      // Update hasDrawnCard based on the current player's updated status
      if (players.isNotEmpty && currentPlayerIndex < players.length) {
        hasDrawnCard = players[currentPlayerIndex].getHasDrawn();
      }
    });
  }

  bool isPaused() => paused;
  bool isPlayersTurn(String pid) => players.isNotEmpty && currentPlayerIndex < players.length && players[currentPlayerIndex].id == pid;
  bool isGameOver() => gameOver;

  Future<void> handlePlayAgain(String playerId) async {
    if (gameOver) {
      await firestoreController.markPlayerReadyForRematch(gameId, playerId);
    }
  }
}