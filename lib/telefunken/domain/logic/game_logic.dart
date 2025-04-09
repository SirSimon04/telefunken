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
  late bool hasDrawnCard = false;

  GameLogic({
    required this.gameId,
    required this.firestoreController,
  });

  // Synchronisiere den Spielstatus mit Firestore
  Future<void> syncWithFirestore() async {
    try {
      final gameSnapshot = await firestoreController.getGame(gameId);
      if (!gameSnapshot.exists) {
        print('Game document does not exist.');
        return;
      }
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
  Future<void> nextTurn() async {
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;

    hasDrawnCard = false;

    await firestoreController.updateGameState(gameId, {
      'currentPlayer': players[currentPlayerIndex].id,
      'discardPile': discardPile.map((card) => card.toMap()).toList(),
    });
  }

  // Karte ziehen
  void drawCard(String source) async {
    if (hasDrawnCard) {
      print("You have already drawn a card this turn.");
      return;
    }

    CardEntity drawnCard;
    if (source == 'deck') {
      drawnCard = deck.dealOne();
    } else if (source == 'discardPile' && discardPile.isNotEmpty) {
      drawnCard = discardPile.removeLast();
    } else {
      print("Invalid source or discard pile is empty.");
      return;
    }

    players[currentPlayerIndex].addCardToHand(drawnCard);
    hasDrawnCard = true;


    try {
      final playerId = players[currentPlayerIndex].id;
      await firestoreController.updateGameState(gameId, {
        'players.$playerId.hand': players[currentPlayerIndex].hand.map((card) => card.toMap()).toList(),
        'discardPile': discardPile.map((card) => card.toMap()).toList(),
      });
    } catch (e) {
      print('Error updating game state: $e');
    }

    print("Player ${players[currentPlayerIndex].name} drew a card from $source.");
  }

  void nextRound(){
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

    firestoreController.updateGameState(gameId, {
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
  bool validateDiscard(CardEntity card) {
    if (!hasDrawnCard) return false;

    if (currentMoves.isEmpty) {
      if (ruleSet.validateDiscard(card)) {
        discardPile.add(card);
        players[currentPlayerIndex].removeCardFromHand(card);

        firestoreController.updateGameState(gameId, {
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

        firestoreController.updateGameState(gameId, {
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

  void addCurrentMovesToTable(){
    for (var move in currentMoves) {
      table.add(move);
    }
    final tableMap = {
      for (int i = 0; i < table.length; i++) i.toString(): table[i].map((card) => card.toMap()).toList(),
    };
    
    firestoreController.updateGameState(gameId, {
      'table': tableMap,
    });
  }

  // Überprüfe, ob ein Spieler gewonnen hat
  bool checkForWin() {
    if (players[currentPlayerIndex].hand.isEmpty) {
      print("Player ${players[currentPlayerIndex].name} has won the round!");
      paused = true;
      calculatePoints();
      Player winningPlayer = getWinnigPlayer();
      firestoreController.updateGameState(gameId, {
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
        } else if (card.suit == 'Joker') {
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
      if(player.points < winningPlayer.points){
        winningPlayer = player;
      }
    }
    print("Player ${winningPlayer.name} is leading the game with ${winningPlayer.points} points!");
    return winningPlayer;
  }

  removeCurrentMovesFromPlayersHand(){
    for (var move in currentMoves) {
      players[currentPlayerIndex].removeCardsFromHand(move);
    }
    currentMoves.clear();
  }

  void listenToGameState() {
    firestoreController.listenToGameState(gameId).listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;

        currentPlayerIndex = players.indexWhere((p) => p.id == data['currentPlayer']);

        final tableData = data['table'];
        table.clear();
        if (tableData is Map<String, dynamic>) {
          // Wenn tableData eine Map ist, die Gruppen als Werte enthält
          table.addAll(tableData.values.map((group) {
            if (group is List<dynamic>) {
              return group.map((card) => CardEntity.fromMap(card)).toList();
            } else {
              throw Exception('Invalid table group format in Map');
            }
          }));
        } else if (tableData is List<dynamic>) {
          // Wenn tableData direkt eine Liste ist
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

        discardPile.clear();
        final discardPileData = data['discardPile'];
        if (discardPileData is List<dynamic>) {
          discardPile.addAll(discardPileData.map((card) => CardEntity.fromMap(card)));
        } else {
          throw Exception('Invalid discard pile data format');
        }
        paused = data['isGamePaused'] ?? false;
      }
    });
  }


  ///ToDo:
  /// !Wichtig! Gerade wird immer ein neues Kartendeck in der gamelogic erstellt. Und die Spieler werden Immer neu gemischt obwohl die Reihenfolge nur ein Mal festgelegt werden soll.. 
  /// 
  /// Wenn eine Karte auf den tisch gelegt wurde und die Gruppe oder eine einzelne Karte wieder bewegt wird, soll sie aus currentMoves gelöscht werden und alle Karten gehen zurück in den Ursprung
  /// 
  /// - Update die Spielerhände von den anderen
  /// - Gerade ist es Random ob die Reiehnfolge der Spieler richtig angezeigt wird.
  /// - Wenn man mehrere Karten hochzieht und ablegen möchte sind sie manchmal noch weit auseinander. Bspw 2, 9, 9. Sie sollen beim "verschieben" nebeneinander angezeigt werden
  /// - Gerade ist der Fehler, wenn die Karten zum Ursprung zurück "fliegen", dann sind sie doppelt da..
  /// - Anstelle vom eigenen Namen soll da einfach "You" stehen
  /// - Karten ziehen implementieren: Zu Rundenbeginn !MUSS! eine Karte entweder vom Kartenstapel oder vom Ablagestapel gezogen werden!! In dieser Zeit kann der Spieler keine Karten ablegen
  /// - Regelwerk überarbeiten
  /// - Punktevergabe überarbeiten und Punktzahl neben dem Spieler anzeigen 
  /// - Rundencounter in die Ecke hauen
  /// - Am Spielende soll das Spielfeld 3 Sekunden lang stehen bleiben, dann navigiert man zu einer neuen Seite, wo eine Tabelle mit den Spieler und der Punkte und den bekommenen Punkten per Runde angezeigt wird.
  /// - Karten an andere Karten anlegen können
  /// - Bei den anlegenden Karten schauen ob man einen Joker ersetzen und benutzen kann
}
