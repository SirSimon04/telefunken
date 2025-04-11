import 'package:flutter_test/flutter_test.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/domain/rules/rule_set.dart';
import 'package:telefunken/telefunken/domain/rules/standard_rule_set.dart';

void main() {
  group('StandardRuleSet.validateMove', () {
    late StandardRuleSet ruleSet;
  
    setUp(() {
      ruleSet = StandardRuleSet();
    });
    
    CardEntity card(String rank, [String suit = 'C']) {
        return rank.startsWith('Joker')
        ? CardEntity(suit: '', rank: 'Joker')
        : CardEntity(suit: suit, rank: rank);
    }
    
    test('Zug mit weniger als 3 Karten ist ungültig', () {
      final move = [card('4'), card('5')];
      expect(ruleSet.validateMove(move), isFalse);
    });
    
    test('Ein Zug bestehend aus drei normalen Karten (keine Joker, keine 2 als Ersatz) ist gültig', () {
      final move = [card('4'), card('5'), card('6')];
      expect(ruleSet.validateMove(move), isTrue);
    });
    
    test('Ein Zug mit einem Joker als Substitution bei 3 Karten ist gültig', () {
      final move = [card('Joker'), card('4'), card('5')];
      expect(ruleSet.validateMove(move), isTrue);
    });
    
    test('Ein Zug mit zwei Substitutionen in 3 Karten ist ungültig', () {
      final move = [card('Joker'), card('2'), card('5')];
      expect(ruleSet.validateMove(move), isFalse);
    });
    
    test('Ein Zug mit einem Joker in 4 Karten ist gültig', () {
      final move = [card('Joker'), card('4'), card('5'), card('6')];
      expect(ruleSet.validateMove(move), isTrue);
    });
    
    test('Ein Zug mit 2 als Ersatz in 4 Karten ist gültig', () {
      final move = [card('2'), card('4'), card('5'), card('6')];
      expect(ruleSet.validateMove(move), isTrue);
    });
    
    test('Ein Zug mit Joker und 2 als Ersatz in 4 Karten ist ungültig', () {
      //Die Reihenfolge ist hier entscheidend. So wie es hier steht, ist es ungültig. "2, Joker, 4, 5" wäre gültig.
      final move = [card('Joker'), card('2'), card('4'), card('5')];
      expect(ruleSet.validateMove(move), isFalse);
    });
    
    test('Ein Zug bestehend ausschließlich aus 2en ist gültig (als normal gespielte Karten)', () {
      final move = [card('2'), card('2'), card('2')];
      expect(ruleSet.validateMove(move), isTrue);
    });
    
    test('Ein längerer komplexer Zug, der Joker und 2 als Ersatz mischt, ist gültig', () {
      final move = [
        card('2'),
        card('2'),
        card('4'),
        card('5'),
        card('Joker'),
        card('7'),
        card('8')
      ];
      expect(ruleSet.validateMove(move), isTrue);
    });
    
    test('Ein komplexer Zug, bei dem zu viele Ersatzkarten eingesetzt werden, ist ungültig', () {
      final move = [
        card('2'),
        card('Joker'),
        card('Joker'),
        card('Joker'),
        card('6'),
        card('7')
      ];
      expect(ruleSet.validateMove(move), isFalse);
    });
    
    test('Ein Zug, in dem 2 normal gespielt wird, ist gültig', () {
      final move = [
        card('2'),
        card('Joker'),
        card('Joker'),
        card('5'),
        card('6')
      ];
      expect(ruleSet.validateMove(move), isTrue);
    });
    
    test('Ein Zug mit nur zwei Karten ist ungültig, selbst wenn beide normal wären', () {
      final move = [card('7'), card('8')];
      expect(ruleSet.validateMove(move), isFalse);
    });


    test('Ass in der Mitte einer Sequenz schlägt fehl', () {
      final move = [
        card('Q'),
        card('K'),
        card('A'),
        card('2'),
        card('3'),        
      ];
      expect(ruleSet.validateMove(move), isFalse);
    });

    test('Gültige Sequenz mit Ass am Ende', () {
      final move = [
        card('Q'),
        card('K'),
        card('A')
      ];
      expect(ruleSet.validateMove(move), isTrue);
    });

    test('Ungültige Sequenz mit 2 in der Mitte', () {
      final move = [
        card('A'),
        card('2'),
        card('3')
      ];
      expect(ruleSet.validateMove(move), isFalse);
    });

    test('Gültige Sequenz mit 2 am Anfang', () {
      final move = [
        card('2'),
        card('3'),
        card('4')
      ];
      expect(ruleSet.validateMove(move), isTrue);
    });

  });
}
