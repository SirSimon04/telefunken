class CardEntity {
  final String suit;
  final String rank;
  bool isUp;

  CardEntity({required this.suit, required this.rank, this.isUp = false});

  @override
  String toString() {
    return suit + rank;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardEntity && runtimeType == other.runtimeType && suit == other.suit && rank == other.rank;

  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;
}
