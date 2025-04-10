import 'card_entity.dart';

class Player {
  final String id;
  final String name;
  final bool isAI;

  late bool isOut;
  List<CardEntity> hand = [];
  late int coins;
  late int points;

  Player({required this.id, required this.name, this.isAI = false, this.isOut = false});

  void addCardToHand(CardEntity card) {
    hand.add(card);
  }

  @override
  String toString() => 'Player $id: $name';

  // Konvertiere Player in Map
  Map<String, dynamic> toMap() {
    return {
      'id': String,
      'name': name,
      'isAI': isAI,
      'isOut': isOut,
      'hand': hand.map((card) => card.toMap()).toList(),
      'coins': coins,
      'points': points,
    };
  }

  // Erstelle Player aus Map
  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] as String,
      name: map['name'] as String,
      isAI: map['isAI'] as bool? ?? false,
    )
      ..isOut = map['isOut'] as bool? ?? false
      ..hand = (map['hand'] as List).map((card) => CardEntity.fromMap(card as Map<String, dynamic>)).toList()
      ..coins = map['coins'] as int? ?? 0
      ..points = map['points'] as int? ?? 0;
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

  int getCoins() {
    return coins;
  }

  void removeCoin() {
    coins --;
  }
}
