import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/card_loader.dart';
import 'dart:math' as math;
class HomeScreen extends FlameGame {
  @override
  Future<void> onLoad() async {
    await Flame.images.load('background.png');
    await CardLoader.loadCards();

    // Hintergrundbild hinzufügen
    add(SpriteComponent()
      ..sprite = await loadSprite('background.png')
      ..size = size);

    // Titel hinzufügen
    add(TextComponent(
      text: 'Welcome to Telefunken',
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 24, color: Colors.white),
      ),
      position: Vector2(size.x / 2, 100),
      anchor: Anchor.center,
    ));


    addCardsToScreen();
  }


  void addCardsToScreen(){
    final suits = ['H', 'C', 'S', 'D'];
    final position = Vector2(size.x / 2 - 50, 200);
    final rotation = [-0.2, 0.0, 0.1, 0.2];
    for (int i = 0; i < suits.length; i++) {
      add(SpriteComponent()
        ..sprite = CardLoader.getCardSprite(suits[i], "2")
        ..anchor = Anchor.center
        ..position = position + Vector2(i * 20, 0)  // Leichter x-Versatz
        ..angle = rotation[i]
        ..size = Vector2(50, 70));
    }
    for (int i = 0; i < suits.length; i++) {
      if(i == 3){
          add(SpriteComponent()
          ..sprite = CardLoader.getCardSprite("Joker", "")
          ..anchor = Anchor.center
          ..position = position + Vector2(i * 20 +100, 100)  // Leichter x-Versatz
          ..angle = rotation[i]
          ..size = Vector2(50, 70));
      }else{
        add(SpriteComponent()
          ..sprite = CardLoader.getCardSprite(suits[i], "K")
          ..anchor = Anchor.center
          ..position = position + Vector2(i * 20 +100, 100)
          ..angle = rotation[i]
          ..size = Vector2(50, 70));
      }
    }

    final pivot = Vector2(size.x / 2 - 100, 375);
    final radius = 100.0;
    final angleStart = -0.1;
    final angleEnd = 0.6;
    for (int i = 0; i < 7; i++) {
      final t = (i / 6);
      final angle = angleStart + (angleEnd - angleStart) * t;

      final offsetX = radius * math.sin(angle);
      final offsetY = radius * (1 - math.cos(angle));


      if(i==3){
        add(SpriteComponent()
          ..sprite = CardLoader.getCardSprite('Joker', '')
          ..anchor = Anchor.bottomCenter
          ..position = pivot + Vector2(offsetX, offsetY)
          ..angle = angle
          ..size = Vector2(50, 70));
      }else{
        add(SpriteComponent()
          ..sprite = CardLoader.getCardSprite('S', (i+2).toString())
          ..anchor = Anchor.bottomCenter
          ..position = pivot + Vector2(offsetX, offsetY)
          ..angle = angle
          ..size = Vector2(50, 70));
      }
    }
    //overlays.add('MainMenu');
  }
}