import 'card_entity.dart';

class Player {
  final String id;
  final String name;
  final bool isAI;

  bool out = false;
  bool hasDrawn = false;
  List<CardEntity> hand = [];
  int coins = 0;
  int points = 0;

  Player({required this.id, required this.name, this.isAI = false, this.out = false, this.hasDrawn = false});

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
      'hasDrawn': hasDrawn,
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
      ..out = map['isOut'] as bool? ?? false
      ..hasDrawn = map['hasDrawn'] as bool? ?? false
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

  void setOut(bool out) {
    this.out = out;
  }

  bool isOut() {
    return out;
  }

  int getCoins() {
    return coins;
  }

  void removeCoin() {
    coins --;
  }

  int getPoints(){
    return points;
  }

  void addPoints(int points){
    this.points += points;
  }

  void setDrawed(bool drawed) { // Keep this if used elsewhere, but prefer setHasDrawn
    this.hasDrawn = drawed;
  }

  // Rename hasDrawed() to hasDrawn()
  bool getHasDrawn() {
    return hasDrawn; // Use the renamed field
  }
}
