import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/domain/logic/game_logic.dart';

// class CardComponent extends PositionComponent {
//   final CardEntity card;
//   final GameLogic? gameLogic;
//   final void Function(CardEntity)? onCardTapped;

//   CardComponent({required this.card, this.onCardTapped, this.gameLogic});

//   @override
//   bool onTap(TapDownEvent event) {
//     if (gameLogic!.isPlayersTurn(gameLogic!.players[gameLogic!.currentPlayerIndex].id)) {
//       onCardTapped?.call(card);
//       return true;
//     }
//     return false;
//   }

//   @override
//   void render(Canvas canvas) {
//     final paint = Paint()..color = Colors.blue;
//     final rect = Rect.fromLTWH(0, 0, 50, 75);
//     canvas.drawRect(rect, paint);

//     final textPainter = TextPainter(
//       text: TextSpan(text: card.toString(), style: TextStyle(color: Colors.white, fontSize: 10)),
//       textDirection: TextDirection.ltr,
//     );
//     textPainter.layout();
//     textPainter.paint(canvas, Offset(5, 5));
//   }
// }

//Das hier ergibt gerade keinen Sinn!!