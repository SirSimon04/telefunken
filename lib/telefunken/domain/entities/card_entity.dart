class CardEntity {
  final String suit;
  final String rank;
  bool isUp;

  CardEntity({required this.suit, required this.rank, this.isUp = false});

  @override
  String toString() {
    return suit + rank;
  }


}
