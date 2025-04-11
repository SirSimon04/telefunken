import 'package:cloud_firestore/cloud_firestore.dart';
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

  GameLogic({
    required this.gameId,
    required this.firestoreController,
  });

  // Synchronisiere den Spielstatus mit Firestore
  Future<void> syncWithFirestore() async {
    try {
      final gameSnapshot = await firestoreController.getGame(gameId);
      if (!gameSnapshot.exists) return;
      final gameData = gameSnapshot.data()!;

      ruleSet = RuleSet.fromName(gameData['rules']);

      maxPlayers = gameData['max_players'] ?? 0;
      currentPlayerIndex = players.indexWhere((p) => p.id == gameData['currentPlayer']);
      roundNumber = gameData['roundNumber'] ?? 1;

      final playersData = await firestoreController.getPlayers(gameId);

      players = playersData.map((playerData) {
        final player = Player.fromMap(playerData);
        print('Player: ${player.name}, ID: ${player.id}');
        return player;
      }).toList();

      // Load the deck
      final deckData = await firestoreController.getDeck(gameId);

      if (deckData.isEmpty) {
        print('Deck data is empty.');
        return;
      }

      try {
        deck.cards.clear();
        deck.cards.addAll(deckData.map((card) => CardEntity.fromMap(card)));
      } catch (e) {
        print('Error processing deck data: $e');
      }

      // Load the table
      table.clear();
      final tableData = gameData['table'] as List<dynamic>? ?? [];
      try {
        table.addAll(tableData.map((group) {
          if (group is List<dynamic>) {
            return group.map((card) => CardEntity.fromMap(card)).toList();
          } else {
            throw Exception('Invalid table group format');
          }
        }));
      } catch (e) {
        print('Error processing table data: $e');
      }

      // Load the discard pile
      discardPile.clear();
      final discardPileData = gameData['discardPile'] as List<dynamic>? ?? [];
      try {
        discardPile.addAll(discardPileData.map((card) => CardEntity.fromMap(card)));
      } catch (e) {
        print('Error processing discard pile data: $e');
      }
    } catch (e) {
      print('Error syncing with Firestore: $e');
    }
  }

  int getDeckLength() {
    return deck.getLength();
  }

  // Nächster Spieler und Synchronisation
  void nextTurn() async {
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;

    hasDrawnCard = false;

    await firestoreController.updateGameState(gameId, {
      'currentPlayer': players[currentPlayerIndex].id,
      'discardPile': discardPile.map((card) => card.toMap()).toList(),
    });
  }

  // Karte ziehen
  Future<CardEntity?> drawCard(String source) async {
    if (hasDrawnCard) return null;

    CardEntity drawnCard;
    if (source == 'deck') {
      drawnCard = deck.dealOne();
    } else if (source == 'discardPile' && discardPile.isNotEmpty) {
      if(players[currentPlayerIndex].getCoins() < 1) {
        //show in breadcrumb that no coins are available
        print("Player ${players[currentPlayerIndex].name} has no coins to draw from discard pile.");
        return null;
      }
      drawnCard = discardPile.removeLast();
      players[currentPlayerIndex].removeCoin();
    } else {
      print("Invalid source or discard pile is empty.");
      return null;
    }

    players[currentPlayerIndex].addCardToHand(drawnCard);
    hasDrawnCard = true;

    await firestoreController.updatePlayer(
      gameId,
      players[currentPlayerIndex].id,
      {
        'hand': players[currentPlayerIndex].hand.map((card) => card.toMap()).toList(),
        'coins': players[currentPlayerIndex].getCoins(),
      },
    );

    try {
      await firestoreController.updateGameState(gameId, {
        'discardPile': discardPile.map((card) => card.toMap()).toList(),
        'deck': deck.cards.map((card) => card.toMap()).toList(),
      });
      await FirebaseFirestore.instance
        .collection('games')
        .doc(gameId)
        .update({
          'lastDraw': {
            'playerId': players[currentPlayerIndex].id,
            'card': drawnCard.toMap(),
            'source': source,
            'timestamp': FieldValue.serverTimestamp(),
        }
      });
    } catch (e) {
      print('Error updating game state: $e');
    }

    print("Player ${players[currentPlayerIndex].name} drew a card from $source.");
    return drawnCard;
  }

  void nextRound() async {
    Player temp = players[0];
    players.removeAt(0);
    players.add(temp);

    for (var player in players) {
      player.hand.clear();
    }
    // Reset the table and discard pile
    table.clear();
    discardPile.clear();
    // Reset the round number and deal new cards
    roundNumber++;
    currentPlayerIndex = 0;
    deck.reset();
    deck.shuffle();

    await firestoreController.updateGameState(gameId, {
      'roundNumber': roundNumber,
      'deck': deck.cards.map((card) => card.toMap()).toList(),
      'discardPile': [],
      'table': [],
    });
  }

  bool isPaused(){
    return paused;
  }

  bool isPlayersTurn(String playerId){
    return players[currentPlayerIndex].id == playerId;
  }

  // Validierung von Zügen
  bool validateMove(List<CardEntity> cards) {
    if (!hasDrawnCard) return false;

    if (ruleSet.validateMove(cards)) {
      currentMoves.add(cards);
      print("Valid move: $cards");
      return true;
    } else {
      print("Invalid move: $cards");
      return false;
    }
  }

  // Validierung von Ablagen
  Future<bool> validateDiscard(CardEntity card) async {
    if (!hasDrawnCard) return false;

    if (currentMoves.isEmpty) {
      if (ruleSet.validateDiscard(card)) {
        discardPile.add(card);
        players[currentPlayerIndex].removeCardFromHand(card);

        await firestoreController.updateGameState(gameId, {
          'discardPile': discardPile.map((card) => card.toMap()).toList(),
        });

        checkForWin();
        nextTurn();
        return true;
      }
    } else {
      if (players[currentPlayerIndex].isOut || ruleSet.validateRoundCondition(currentMoves, roundNumber)) {
        discardPile.add(card);
        players[currentPlayerIndex].removeCardFromHand(card);
        addCurrentMovesToTable();
        removeCurrentMovesFromPlayersHand();
        players[currentPlayerIndex].isOut = true;

        await firestoreController.updateGameState(gameId, {
          'discardPile': discardPile.map((card) => card.toMap()).toList(),
        });

        checkForWin();
        nextTurn();
        return true;
      } else {
        print("Player is not out yet or the round condition is not met.");
        return false;
      }
    }
    return false;
  }

  void addCurrentMovesToTable() async {
    for (var move in currentMoves) {
      table.add(move);
    }
    final tableMap = {
      for (int i = 0; i < table.length; i++) i.toString(): table[i].map((card) => card.toMap()).toList(),
    };
    
    await firestoreController.updateGameState(gameId, {
      'table': tableMap,
    });
  }

  // Überprüfe, ob ein Spieler gewonnen hat
  Future<bool> checkForWin() async {
    if (players[currentPlayerIndex].hand.isEmpty) {
      print("Player ${players[currentPlayerIndex].name} has won the round!");
      paused = true;
      calculatePoints();
      Player winningPlayer = getWinnigPlayer();
      await firestoreController.updateGameState(gameId, {
        'winner': winningPlayer.name,
        'isGameOver': true,
      });
      return true;
    }
    return false;
  }

  // Punkte berechnen
  void calculatePoints() {
    for (var player in players) {
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
          points += 10;
        }
      }
      player.points = points;
    }
  }

  Player getWinnigPlayer(){
    Player winningPlayer = players[0];
    for (var player in players) {
      print("Player ${player.name} has ${player.points} points.");
      if(player.points < winningPlayer.points){
        winningPlayer = player;
      }
    }
    print("Player ${winningPlayer.name} is leading the game with ${winningPlayer.points} points!");
    return winningPlayer;
  }

  removeCurrentMovesFromPlayersHand() async {
    for (var move in currentMoves) {
      players[currentPlayerIndex].removeCardsFromHand(move);
    }
    currentMoves.clear();

    await firestoreController.updatePlayer(
      gameId,
      players[currentPlayerIndex].id,
      {
        'hand': players[currentPlayerIndex].hand.map((card) => card.toMap()).toList(),
      }
    );
  }

  void listenToGameState() {
    firestoreController.listenToGameState(gameId).listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        
        // Aktualisiere den aktuellen Spieler
        currentPlayerIndex = players.indexWhere((p) => p.id == data['currentPlayer']);

        // Aktualisiere das Table
        final tableData = data['table'];
        table.clear();
        if (tableData is Map<String, dynamic>) {
          table.addAll(tableData.values.map((group) {
            if (group is List<dynamic>) {
              return group.map((card) => CardEntity.fromMap(card)).toList();
            } else {
              throw Exception('Invalid table group format in Map');
            }
          }));
        } else if (tableData is List<dynamic>) {
          table.addAll(tableData.map((group) {
            if (group is List<dynamic>) {
              return group.map((card) => CardEntity.fromMap(card)).toList();
            } else {
              throw Exception('Invalid table group format in List');
            }
          }));
        } else {
          throw Exception('Invalid table data format');
        }

        // Aktualisiere die Discard Pile
        discardPile.clear();
        final discardPileData = data['discardPile'];
        if (discardPileData is List<dynamic>) {
          print("changed discard pile");
          discardPile.addAll(discardPileData.map((card) => CardEntity.fromMap(card)));
        } else {
          throw Exception('Invalid discard pile data format');
        }
        
        // NEU: Aktualisiere das Deck
        final deckData = data['deck'];
        if (deckData is List<dynamic>) {
          try {
            deck.cards.clear();
            deck.cards.addAll(deckData.map((card) => CardEntity.fromMap(card)));
          } catch (e) {
            print('Error processing deck data in listener: $e');
          }
        } else {
          print('Deck data not in expected format.');
        }

        // Aktualisiere Spiel-Flags
        paused = data['isGamePaused'] ?? false;
        gameOver = data['isGameOver'] ?? false;
      }
    });
  }

    void listenToPlayerUpdates() {
      firestoreController.listenToPlayersUpdate(gameId).listen((playersData) {
        players = playersData.map((playerData) => Player.fromMap(playerData)).toList();
      });
    }

  bool isGameOver() {
    return gameOver;
  }


  ///ToDo:
  /// - Gerade ist es Random ob die Reiehnfolge der Spieler richtig angezeigt wird.

  /// - Regelwerk überarbeiten
  /// - Punktevergabe überarbeiten und Punktzahl neben dem Spieler anzeigen 
  /// - Rundencounter in die Ecke hauen
  /// - Buy Button für die Karten
  /// - Am Spielende soll das Spielfeld 3 Sekunden lang stehen bleiben, dann navigiert man zu einer neuen Seite, wo eine Tabelle mit den Spieler und der Punkte und den bekommenen Punkten per Runde angezeigt wird.
  /// - Karten an andere Karten anlegen können
  /// - Bei den anlegenden Karten schauen ob man einen Joker ersetzen und benutzen kann
}
