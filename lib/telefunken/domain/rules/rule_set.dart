import 'package:telefunken/telefunken/domain/entities/card_entity.dart';

import '../entities/deck.dart';
import '../entities/player.dart';

abstract class RuleSet {
  void initializeGame(List<Player> players, Deck deck);
  bool validateMove(List<CardEntity> cards);
  // Weitere methodische Definitionen entsprechend den Anforderungen
}