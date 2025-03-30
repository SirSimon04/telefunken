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
  final List<Player> players;
  final RuleSet ruleSet;
  final FirestoreController firestoreController;

  late Deck deck;
  final List<List<CardEntity>> table = [];
  final List<CardEntity> discardPile = [];

  late int currentPlayerIndex;
  late int roundNumber;
  late List<List<CardEntity>> currentMoves = [];

  final String gameId; // Firestore Game ID

  GameLogic({
    required this.players,
    required this.ruleSet,
    required this.firestoreController,
    required this.gameId,
    this.currentPlayerIndex = 0,
    this.roundNumber = 1,
  });

  // Starte das Spiel und synchronisiere mit Firestore
  Future<void> startGame() async {
    deck = Deck();
    //pl//ayers.shuffle();
    players.reverse();
    deck.shuffle();

    int cardsToDeal = players.length * 11 + 1;
    dealCards(cardsToDeal);

    for (var player in players) {
      sortPlayersHand(player);
    }

    // Synchronisiere den initialen Spielstatus mit Firestore
    await firestoreController.updateGameState(gameId, {
      'currentPlayer': players[currentPlayerIndex].id,
      'table': table.map((group) => group.map((card) => card.toMap()).toList()).toList(),
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

  bool isPlayersTurn(int playerID){
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
  }

  bool checkForWin(){
    if(players[currentPlayerIndex].hand.length == 0){
      print("Player ${players[currentPlayerIndex].name} has won the game!");
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

  // Beobachte Änderungen im Spielstatus
  void listenToGameState() {
    firestoreController.listenToGameState(gameId).listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        // Aktualisiere den lokalen Spielstatus basierend auf Firestore-Daten
        currentPlayerIndex = players.indexWhere((p) => p.id == data['currentPlayer']);
        table.clear();
        table.addAll((data['table'] as List).map((group) =>
            (group as List).map((card) => CardEntity.fromMap(card)).toList()));
        discardPile.clear();
        discardPile.addAll((data['discardPile'] as List).map((card) => CardEntity.fromMap(card)));
      }
    });
  }
}
