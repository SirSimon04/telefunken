import '../models/deck.dart';
import '../models/player.dart';
import 'rules/rule_set.dart';

class GameLogic {
  final Deck deck;
  final List<Player> players;
  final RuleSet ruleSet;

  GameLogic({
    required this.deck,
    required this.players,
    required this.ruleSet,
  });

  void startGame() {
    deck.shuffle();
    // Beispiel: Erster Spieler (Splitter) erhält 12 Karten, die anderen 11
    int cardsToDeal = players.length * 11 + 1; // 12 Karten für den ersten Spieler, 11 für die anderen
    int playerIndex = 0;

    for (int i = 0; i < cardsToDeal; i++) {
      players[playerIndex].hand.add(deck.deal(1));
      playerIndex = (playerIndex + 1) % players.length;
    }

    // Regelwerkspezifische Initialisierung
    ruleSet.initializeGame(players, deck);
  }
}
