import 'card_entity.dart';

class Player {
  final int id;
  final String name;
  final bool isAI;

  late bool isOut;
  List<CardEntity> hand = [];

  Player({required this.id, required this.name, this.isAI = false, this.isOut = false});

  void addCardToHand(CardEntity card) {
    card.isUp = true; // Karte aufdecken, wenn sie zur Hand des Spielers hinzugefügt wird
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
}
