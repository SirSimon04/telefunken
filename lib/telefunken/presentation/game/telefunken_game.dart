import 'dart:math';

import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/deck.dart';
import '../../domain/entities/player.dart';
import '../../domain/logic/game_logic.dart';
import '../../domain/rules/standard_rule_set.dart';

class TelefunkenGame extends FlameGame {
  late Deck deck;
  late int playerCount;
  late List<Player> players;
  late GameLogic gameLogic;
  final Duration roundDuration;
  int currentPlayerIndex = 0;
  final Map<String, Vector2> playerPositions = {};
  late TextComponent cardsLeftText;
  late SpriteComponent deckUI;
  late RectangleComponent garbageUI;

  TelefunkenGame({
    required this.playerCount,
    required this.roundDuration,
  });

  @override
  Future<void> onLoad() async {
    final deckPosition = Vector2(size.x / 2, size.y / 3);

    // Hintergrundbild hinzufügen
    add(SpriteComponent()
      ..sprite = await loadSprite('background.png')
      ..size = size);

    deckUI = SpriteComponent(
      sprite: await loadSprite('cards/Back_Red.png'),
      position: deckPosition,
      anchor: Anchor.centerRight,
      size: Vector2(50, 70),
    );
    add(deckUI);

    // Garbage UI should just be a square in the same size but with a white border
    garbageUI = RectangleComponent(
      position: deckPosition + Vector2(10, 0),
      size: Vector2(50, 70),
      anchor: Anchor.centerLeft,
      paint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white,
    );
    add(garbageUI);
    
    // Text für verbleibende Karten hinzufügen
    cardsLeftText = TextComponent(
      text: 'Cards left: ',
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
      position: deckPosition + Vector2(0, 50),
      anchor: Anchor.center,
    );
    add(cardsLeftText);

    // Spieler anzeigen und Positionen speichern
    displayPlayers(deckPosition);

    // "BUY"-Button unten rechts hinzufügen
    final buyButtonPosition = Vector2(size.x - 50, size.y - 50);
    add(ButtonComponent(
      text: 'BUY',
      position: buyButtonPosition,
      onPressed: () {
        // Logik für den "BUY"-Button hier
      },
    ));

    // Platzhalter: UI-Komponente zur Anzeige des Spielstarts
    final waitForPlayersText = TextComponent(
      text: "Warte auf Spieler...",
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 24, color: Colors.white),
      ),
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
    );
    add(waitForPlayersText);

    final startText = TextComponent(
      text: "Telefunken Game gestartet",
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 24, color: Colors.white),
      ),
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
    );

    //wenn alle Spieler da sind, soll der wait text verschwinden und der Starttext erscheinen
    if(this.playerCount == players.length) {
      remove(waitForPlayersText);
      add(startText);
      add(TimerComponent(
        period: 2,
        removeOnFinish: true,
        onTick: () async {
          remove(startText);
          // Hier kannst du den Spielstart initiieren
          gameLogic.startGame();
          await distributeCards(deckPosition);
        },
      ));
    }
  }

  void displayPlayers(Vector2 deckPosition) {
    final radius = 150.0;
    final angleStep = pi / (players.length);
    for (int i = 1; i < players.length; i++) {
      final angle = (i) * angleStep;
      final playerPosition = deckPosition - Vector2(radius * cos(angle), radius * sin(angle));
      playerPositions[players[i].name] = playerPosition; // Position speichern
      add(TextComponent(
        text: players[i].name,
        textRenderer: TextPaint(
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
        position: playerPosition,
        anchor: Anchor.center,
      ));
    }
  }

  void displayCurrentPlayerHand() async {
    final int cardCount = players[currentPlayerIndex].hand.length;
    final double cardWidth = 50.0;
    final double minSpacing = 15.0;
    final double maxSpacing = 50.0;
    
    final double totalWidth = (cardCount - 1) * maxSpacing + cardWidth;
    double spacing = totalWidth > size.x ? (size.x - cardWidth) / (cardCount - 1) : maxSpacing;
    spacing = spacing.clamp(minSpacing, maxSpacing);

    final double handWidth = (cardCount - 1) * spacing + cardWidth;
    
    // Berechne die Startposition so, dass die Hand **zentriert** ist
    final Vector2 startPosition = Vector2((size.x - handWidth) / 2, size.y - 150);
    
    for (int i = 0; i < cardCount; i++) {
      final Vector2 cardPosition = startPosition + Vector2(i * spacing, 0);
      
      add(SpriteComponent()
        ..sprite = await loadSprite('cards/${players[currentPlayerIndex].hand[i].toString()}.png')
        ..position = cardPosition
        ..anchor = Anchor.bottomLeft
        ..size = Vector2(cardWidth, 70)
        ..priority = 1);
    }
  }


  void nextTurn() {
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    if (players[currentPlayerIndex].isAI) {
      nextTurn(); // Skip AI players for now
    } else {
      displayCurrentPlayerHand();
    }
  }

  Future<void> distributeCards(Vector2 deckPosition) async {
    int count = 0;
    for (int j = 0; j < players[0].hand.length; j++) {
      for (int i = 0; i < players.length; i++) {
        if(j == players[0].hand.length - 1 && i > 0) {
          break;
        }
        final player = players[i];
        final playerPosition = i == 0
            ? Vector2(size.x / 2, size.y - 100)
            : playerPositions[player.name]!;
        await dealCardAnimation(deckPosition, playerPosition);
        count++;
        updateCardsLeftText(108-count);
      }
    }
    displayCurrentPlayerHand();
  }

  Future<void> dealCardAnimation(Vector2 startPosition, Vector2 endPosition) async {
    final card = SpriteComponent()
      ..sprite = Sprite(await images.load('cards/Back_Red.png'))
      ..position = startPosition
      ..size = Vector2(50, 70)
      ..anchor = Anchor.centerRight
      ..priority = 1;

    add(card);

    await Future.delayed(Duration(milliseconds: 500)); // Verzögerung hinzufügen

    card.add(MoveEffect.to(
      endPosition,
      EffectController(
        duration: 1.0,
        curve: Curves.easeInOut,
      ),
      onComplete: () => remove(card),
    ));
  }

  void updateCardsLeftText([int? cardsLeft]) {
    cardsLeftText.text = 'Cards left: ${cardsLeft ?? gameLogic.getDeckLenght()}';
    if(gameLogic.getDeckLenght() == 0) {
      remove(deckUI);
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
    size = Vector2(100, 50);
  }

  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
  }
}
