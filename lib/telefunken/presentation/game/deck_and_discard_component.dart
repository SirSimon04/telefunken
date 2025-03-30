// import 'package:flame/components.dart';
// import 'package:flame/events.dart';
// import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
// import 'package:telefunken/telefunken/domain/logic/game_logic.dart';

// class DeckAndDiscardComponent extends SpriteComponent with TapCallbacks{

//   final int playerId;
//   final bool isDeck;
//   final Function onTap;
//   final CardEntity card;
//   final GameLogic gameLogic;

//   DeckAndDiscardComponent({
//     required this.playerId,
//     required this.isDeck,
//     required this.onTap,
//     required this.card,
//     required this.gameLogic,
//   });

//   @override
//   Future<void> onLoad() async {
//     await super.onLoad();
//     sprite = await Sprite.load(isDeck ? 'deck.png' : '${card.suit}${card.rank}.png');
//     size = Vector2(50, 75);
//     anchor = Anchor.center;
//   }

//   @override
//   void onTap() {
//     if(gameLogic.isPlayersTurn(playerId)){

//     }
//   }

//   @override
//   void onLongPress() {
//     onLongPress(playerId);
//   }
// }