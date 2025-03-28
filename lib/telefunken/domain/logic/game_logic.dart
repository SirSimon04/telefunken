import 'package:flame/image_composition.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';

import '../entities/deck.dart';
import '../entities/player.dart';
import '../rules/rule_set.dart';
import '../../presentation/game/telefunken_game.dart';

class GameLogic {
  final List<Player> players;
  final RuleSet ruleSet;

  late Deck deck;
  final List<CardEntity> table = [];
  final List<CardEntity> discardPile = [];

  late int currentPlayerIndex ;

  GameLogic({
    required this.players,
    required this.ruleSet,
    this.currentPlayerIndex = 0,
  });

  void startGame() {
    deck = Deck();
    //players.shuffle();
    players.reverse();
    deck.shuffle();

    int cardsToDeal = players.length * 11 + 1; // 12 Karten für den ersten Spieler, 11 für die anderen
    dealCards(cardsToDeal);

    for (var player in players) {
      sortPlayersHand(player);
    }
  }

  void dealCards(int cardsToDeal) {
    int playerIndex=0;
    for (int i = 0; i < cardsToDeal; i++) {
      Player currentPlayer = players[playerIndex];
      CardEntity card = deck.dealOne();
      currentPlayer.addCardToHand(card);
      playerIndex = (playerIndex + 1) % players.length;
    }
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

  bool validateMove(List<CardEntity> cards, Player player) {
    if(cards.length > 1){
      return validateTable(cards, player);
    }else if(cards.length == 1){
      return validateDiscard(cards.first, player);
    }
    return true;
  }

  bool validateTable(List<CardEntity> cards, Player player) {
    print("Validating: " + cards.toString());
    // Hier die Logik zur Validierung der Karten auf dem Tisch implementieren
    return true;
  }

  bool validateDiscard(CardEntity card, Player player) {
    card.isUp = true; // Karte aufdecken
    if (card.suit == 'Joker' || card.rank == '2') {
      print("Joker oder 2 Karte auf den Ablagestapel gelegt");
      // Joker dürfen nicht auf den Ablagestapel gelegt werden
      return false;
    }
    return true;
  }

  bool isPlayersTurn(int playerID){
    return players[currentPlayerIndex].id == playerID;
  }

  void updateUI() {
    //game.nextTurn();
  }

  void nextTurn(){

  }

  int getDeckLength() {
    return deck.getLength();
  }

  void playCard(CardEntity card) {
    table.add(card);
    players[currentPlayerIndex].removeCardFromHand(card);
    card.isUp = true;
  }

  void playCards(List<CardEntity> cards) {
    for (var card in cards) {
      playCard(card);
    }
  }

  void discardCard(CardEntity card) {
    discardPile.add(card); // Karte in den Ablagestapel verschieben
    players[currentPlayerIndex].removeCardFromHand(card);
    card.isUp = true;

    //next Player
  }
}
