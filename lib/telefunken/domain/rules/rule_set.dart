import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/domain/rules/standard_rule_set.dart';

abstract class RuleSet {
  bool validateDiscard(CardEntity card);
  bool validateMove(List<CardEntity> cards);
  bool validateRoundCondition(List<List<CardEntity>> cards, int roundNumber);

  static RuleSet fromName(String name) {
    // Example implementation
    switch (name) {
      case 'Standard':
        return StandardRuleSet(); // Replace with actual RuleSet initialization
      // case 'Pro':
      //   return RuleSet(); // Replace with actual RuleSet initialization
      // case 'Fun':
      //   return RuleSet(); // Replace with actual RuleSet initialization
      default:
        throw ArgumentError('Unknown rule set: $name');
    }
  }
}