import 'card_entity.dart';

class Player {
  final int id;
  final String name;
  final bool isAI;

  late bool isOut;
  List<CardEntity> hand = [];
  late int coins;
  late int points;

  Player({required this.id, required this.name, this.isAI = false, this.isOut = false});

  void addCardToHand(CardEntity card) {
    card.isUp = true;
    hand.add(card);
  }

  @override
  String toString() => 'Player $id: $name';

  factory Player.fromMap(Map<String, dynamic> data) {
    return Player(
      id: data['id'],
      name: data['name'],
      isAI: data['isAI'],
    );
  }

  void removeCardFromHand(CardEntity card) {
    hand.remove(card);
  }

  void removeCardsFromHand(List<CardEntity> cards) {
    for (var card in cards) {
      hand.remove(card);
    }
  }

  void clearHand() {
    hand.clear();
  }

  void setOut() {
    isOut = true;
  }
}
