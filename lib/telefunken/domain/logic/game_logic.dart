import 'package:telefunken/telefunken/domain/entities/card_entity.dart';

import '../entities/deck.dart';
import '../entities/player.dart';
import '../rules/rule_set.dart';
import '../../presentation/game/telefunken_game.dart';

class GameLogic {
  late Deck deck;
  final List<Player> players;
  final RuleSet ruleSet;
  final Duration roundDuration;
  final TelefunkenGame game;
  final bool isLocal;

  GameLogic({
    required this.players,
    required this.ruleSet,
    required this.roundDuration,
    required this.game,
    this.isLocal = false,
  });

  void startGame() {
    deck = Deck();
    game.deck = deck;

    deck.shuffle();
    
    // Beispiel: Erster Spieler (Splitter) erhält 12 Karten, die anderen 11
    int cardsToDeal = players.length * 11 + 1; // 12 Karten für den ersten Spieler, 11 für die anderen
    int playerIndex = 0;

    for (int i = 0; i < cardsToDeal; i++) {
      Player currentPlayer = players[playerIndex];
      CardEntity card = deck.deal(1).first;
      currentPlayer.addCardToHand(card);
      playerIndex = (playerIndex + 1) % players.length;
    }

  }

  void validateMove(Player player, CardEntity card){
    // if (ruleSet.isValidMove(player, card)){
    //   ruleSet.executeMove(player, card);
    //   updateUI();
    // }
  }

  void updateUI() {
    //game.nextTurn();
  }

  int getDeckLenght() {
    return deck.getLength();
  }
}
