import 'dart:math';

import 'package:flame/image_composition.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/presentation/game/card_component.dart';
import 'package:telefunken/telefunken/service/firestore_controller.dart';

import '../entities/deck.dart';
import '../entities/player.dart';
import '../rules/rule_set.dart';
import '../../presentation/game/telefunken_game.dart';

class GameLogic {
  final String gameId;
  final FirestoreController firestoreController;

  late List<Player> players;
  late int maxPlayers;
  late RuleSet ruleSet;
  late Deck deck;
  final List<List<CardEntity>> table = [];
  final List<CardEntity> discardPile = [];

  late int currentPlayerIndex;
  late int roundNumber;
  late List<List<CardEntity>> currentMoves = [];
  late bool paused = false;

  GameLogic({
    required this.gameId,
    required this.firestoreController,
    this.currentPlayerIndex = 0,
    this.roundNumber = 1,
  });

  // Starte das Spiel und synchronisiere mit Firestore
  Future<void> startGame() async {
    // Hole die Spieler und Regelwerk aus Firestore
    final gameSnapshot = await firestoreController.getGame(gameId);
    final gameData = gameSnapshot.data()!;
    final playersData = await firestoreController.getPlayers(gameId);
    players = playersData.map((playerData) => Player.fromMap(playerData)).toList();
    ruleSet = RuleSet.fromName(gameData['rules']);
    maxPlayers = gameData['max_players'] as int;

    deck = Deck();
    players.shuffle();
    deck.shuffle();

    int cardsToDeal = players.length * 11 + 1;
    dealCards(cardsToDeal);

    for (var player in players) {
      sortPlayersHand(player);
    }

    final tableMap = {
      for (int i = 0; i < table.length; i++) i.toString(): table[i].map((card) => card.toMap()).toList(),
    };
    await firestoreController.updateGameState(gameId, {
      'currentPlayer': players[currentPlayerIndex].id,
      'table': tableMap,
      'discardPile': discardPile.map((card) => card.toMap()).toList(),
      'isGameStarted': true,
    });
  }

  // Karten austeilen und synchronisieren
  void dealCards(int cardsToDeal) {
    int playerIndex = 0;
    for (int i = 0; i < cardsToDeal; i++) {
      Player currentPlayer = players[playerIndex];
      CardEntity card = deck.dealOne();
      currentPlayer.addCardToHand(card);
      playerIndex = (playerIndex + 1) % players.length;
    }

    // Synchronisiere die Hände der Spieler mit Firestore
    for (var player in players) {
      firestoreController.updateGameState(gameId, {
        'players.${player.id}.hand': player.hand.map((card) => card.toMap()).toList(),
      });
    }
  }

  int getDeckLength() {
    return deck.getLength();
  }
  
  void sortPlayersHand(Player player) {
    const List<String> rankOrder = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
    const List<String> suitOrder = ['Joker', 'C', 'D', 'H', 'S'];

    player.hand.sort((a, b) {
      final int rankCompare = rankOrder.indexOf(a.rank).compareTo(rankOrder.indexOf(b.rank));
      if (rankCompare != 0) return rankCompare;
      return suitOrder.indexOf(b.suit).compareTo(suitOrder.indexOf(a.suit));
    });
  }

  // Nächster Spieler und Synchronisation
  Future<void> nextTurn() async {
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;

    await firestoreController.updateGameState(gameId, {
      'currentPlayer': players[currentPlayerIndex].id,
      'discardPile': discardPile.map((card) => card.toMap()).toList(),
    });
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
    
    dealCards(players.length * 11 + 1);
    for (var player in players) {
      sortPlayersHand(player);
    }
  }

  bool isPaused(){
    return paused;
  }

  bool isPlayersTurn(String playerID){
    return players[currentPlayerIndex].id == playerID;
  }

  bool validateMove(List<CardEntity> cards) {
    if(ruleSet.validateMove(cards)){
      currentMoves.add(cards);
      print("Valider move: $cards");
      return true;
    }else{
      print("Invalid move: $cards");
      return false;
    }
  }

  //wenn eine oder mehrere Karten mit bereits gelegten Karten kollidieren, sollen diese zu den Karten auf dem Tisch hinzugefügt werden, sobald die Regeln dies zulassen
 // bool validateAdditionalCard()

  bool validateDiscard(CardEntity card) {
    if(currentMoves.isEmpty){
      if(ruleSet.validateDiscard(card)){
        discardPile.add(card);
        players[currentPlayerIndex].removeCardFromHand(card);

        firestoreController.updateGameState(gameId, {
          'discardPile': discardPile.map((card) => card.toMap()).toList(),
        });

        checkForWin();
        nextTurn();
        return true;
      }
    }else{
      if(players[currentPlayerIndex].isOut || ruleSet.validateRoundCondition(currentMoves, roundNumber)){
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
      }else{
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

  bool checkForWin() {
    if (players[currentPlayerIndex].hand.isEmpty) {
      print("Player ${players[currentPlayerIndex].name} has won the game!");
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

  void calculatePoints(){
    for (var player in players) {
      int points = 0;
      for (var card in player.hand) {
        if(card.rank == '2'){
          points += 20;
        }else if(card.rank == 'A'){
          points += 15;
        }else if(card.suit == 'Joker'){
          points += 50;
        }else if(card.rank == '3' || card.rank == '4' || card.rank == '5' || card.rank == '6' || card.rank == '7'){
          points += 5;
        }else{
          points += 10;
        }
      }
      print("Player ${player.name} has $points points.");
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
        table.clear();
        final tableMap = data['table'] as Map<String, dynamic>;
        table.addAll(tableMap.values.map((group) =>
            (group as List).map((card) => CardEntity.fromMap(card)).toList()));

        discardPile.clear();
        discardPile.addAll((data['discardPile'] as List).map((card) => CardEntity.fromMap(card)));

        paused = data['isGamePaused'] ?? false;
      }
    });
  }


  ///ToDo:
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
