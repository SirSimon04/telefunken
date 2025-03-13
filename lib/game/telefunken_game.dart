import 'package:flame/effects.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../models/player.dart';
import 'game_logic.dart';
import 'rules/standard_rule_set.dart';

class TelefunkenGame extends FlameGame {
  late Deck deck;
  late List<Player> players;
  late GameLogic gameLogic;

  @override
  Future<void> onLoad() async {
    await Flame.images.loadAll(['cards.png']);
    



    // Deck und Spieler initialisieren
    deck = Deck();
    players = [
      Player(id: 1, name: 'Player 1'),
      Player(id: 2, name: 'Player 2'),
      // Weitere Spieler können hier hinzugefügt werden
    ];

    // Spiel-Logik mit dem Standard-Regelwerk initialisieren
    gameLogic = GameLogic(
      deck: deck,
      players: players,
      ruleSet: StandardRuleSet(),
    );
    gameLogic.startGame();

    // Platzhalter: UI-Komponente zur Anzeige des Spielstarts
    add(TextComponent(
      text: "Telefunken Game gestartet",
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 24, color: Colors.white),
      ),
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
    ));
  }

    Future<void> dealCardAnimation(Vector2 startPosition, Vector2 endPosition) async {
    final card = SpriteComponent()
      ..sprite = Sprite(await images.load('card.png'))
      ..position = startPosition
      ..size = Vector2(50, 70);

    add(card);

    card.add(MoveEffect.to(
      endPosition,
      EffectController(
        duration: 1.0,
        curve: Curves.easeInOut,
      ),
      onComplete: () => remove(card),
    ));
  }


  Sprite getSingleCard(double x, double y, double width, double height) {
  return Sprite(
    Flame.images.fromCache('cards.png'),
    srcPosition: Vector2(x, y),
    srcSize: Vector2(width, height),
  );
}
}
