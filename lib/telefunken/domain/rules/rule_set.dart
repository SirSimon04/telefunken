import '../entities/deck.dart';
import '../entities/player.dart';

abstract class RuleSet {
  void initializeGame(List<Player> players, Deck deck);
  // Hier kannst du weitere abstrakte Methoden für die Spiellogik definieren.
}
