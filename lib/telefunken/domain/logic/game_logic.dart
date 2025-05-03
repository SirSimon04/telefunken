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

      final tableData = gameData['table'] as List<dynamic>? ?? [];
      table
        ..clear()
        ..addAll(
          tableData.map((group) {
            if (group is List<dynamic>) {
              return group.map((c) => CardEntity.fromMap(c)).toList();
            }
            throw Exception('Invalid table group format');
          }),
        );

      final discardPileData = gameData['discardPile'] as List<dynamic>? ?? [];
      discardPile
        ..clear()
        ..addAll(
          discardPileData.map((card) => CardEntity.fromMap(card)),
        );
    } catch (e) {
      print('Error syncing with Firestore: $e');
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
    // final roundWinner = players.firstWhere(
    //   (p) => p.id == roundWinnerPlayerId,
    //   orElse: () => players[0], // Fallback, though should always find the player
    // );

    // --- Updated Show Dialog ---
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false, // Keep it non-dismissible until timer runs out
        builder: (context) {
          // Auto-close dialog after 10 seconds
          Future.delayed(const Duration(seconds: 10), () {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
               Navigator.of(context, rootNavigator: true).pop();
            }
          });

          return AlertDialog(
            title: Text('Round $roundNumber Starting!'),
            content: SingleChildScrollView( // Use SingleChildScrollView if content might overflow
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ddd finished the last round!'),
                  const SizedBox(height: 15),
                  Text('Current Scores:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  DataTable(
                    columnSpacing: 20, // Adjust spacing as needed
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
       print("Error: navigatorKey.currentContext is null. Cannot show dialog.");
    }
    //wait the 10 seconds
    await Future.delayed(const Duration(seconds: 11));

    onNextRoundStarted?.call(); // Notify UI if needed
  }

  // ---------------------
  // CARD ACTIONS
  // ---------------------
  void drawCard(String source) async {
    if (hasDrawnCard) return;

    CardEntity drawnCard;
    if (source == 'deck') {
      drawnCard = deck.dealOne();
    } else if (source == 'discardPile' && discardPile.isNotEmpty) {
      if (players[currentPlayerIndex].getCoins() < 1) {
        // Not enough coins
        return;
      }
      drawnCard = discardPile.removeLast();
      players[currentPlayerIndex].removeCoin();
    } else {
      print("Invalid source or discard pile is empty.");
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
      print('Error updating game state: $e');
    }
  }

  // ---------------------
  // MOVE VALIDATION
  // ---------------------

  //add an optional parameter to the validateMove function
  // to allow for a specific player to be passed in
  bool validateMove(List<CardEntity> cards, [bool addToMoves = true]) {
    if (!hasDrawnCard) return false;
    if (ruleSet.validateMove(cards)) {
      if(addToMoves == false){}
      else{
        currentMoves.add(cards);
      }
      return true;
    }
    return false;
  }

  Future<bool> validateDiscard(CardEntity card) async {
    if (!hasDrawnCard) return false;

    if (card.rank == '2' || card.rank == 'Joker') {
      print("Cannot discard a 2 or Joker.");
      return false;
    }

    if (currentMoves.isEmpty) {
      if (!ruleSet.validateDiscard(card)) return false;

      discardPile.add(card);
      players[currentPlayerIndex].removeCardFromHand(card);
      firestoreController.updatePlayer(
        gameId,
        players[currentPlayerIndex].id,
        {
          'hand': players[currentPlayerIndex]
              .hand
              .map((card) => card.toMap())
              .toList(),
        },
      );
      await _updateDiscardPile();
      if(!await checkForWin()) nextTurn();
      return true;
    } else {
      final canDiscard =
          players[currentPlayerIndex].isOut() ||
          ruleSet.validateRoundCondition(currentMoves, roundNumber);

      if (!canDiscard) return false;

      discardPile.add(card);
      players[currentPlayerIndex].removeCardFromHand(card);
      addCurrentMovesToTable();
      removeCurrentMovesFromPlayersHand();
      players[currentPlayerIndex].setOut(true);
      firestoreController.updatePlayer(
        gameId,
        players[currentPlayerIndex].id,
        {
          'hand': players[currentPlayerIndex]
              .hand
              .map((card) => card.toMap())
              .toList(),
          'isOut': players[currentPlayerIndex].isOut(),
        },
      );
      await _updateDiscardPile();
      if(!await checkForWin()) nextTurn();
      return true;
    }
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

  // Renamed from removeGroupFromCurrentMoves
  bool removeMove(List<CardEntity> group) {
    // Suche exakte Übereinstimmung in currentMoves
    // Using listEquals from package:collection for robust comparison
    final index = currentMoves.indexWhere((g) =>
        listEquals(g.map((c) => c.toString()).toList()..sort(),
                   group.map((c) => c.toString()).toList()..sort()));

    if (index != -1) {
      print("Removing move from currentMoves: $group");
      currentMoves.removeAt(index);
      return true;
    }
    print("Move not found in currentMoves to remove: $group");
    return false;
  }

  // ---------------------
  // WIN CHECK & SCORING
  // ---------------------
  Future<bool> checkForWin() async {
    if (players[currentPlayerIndex].hand.isNotEmpty) return false;
    final roundWinnerId = players[currentPlayerIndex].id;

    calculatePoints();
    await Future.delayed(const Duration(seconds: 2));
    if (roundNumber == 7) {
      final winner = getWinnigPlayer();
      await firestoreController.updateGameState(gameId, {
        'winner': winner.name,
        'isGameOver': true,
      });
      return true;
    } else {
      firestoreController.startNewRound(gameId, roundWinnerId);
      return true;
    }
  }

  void calculatePoints() async {
    final roundPenaltyPoints = <String, int>{}; // Renamed for clarity
    for (var player in players) {
      // Skip the player who went out (they have 0 penalty points for the round)
      if (player.id == players[currentPlayerIndex].id && player.hand.isEmpty) {
         roundPenaltyPoints[player.id] = 0;
         print("Skip player ${player.name} with 0 points");
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
        } else { // 8, 9, 10, J, Q, K
          points += 10;
        }
      }
      player.addPoints(points);
      roundPenaltyPoints[player.id] = points;

      await firestoreController.updatePlayer(gameId, player.id, {
        'points': player.points,
      });
    }
    print("Round Penalty Points: $roundPenaltyPoints");
    // Send the map of ROUND penalty points to Firestore
    await firestoreController.updateRoundScores(gameId, roundNumber, roundPenaltyPoints);
  }

  Player getWinnigPlayer() {
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
    for (var move in currentMoves) {
      players[currentPlayerIndex].removeCardsFromHand(move);
    }
    currentMoves.clear();
    await firestoreController.updatePlayer(
      gameId,
      players[currentPlayerIndex].id,
      {'hand': players[currentPlayerIndex].hand.map((c) => c.toMap()).toList()},
    );
  }

  // ---------------------
  // LISTENERS
  // ---------------------
  void listenToGameState() {
    firestoreController.listenToGameState(gameId).listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data()!;

      // Spieler
      final cpIndex = players.indexWhere((p) => p.id == data['currentPlayer']);
      if (cpIndex >= 0) {
        currentPlayerIndex = cpIndex;
      }

      // Table
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

      // Discard Pile
      discardPile.clear();
      final discardData = data['discardPile'];
      if (discardData is List<dynamic>) {
        discardPile.addAll(discardData.map((card) => CardEntity.fromMap(card as Map<String, dynamic>)));
      } else {
        throw Exception('Invalid discard pile data format');
      }

      // Deck
      final deckData = data['deck'];
      if (deckData is List<dynamic>) {
        try {
          deck.cards
            ..clear()
            ..addAll(deckData.map((card) => CardEntity.fromMap(card as Map<String, dynamic>)));
        } catch (e) {
          print('Error processing deck data: $e');
        }
      }

      if(data['roundNumber'] != roundNumber) {
        nextRound();
      }
      roundNumber = data['roundNumber'] ?? roundNumber;

      paused = data['isGamePaused'] ?? false;
      gameOver = data['isGameOver'] ?? false;
    });
  }

  void listenToPlayerUpdates() {
    firestoreController.listenToPlayersUpdate(gameId).listen((playersData) {
      players = playersData.map((p) => Player.fromMap(p)).toList();
    });
  }

  bool isPaused() => paused;
  bool isPlayersTurn(String pid) => players[currentPlayerIndex].id == pid;
  bool isGameOver() => gameOver;
}