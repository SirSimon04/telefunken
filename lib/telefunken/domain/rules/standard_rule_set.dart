import 'rule_set.dart';
import '../entities/deck.dart';
import '../entities/player.dart';

class StandardRuleSet extends RuleSet {
  @override
  void initializeGame(List<Player> players, Deck deck) {
    // Implementiere hier die Logik für das Standard-Regelwerk.
    print("Standard RuleSet initialisiert.");
  }
}
