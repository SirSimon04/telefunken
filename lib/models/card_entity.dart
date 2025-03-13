enum Suit { hearts, diamonds, clubs, spades, joker }
enum Rank { two, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace, joker }

class CardEntity {
  final Suit suit;
  final Rank rank;

  CardEntity({required this.suit, required this.rank});

  @override
  String toString() => '${rank.name} of ${suit.name}';
}
