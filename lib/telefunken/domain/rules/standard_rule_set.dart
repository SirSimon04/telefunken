import 'rule_set.dart';
import '../entities/deck.dart';
import '../entities/player.dart';
import '../entities/card_entity.dart';

class StandardRuleSet extends RuleSet {
  @override
  void initializeGame(List<Player> players, Deck deck) {
    // Mische das Deck und teile Karten aus
    deck.shuffle();
    int cardsToDeal = players.length * 11 + 1; // 12 Karten für den ersten Spieler, 11 für die anderen
    dealCards(players, deck, cardsToDeal);
  }

  void dealCards(List<Player> players, Deck deck, int cardsToDeal) {
    int playerIndex = 0;
    for (int i = 0; i < cardsToDeal; i++) {
      Player currentPlayer = players[playerIndex];
      CardEntity card = deck.dealOne();
      currentPlayer.addCardToHand(card);
      playerIndex = (playerIndex + 1) % players.length;
    }
  }

  bool validateInitialMove(List<CardEntity> cards, int roundNumber) {
    // Überprüfe die Anforderungen für die aktuelle Runde
    switch (roundNumber) {
      case 1:
        return _validatePairs(cards, 3, 2); // Zwei 3er-Paare
      case 2:
        return _validatePairs(cards, 4, 1); // Ein 4er-Paar
      case 3:
        return _validatePairs(cards, 4, 2); // Zwei 4er-Paare
      case 4:
        return _validatePairs(cards, 5, 1); // Ein 5er-Paar
      case 5:
        return _validatePairs(cards, 5, 2); // Zwei 5er-Paare
      case 6:
        return _validatePairs(cards, 6, 1); // Ein 6er-Paar
      case 7:
        return _validateSequence(cards, 7); // Eine 7er-Reihe
      default:
        return false;
    }
  }

  bool _validatePairs(List<CardEntity> cards, int pairSize, int pairCount) {
    Map<String, int> rankCounts = {};
    int jokerCount = cards.where((card) => card.rank == 'Joker' || card.rank == '2').length;

    for (var card in cards) {
      if (card.rank != 'Joker' && card.rank != '2') {
        rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
      }
    }

    int validPairs = 0;

    for (var count in rankCounts.values) {
      while (count + jokerCount >= pairSize) {
        validPairs++;
        if (count >= pairSize) {
          count -= pairSize;
        } else {
          jokerCount -= (pairSize - count);
          count = 0;
        }
      }
    }

    while (jokerCount >= pairSize) {
      validPairs++;
      jokerCount -= pairSize;
    }

    return validPairs >= pairCount;
  }
  bool _validateSequence(List<CardEntity> cards, int sequenceLength) {
    if (cards.length != sequenceLength) return false;

    List<int> ranks = cards.map((card) => _rankToInt(card.rank)).toList();
    ranks.sort();

    int jokerCount = cards.where((card) => card.rank == 'Joker' || card.rank == '2').length;
    int gaps = 0;

    for (int i = 1; i < ranks.length; i++) {
      if (ranks[i] != ranks[i - 1] + 1) {
        gaps += (ranks[i] - ranks[i - 1] - 1);
      }
    }

    return gaps <= jokerCount;
  }

  int _rankToInt(String rank) {
    const rankOrder = {
      '2': 2,
      '3': 3,
      '4': 4,
      '5': 5,
      '6': 6,
      '7': 7,
      '8': 8,
      '9': 9,
      '10': 10,
      'J': 11,
      'Q': 12,
      'K': 13,
      'A': 14,
      'Joker': 0, // Joker als 0 behandeln
    };
    return rankOrder[rank] ?? 0;
  }

  bool validateDiscard(CardEntity card) {
    // Überprüfe, ob die Karte auf den Ablagestapel gelegt werden darf
    if (card.rank == 'Joker' || card.rank == '2') {
      return false; // Joker und 2 dürfen nicht abgelegt werden
    }
    return true;
  }

  bool validateMove(List<CardEntity> cards) {
    // Überprüfe, ob die Karten mindestens drei nebeneinander sind
    if (cards.length < 3) return false;

    int jokerCount = cards.where((card) => card.rank == 'Joker' || card.rank == '2').length;
    int nonJokerCount = cards.length - jokerCount;

    return jokerCount < nonJokerCount; // Es müssen mehr echte Karten als Joker sein
  }
}
