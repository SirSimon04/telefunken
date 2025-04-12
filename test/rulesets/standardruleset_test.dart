import 'package:flutter_test/flutter_test.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
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

    test('Joker, 2, 2', (){
      final move = [card('Joker'), card('2'), card('2')];
      expect(ruleSet.validateMove(move), isTrue);
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

    test('Lange Sequenz', () {
      final move = [
        card('3'),
        card('4'),
        card('5'),
        card('6'),
        card('7'),
        card('8'),
        card('9'),
        card('10'),
        card('J'),
      ];
      expect(ruleSet.validateMove(move), isTrue);
    });

    test('Lange Sequenz mit Jokern', () {
      final move = [
        card('3'),
        card('2'),
        card('Joker'),
        card('6'),
        card('7'),
        card('8'),
        card('Joker'),
        card('10'),
        card('J'),
      ];
      expect(ruleSet.validateMove(move), isTrue);
    });

  });

group('Round Validation', () {
    late StandardRuleSet ruleSet;

    setUp(() {
      ruleSet = StandardRuleSet();
    });

    CardEntity card(String rank, [String suit = 'C']) {
      return rank.startsWith('Joker')
          ? CardEntity(suit: '', rank: 'Joker')
          : CardEntity(suit: suit, rank: rank);
    }

    /// Runde 1: zwei Dreier Paare benötigt
    test('Runde 1: Gültig, wenn zwei Dreierpaare vorhanden sind', () {
      final move1 = [card('4'), card('4'), card('4')];
      final move2 = [card('7'), card('7'), card('7')];
      expect(ruleSet.validateRoundCondition([move1, move2], 1), isTrue);
    });

    test('Runde 1: Ungültig, wenn nur ein Dreierpaar vorhanden ist', () {
      final move1 = [card('4'), card('4'), card('4')];
      expect(ruleSet.validateRoundCondition([move1], 1), isFalse);
    });

    /// Runde 2: ein Viererpack benötigt
    test('Runde 2: Gültig, wenn ein Viererpack vorhanden ist', () {
      final move = [card('4'), card('4'), card('4'), card('4')];
      expect(ruleSet.validateRoundCondition([move], 2), isTrue);
    });

    test('Runde 2: Ungültig, wenn kein Viererpack vorhanden ist', () {
      final move = [card('4'), card('4'), card('4')];
      expect(ruleSet.validateRoundCondition([move], 2), isFalse);
    });

    /// Runde 3: zwei Vierer Paare
    test('Runde 3: Gültig, wenn zwei Viererpaare vorhanden sind', () {
      final move1 = [card('4'), card('4'), card('4'), card('4')];
      final move2 = [card('7'), card('7'), card('7'), card('7')];
      expect(ruleSet.validateRoundCondition([move1, move2], 3), isTrue);
    });

    test('Runde 3: Ungültig, wenn nur ein Viererpaar vorhanden ist', () {
      final move1 = [card('4'), card('4'), card('4'), card('4')];
      expect(ruleSet.validateRoundCondition([move1], 3), isFalse);
    });

    /// Runde 4: ein Fünfer-Paar
    test('Runde 4: Gültig, wenn ein Fünferpack vorhanden ist', () {
      final move = [card('4'), card('4'), card('4'), card('4'), card('4')];
      expect(ruleSet.validateRoundCondition([move], 4), isTrue);
    });

    test('Runde 4: Ungültig, wenn kein Fünferpack vorhanden ist', () {
      final move = [card('4'), card('4'), card('4'), card('4')];
      expect(ruleSet.validateRoundCondition([move], 4), isFalse);
    });

    /// Runde 5: zwei Fünfer-Paare
    test('Runde 5: Gültig, wenn zwei Fünferpaare vorhanden sind', () {
      final move1 = [card('4'), card('4'), card('4'), card('4'), card('4')];
      final move2 = [card('7'), card('7'), card('7'), card('7'), card('7')];
      expect(ruleSet.validateRoundCondition([move1, move2], 5), isTrue);
    });

    test('Runde 5: Ungültig, wenn nur ein Fünferpaar vorhanden ist', () {
      final move1 = [card('4'), card('4'), card('4'), card('4'), card('4')];
      expect(ruleSet.validateRoundCondition([move1], 5), isFalse);
    });

    /// Runde 6: ein Sechser-Paar
    test('Runde 6: Gültig, wenn ein Sechserpack vorhanden ist', () {
      final move = [
        card('4'),
        card('4'),
        card('4'),
        card('4'),
        card('4'),
        card('4')
      ];
      expect(ruleSet.validateRoundCondition([move], 6), isTrue);
    });

    test('Runde 6: Ungültig, wenn kein Sechserpack vorhanden ist', () {
      final move = [card('4'), card('4'), card('4'), card('4'), card('4')];
      expect(ruleSet.validateRoundCondition([move], 6), isFalse);
    });

    /// Runde 7: eine Siebener-Sequenz
    test('Runde 7: Gültig, wenn eine Siebenersequenz vorhanden ist', () {
      final move = [
        card('2'),
        card('3'),
        card('4'),
        card('5'),
        card('6'),
        card('7'),
        card('8')
      ];
      expect(ruleSet.validateRoundCondition([move], 7), isTrue);
    });

    test('Runde 7: Ungültig, wenn keine Siebenersequenz vorhanden ist', () {
      final move = [
        card('2'),
        card('3'),
        card('4'),
        card('5'),
        card('6'),
        card('7')
      ];
      expect(ruleSet.validateRoundCondition([move], 7), isFalse);
    });
  });
}
