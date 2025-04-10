class CardEntity {
  final String suit;
  final String rank;

  CardEntity({required this.suit, required this.rank});

  @override
  String toString() {
    return suit + rank;
  }

  // Konvertiere CardEntity in Map
  Map<String, dynamic> toMap() {
    return {
      'suit': suit,
      'rank': rank,
    };
  }

  // Erstelle CardEntity aus Map
  factory CardEntity.fromMap(Map<String, dynamic> map) {
    return CardEntity(
      suit: map['suit'] as String,
      rank: map['rank'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardEntity && runtimeType == other.runtimeType && suit == other.suit && rank == other.rank;

  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;

  static fromJson(drawData) {
    return CardEntity(
      suit: drawData['suit'] as String,
      rank: drawData['rank'] as String,
    );
  }
}
