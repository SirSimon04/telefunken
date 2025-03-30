class CardEntity {
  final String suit;
  final String rank;
  bool isUp;

  CardEntity({required this.suit, required this.rank, this.isUp = false});

  @override
  String toString() {
    return suit + rank;
  }

  // Konvertiere CardEntity in Map
  Map<String, dynamic> toMap() {
    return {
      'suit': suit,
      'rank': rank,
      'isUp': isUp,
    };
  }

  // Erstelle CardEntity aus Map
  factory CardEntity.fromMap(Map<String, dynamic> map) {
    return CardEntity(
      suit: map['suit'] as String,
      rank: map['rank'] as String,
      isUp: map['isUp'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardEntity && runtimeType == other.runtimeType && suit == other.suit && rank == other.rank;

  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;
}
