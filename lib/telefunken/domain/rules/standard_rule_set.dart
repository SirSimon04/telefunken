import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/domain/rules/rule_set.dart';

class StandardRuleSet extends RuleSet {
  @override
  bool validateDiscard(CardEntity card) => true;

  @override
  bool validateMove(List<CardEntity> cards) {
    if (cards.length < 3) return false;
    return _isValidGroup(cards) || _isValidSequence(cards);
  }

  // ---------------------------
  // -------- GROUP CHECK -------
  // ---------------------------
  bool _isValidGroup(List<CardEntity> cards) {
    final targetRank = _getGroupTargetRank(cards);
    if (targetRank == null) return false;

    final wild = cards.where((c) => _isGroupWildcard(c, targetRank)).length;
    final normalCount = cards.length - wild;
    if (normalCount <= 0 || wild >= normalCount) return false;
    return true;
  }

  String? _getGroupTargetRank(List<CardEntity> cards) {
    final normalCards = cards.where((c) => !_isGroupWildcard(c, null)).toList();
    if (normalCards.isEmpty) {
      return cards.every((c) => c.rank == '2') ? '2' : null;
    }
    final rank = normalCards.first.rank;
    return normalCards.every((c) => c.rank == rank) ? rank : null;
  }

  bool _isGroupWildcard(CardEntity c, String? targetRank) {
    if (c.rank.startsWith('Joker')) return true;
    if (c.rank == '2' && targetRank != '2') return true;
    return false;
  }

  // ---------------------------
  // ------ SEQUENCE CHECK ------
  // ---------------------------
  bool _isValidSequence(List<CardEntity> cards) {
    if (cards.length < 3) return false;
    if (_isHighSequenceWithAce(cards)) {
      final w = cards.where((c) => _isSequenceWildcard(c, cards)).length;
      return w < (cards.length - w);
    }
    return _any2ArrangementYieldsSequence(cards);
  }

  bool _isHighSequenceWithAce(List<CardEntity> cards) {
    if (cards.length != 3) return false;
    final set = cards.map((c) => c.rank).toSet();
    return set.length == 4 && set.containsAll(['Q','K','A']);
  }

  bool _isSequenceWildcard(CardEntity c, List<CardEntity> allCards) {
    if (c.rank.startsWith('Joker')) return true;
    if (c.rank == '2') {
      return !_formsValidSequenceWith2AsNormal(allCards, c);
    }
    return false;
  }

  /// Testet alle Kombinationsmöglichkeiten, welche '2' als normal verwendet werden.
  bool _any2ArrangementYieldsSequence(List<CardEntity> cards) {
    final indices = <int>[];
    for (int i=0; i<cards.length; i++) {
      if (cards[i].rank=='2' && !cards[i].rank.startsWith('Joker')) {
        indices.add(i);
      }
    }
    if (indices.isEmpty) return _checkSequenceArrangement(cards, const []);
    final combos = 1 << indices.length;
    for (int mask=0; mask<combos; mask++) {
      final normal2 = <int>[];
      for (int b=0; b<indices.length; b++) {
        if ((mask & (1<<b)) != 0) normal2.add(indices[b]);
      }
      if (_checkSequenceArrangement(cards, normal2)) return true;
    }
    return false;
  }

  /// Prüft die Karten in *gegebener Reihenfolge*, ob eine lückenlose Sequenz entsteht.
  bool _checkSequenceArrangement(List<CardEntity> cards, List<int> normal2Indices) {
    // Anzug prüfen
    if (!_checkSuitOfNormals(cards, normal2Indices)) return false;

    // Karten in Rangliste verwandeln, null = Wildcard
    final ranksInOrder = <int?>[];
    for (int i = 0; i < cards.length; i++) {
      final c = cards[i];
      if (c.rank.startsWith('Joker') || (c.rank == '2' && !normal2Indices.contains(i))) {
        ranksInOrder.add(null);
      } else {
        ranksInOrder.add(_rankToValue(c.rank));
      }
    }

    final normalCount = ranksInOrder.where((r) => r != null).length;
    final wildCount = cards.length - normalCount;
    if (normalCount + wildCount < 3) return false;
    if (normalCount == 0) return false;
    if (wildCount >= normalCount) return false;

    // Wir gehen von links nach rechts; Wildcards wirken nur dort, wo sie liegen.
    int? lastRank;
    int lastNormalIndex = -1;

    for (int i = 0; i < ranksInOrder.length; i++) {
      final currRank = ranksInOrder[i];
      if (currRank == null) {
        // Joker oder '2' als Wildcard - überspringen wir hier
        continue;
      }
      if (lastRank == null) {
        lastRank = currRank;
        lastNormalIndex = i;
      } else {
        // Gap zwischen dieser Karte und letzter normaler Karte berechnen
        if (currRank <= lastRank) return false;
        final gap = currRank - lastRank - 1;

        // Wie viele Wildcards liegen zwischen den beiden Normalen?
        final availableWildcards = _countNullsBetween(ranksInOrder, lastNormalIndex, i);
        if (gap > availableWildcards) return false;

        lastRank = currRank;
        lastNormalIndex = i;
      }
    }

    return true;
  }

  // Zählt null-Einträge (Wildcards) zwischen zwei Indizes exklusiv
  int _countNullsBetween(List<int?> list, int start, int end) {
    int count = 0;
    for (int i = start + 1; i < end; i++) {
      if (list[i] == null) count++;
    }
    return count;
  }

  /// Hier prüfen wir die Farbe nur der als normal angesehenen Karten.
  bool _checkSuitOfNormals(List<CardEntity> cards, List<int> normal2Indices) {
    final normalCards = <CardEntity>[];
    for (int i=0; i<cards.length; i++) {
      final c = cards[i];
      if (c.rank.startsWith('Joker')) continue;
      if (c.rank=='2' && !normal2Indices.contains(i)) continue;
      normalCards.add(c);
    }
    if (normalCards.isEmpty) return true;
    final s = normalCards.first.suit;
    return normalCards.every((c) => c.suit==s);
  }

  /// Prüft nur, ob '2' in passender Farbe mitspielen könnte (sonst wird sie Wildcard).
  bool _formsValidSequenceWith2AsNormal(List<CardEntity> testCards, CardEntity the2) {
    final s = _getSequenceSuitIf2IsNormal(testCards, the2);
    return s!=null;
  }

  String? _getSequenceSuitIf2IsNormal(List<CardEntity> cards, CardEntity the2) {
    final normalCards = cards.where((c) => 
      !c.rank.startsWith('Joker')
      && !(c.rank=='2' && c!=the2)
    );
    if (normalCards.isEmpty) return null;
    final firstSuit = normalCards.first.suit;
    return normalCards.every((c) => c.suit==firstSuit) ? firstSuit : null;
  }

  int _rankToValue(String r) {
    const m = {
      '2':2,'3':3,'4':4,'5':5,'6':6,'7':7,'8':8,
      '9':9,'10':10,'J':11,'Q':12,'K':13,'A':14
    };
    return m[r] ?? 0;
  }

  @override
  bool validateRoundCondition(List<List<CardEntity>> cards, int roundNumber) {
    return true;
  }
}