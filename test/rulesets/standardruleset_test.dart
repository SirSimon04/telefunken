import 'package:flutter_test/flutter_test.dart';
import 'package:telefunken/telefunken/domain/rules/standard_rule_set.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';

void main() {
  group('StandardRuleSet Tests', () {
    late StandardRuleSet ruleSet;

    setUp(() {
      ruleSet = StandardRuleSet();
    });

    group('Valid pair of 3 cards', (){
      test('validateCards - valid pair of 3 cards', () {
        final cards = [
          CardEntity(suit: 'H', rank: '3'),
          CardEntity(suit: 'D', rank: '3'),
          CardEntity(suit: 'S', rank: '3'),
        ];

        final result = ruleSet.validateMove(cards);

        expect(result, isTrue, reason: 'A valid pair of 3 cards should pass.');
      });
      test('valid pair of 3 cards + Joker', () {
        final cards = [
          CardEntity(suit: 'H', rank: '3'),
          CardEntity(suit: 'Joker', rank: ''),
          CardEntity(suit: 'S', rank: '3'),
        ];

        final result = ruleSet.validateMove(cards);

        expect(result, isTrue, reason: 'A valid pair of 3 cards should pass.');
      });
      test('valid pair of 3 cards + 2 as Joker', () {
        final cards = [
          CardEntity(suit: 'H', rank: '3'),
          CardEntity(suit: 'H', rank: '2'),
          CardEntity(suit: 'S', rank: '3'),
        ];
        final result = ruleSet.validateMove(cards);
        expect(result, isTrue, reason: 'A valid pair of 3 cards should pass.');
      });
      test('invalid pair of 3 cards - too many Joker', () {
        final cards = [
          CardEntity(suit: 'Joker', rank: ''),
          CardEntity(suit: 'Joker', rank: ''),
          CardEntity(suit: 'S', rank: '3'),
        ];

        final result = ruleSet.validateMove(cards);

        expect(result, isFalse, reason: 'More Joker than normal cards should fail.');
      });
    });

    group('Valid Sequence of 7 cards', (){
      test('validateCards - valid sequence of 7 cards', () {
        final cards = [
          CardEntity(suit: 'H', rank: '3'),
          CardEntity(suit: 'H', rank: '4'),
          CardEntity(suit: 'H', rank: '5'),
          CardEntity(suit: 'H', rank: '6'),
          CardEntity(suit: 'H', rank: '7'),
          CardEntity(suit: 'H', rank: '8'),
          CardEntity(suit: 'H', rank: '9'),
        ];

        final result = ruleSet.validateMove(cards);

        expect(result, isTrue, reason: 'A valid sequence of 7 cards should pass.');
      });

      test('validateCards - valid sequence of 7 cards + Joker', () {
        final cards = [
          CardEntity(suit: 'H', rank: '3'),
          CardEntity(suit: 'Joker', rank: ''),
          CardEntity(suit: 'Joker', rank: '1'),
          CardEntity(suit: 'H', rank: '6'),
          CardEntity(suit: 'H', rank: '7'),
          CardEntity(suit: 'Joker', rank: ''),
          CardEntity(suit: 'H', rank: '9'),
        ];
        final result = ruleSet.validateMove(cards);
        expect(result, isTrue, reason: 'A valid sequence of 7 cards should pass.');
      });

      test('validateCards - valid sequence of 7 cards + Joker and 2 as a Joker', () {
        final cards = [
          CardEntity(suit: 'H', rank: '3'),
          CardEntity(suit: 'Joker', rank: ''),
          CardEntity(suit: 'S', rank: '2'),
          CardEntity(suit: 'H', rank: '6'),
          CardEntity(suit: 'H', rank: '7'),
          CardEntity(suit: 'Joker', rank: ''),
          CardEntity(suit: 'H', rank: '9'),
        ];
        final result = ruleSet.validateMove(cards);
        expect(result, isTrue, reason: 'A valid sequence of 7 cards should pass.');
      });
    });

    test('validateCards - invalid sequence of 5 cards', () {
      final cards = [
        CardEntity(suit: 'H', rank: '3'),
        CardEntity(suit: 'H', rank: '4'),
        CardEntity(suit: 'H', rank: '6'),
        CardEntity(suit: 'H', rank: '7'),
        CardEntity(suit: 'H', rank: '8'),
      ];

      final result = ruleSet.validateMove(cards);

      expect(result, isFalse, reason: 'An invalid sequence of 5 cards should fail.');
    });
  });
}