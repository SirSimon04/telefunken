import 'card_entity.dart';

class Deck {
  final List<CardEntity> cards = [];

  Deck() {
    // Baue ein einzelnes Poker-Set: 52 Karten + 2 Joker
    List<CardEntity> singleSet = [];
    for (var suit in [Suit.hearts, Suit.diamonds, Suit.clubs, Suit.spades]) {
      for (var rank in [
        Rank.two, Rank.three, Rank.four, Rank.five, Rank.six, Rank.seven,
        Rank.eight, Rank.nine, Rank.ten, Rank.jack, Rank.queen, Rank.king, Rank.ace
      ]) {
        singleSet.add(CardEntity(suit: suit, rank: rank));
      }
    }
    // Zwei Joker hinzufügen
    singleSet.add(CardEntity(suit: Suit.joker, rank: Rank.joker));
    singleSet.add(CardEntity(suit: Suit.joker, rank: Rank.joker));

    // Zwei Sets ergeben insgesamt 108 Karten
    cards.addAll(singleSet);
    cards.addAll(singleSet);
  }

  void shuffle() {
    cards.shuffle();
  }

  
  CardEntity deal(int count) {
    final dealtCards = cards.sublist(0, count);
    cards.removeRange(0, count);
    return dealtCards.first;
  }
}
