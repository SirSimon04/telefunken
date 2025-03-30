import 'package:telefunken/telefunken/domain/entities/card_entity.dart';

abstract class RuleSet {
  bool validateDiscard(CardEntity card);
  bool validateMove(List<CardEntity> cards);
  bool validateRoundCondition(List<List<CardEntity>> cards, int roundNumber);
}