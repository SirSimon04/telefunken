import 'card_entity.dart';

class Deck {
  final List<CardEntity> cards = [];

  final suits = ['H', 'D', 'C', 'S'];
  final ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];

  Deck() {
    createDeck();
  }

  void createDeck(){
    List<CardEntity> singleSet = [];
    for (var suit in suits) {
      for (var rank in ranks) {
        singleSet.add(CardEntity(suit: suit, rank: rank));
      }
    }
    // Zwei Joker hinzufügen
    singleSet.add(CardEntity(suit: "", rank: "Joker"));
    singleSet.add(CardEntity(suit: "", rank: "Joker2"));

    // Zwei Sets ergeben insgesamt 108 Karten
    cards.addAll(singleSet);
    cards.addAll(singleSet);
  }

  void shuffle() {
    cards.shuffle();
  }

  List<CardEntity> dealCards(int count) {
    final dealtCards = cards.sublist(0, count);
    cards.removeRange(0, count);
    return dealtCards;
  }

  CardEntity dealOne() {
    final dealtCard = cards.first;
    cards.removeAt(0);
    return dealtCard;
  }

  void reset(){
    cards.clear();
    createDeck();
  }

  int getLength() {
    return cards.length;
  }
  
  bool isEmpty() {
    return cards.isEmpty;
  }
}
