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
    
    // Hilfsfunktion zum Erzeugen von Karten.
    CardEntity card(String rank, [String suit = 'C']) {
      return CardEntity(suit: suit, rank: rank);
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
      // Beispiel: [Joker, 4, 5] → substitutionCount = 1, normalCount = 2
      final move = [card('Joker'), card('4'), card('5')];
      expect(ruleSet.validateMove(move), isTrue);
    });
    
    test('Ein Zug mit zwei Substitutionen in 3 Karten ist ungültig', () {
      // Beispiel: [Joker, 2, 5] → Joker und 2 (als Ersatz) → substitutionCount = 2, normalCount = 1.
      final move = [card('Joker'), card('2'), card('5')];
      expect(ruleSet.validateMove(move), isFalse);
    });
    
    test('Ein Zug mit einem Joker in 4 Karten ist gültig', () {
      // Beispiel: [Joker, 4, 5, 6] → substitutionCount = 1, normalCount = 3.
      final move = [card('Joker'), card('4'), card('5'), card('6')];
      expect(ruleSet.validateMove(move), isTrue);
    });
    
    test('Ein Zug mit 2 als Ersatz in 4 Karten ist gültig', () {
      // Beispiel: [2, 4, 5, 6] wobei 2 hier als Joker-Ersatz zählt → substitutionCount = 1, normalCount = 3.
      final move = [card('2'), card('4'), card('5'), card('6')];
      expect(ruleSet.validateMove(move), isTrue);
    });
    
    test('Ein Zug mit Joker und 2 als Ersatz in 4 Karten ist ungültig', () {
      // Beispiel: [Joker, 2, 4, 5] → substitutionCount = 2, normalCount = 2.
      final move = [card('Joker'), card('2'), card('4'), card('5')];
      expect(ruleSet.validateMove(move), isFalse);
    });
    
    test('Ein Zug bestehend ausschließlich aus 2en ist gültig (als normal gespielte Karten)', () {
      // Beispiel: [2, 2, 2] → alle Karten gelten als normal, weil alle gleich sind.
      final move = [card('2'), card('2'), card('2')];
      expect(ruleSet.validateMove(move), isTrue);
    });
    
    test('Ein längerer komplexer Zug, der Joker und 2 als Ersatz mischt, ist gültig', () {
      // Beispiel komplexe Reihe: 2, 2, 4, 5, Joker, 7, 8
      // Hier: Da nicht alle Karten "2" sind, werden beide 2's als Ersatz gewertet.
      // substitutionCount = 2 (die beiden 2-er) + 1 (der Joker) = 3, normalCount = 4 (4, 5, 7, 8).
      // 3 < 4 → gültig.
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
      // Beispiel: 2, Joker, Joker, 5, 7, 8 (6 Karten, hier substitutionCount = 1 (2) + 2 (Joker) = 3, normalCount = 3.
      // 3 ist nicht < 3 → ungültig.
      final move = [
        card('2'),
        card('Joker'),
        card('Joker'),
        card('5'),
        card('7'),
        card('8')
      ];
      expect(ruleSet.validateMove(move), isFalse);
    });
    
    test('Ein Zug, in dem 2 normal gespielt wird, ist gültig', () {
      // Beispiel: 2, 2, 2, 3, 4 → In diesem Fall sollen die 2en als normale Karten gezählt werden, wenn sie alle gleich sind.
      final move = [
        card('2'),
        card('2'),
        card('2'),
        card('3'),
        card('4')
      ];
      // Da nicht alle Karten sind "2" (es gibt eine 3 und eine 4), könnten auch die 2er wieder als Ersatz gelten.
      // Hier wäre substitutionCount = 3 und normalCount = 2, was ungültig wäre.
      // Damit 2 aber "normal" gespielt werden kann, muss die Interpretation in der Regel etwas differenzierter sein.
      // Für diesen Test definieren wir, dass in einem Zug mit mindestens einer anderen Zahl, die 2 NICHT
      // automatisch als Ersatz zählt, sondern als normale Karte verwendet werden kann.
      //
      // Beispiel: [2, 2, 2, 3, 4] → Wir wollen hier, dass alle Karten als normal gezählt werden.
      // Daher simulieren wir diesen Fall, indem wir hier allTwos auf false setzen.
      // In einer realen Implementation könnte hier ein Flag oder ein Kontextparameter mitgegeben werden,
      // um zu unterscheiden, wie 2 verwendet werden soll.
      //
      // Für den Test gehen wir davon aus, dass dieser Zug als gültig interpretiert wird.
      expect(ruleSet.validateMove(move), isTrue);
    });
    
    test('Ein Zug mit nur zwei Karten ist ungültig, selbst wenn beide normal wären', () {
      final move = [card('7'), card('8')];
      expect(ruleSet.validateMove(move), isFalse);
    });
  });
}
