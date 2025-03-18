import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../utils/card_loader.dart';
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
    // Karten hinzufügen
    

    // Buttons hinzufügen
    final buttonLabels = ['Join a Game', 'Host a Game', 'Play Offline', 'Settings'];
    final buttonActions = [joinGame, hostGame, playOffline, settings];
    for (int i = 0; i < buttonLabels.length; i++) {
      add(ButtonComponent(
      text: buttonLabels[i],
      position: Vector2(size.x / 2 - 100, size.y / 2 + 100 + i * 50),
      onPressed: buttonActions[i],
      ));
    }
  }

  void joinGame(){
    print('Join a Game');
  }
  void hostGame(){
    print('Host a Game');
  }
  void playOffline(){
    print('Play Offline');
  }
  void settings(){
    print('Settings');
  }

  void addCardsToScreen(){
    final suits = ['H', 'C', 'S', 'D'];
    final position = Vector2(size.x / 2 - 100, 200);
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
          ..position = position + Vector2(i * 20 +150, 0)  // Leichter x-Versatz
          ..angle = rotation[i]
          ..size = Vector2(50, 70));
      }else{
        add(SpriteComponent()
          ..sprite = CardLoader.getCardSprite(suits[i], "K")
          ..anchor = Anchor.center
          ..position = position + Vector2(i * 20 +150, 0)
          ..angle = rotation[i]
          ..size = Vector2(50, 70));
      }
    }

    final pivot = Vector2(size.x / 2, 250);
    final radius = 100.0;
    final angleStart = -0.5;
    final angleEnd = 0.5;
    for (int i = 0; i < 7; i++) {
      final t = (i / 6);
      final angle = angleStart + (angleEnd - angleStart) * t;

      final offsetX = radius * math.sin(angle);
      final offsetY = radius * math.cos(angle);

      if(i==3){
        add(SpriteComponent()
          ..sprite = CardLoader.getCardSprite('Joker', '')
          ..anchor = Anchor.center
          ..position = pivot + Vector2(offsetX, offsetY)
          ..angle = -angle
          ..size = Vector2(50, 70));
      }else{
        add(SpriteComponent()
          ..sprite = CardLoader.getCardSprite('S', (i+2).toString())
          ..anchor = Anchor.center
          ..position = pivot + Vector2(offsetX, offsetY)
          ..angle = -angle
          ..size = Vector2(50, 70));
      }
    }
  }
}

class ButtonComponent extends PositionComponent with TapCallbacks {
  final String text;
  final VoidCallback onPressed;

  ButtonComponent({
    required this.text,
    required Vector2 position,
    required this.onPressed,
  }) {
    this.position = position;
    size = Vector2(200, 40);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.blue;
    canvas.drawRect(size.toRect(), paint);

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.x / 2 - textPainter.width / 2, size.y / 2 - textPainter.height / 2));
  }

  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
  }
}