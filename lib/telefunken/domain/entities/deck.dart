import 'card_entity.dart';

class Deck {
  final List<CardEntity> cards = [];

  Deck() {
    final suits = ['H', 'D', 'C', 'S'];
    final ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
    
    List<CardEntity> singleSet = [];
    for (var suit in suits) {
      for (var rank in ranks) {
        singleSet.add(CardEntity(suit: suit, rank: rank, isUp: false));
      }
    }
    // Zwei Joker hinzufügen
    singleSet.add(CardEntity(suit: "Joker", rank: "", isUp: false));
    singleSet.add(CardEntity(suit: "Joker", rank: "2", isUp: false));

    // Zwei Sets ergeben insgesamt 108 Karten
    cards.addAll(singleSet);
    cards.addAll(singleSet);
  }

  void shuffle() {
    cards.shuffle();
  }

  List<CardEntity> deal(int count) {
    final dealtCards = cards.sublist(0, count);
    cards.removeRange(0, count);
    return dealtCards;
  }

  int getLength() {
    return cards.length;
  }
}
