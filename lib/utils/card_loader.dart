import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';

class CardLoader {
  static final Map<String, Sprite> _cardSprites = {};

  static Future<void> loadCards() async {
    final suits = ['H', 'D', 'C', 'S'];
    final ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];

    for (var suit in suits) {
      for (var rank in ranks) {
        final imageName = 'cards/$suit$rank.png';
        final image = await Flame.images.load(imageName);
        _cardSprites['$suit$rank'] = Sprite(image);
      }
    }
    final jokerAndBackground = await Flame.images.loadAll(['cards/Joker.png','cards/Joker2.png', 'cards/Back_Red.png']);
    //add JokerAndBackground to the map
    _cardSprites['Joker'] = Sprite(jokerAndBackground[0]);
    _cardSprites['Joker2'] = Sprite(jokerAndBackground[1]);
    _cardSprites['Back_Red'] = Sprite(jokerAndBackground[2]);
  }

  static Sprite getCardSprite(String suit, String rank) {
    return _cardSprites['$suit$rank']!;
  }
}