import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/domain/logic/game_logic.dart';
import 'package:telefunken/telefunken/presentation/game/telefunken_game.dart';

class CardComponent extends SpriteComponent with DragCallbacks {
  final CardEntity card;
  final GameLogic? gameLogic;
  final void Function(CardEntity)? onCardDropped;
  Vector2? originalPosition;
  final RectangleComponent garbageUI;
  final RectangleComponent tableUI;
  final RectangleComponent playerHandUI;

  CardComponent({
    required this.card,
    this.onCardDropped,
    this.gameLogic,
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required this.garbageUI,
    required this.tableUI,
    required this.playerHandUI,
  }) : super(sprite: sprite, position: position, size: size, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    //Anchor the card in the center
    anchor = Anchor.centerLeft;
    sprite = await Sprite.load('cards/${card.suit}${card.rank}.png');
    super.onLoad();
  }

  @override
  bool handleDragStart(DragStartInfo info) {
    originalPosition = position.clone(); // Speichere die ursprüngliche Position
    priority = 100; // Stelle sicher, dass die Karte über anderen Komponenten liegt
    return true;
  }

  @override
  bool handleDragUpdate(DragUpdateInfo info) {
    position += info.delta.global; // Bewege die Karte entsprechend der Drag-Bewegung
    return true;
  }

  @override
  bool handleDragEnd(DragEndInfo info) {
    // Überprüfe, ob die Karte auf den Ablagestapel oder den Tisch gelegt wurde
    if (_isOverGarbagePile()) {
      onCardDropped?.call(card); // Karte auf den Ablagestapel legen
      removeFromParent(); // Entferne die Karte aus der Hand
    } else if (_isOverTable()) {
      onCardDropped?.call(card); // Karte auf den Tisch legen
      removeFromParent();
    } else {
      // Karte kehrt zur ursprünglichen Position zurück
      add(MoveEffect.to(
        originalPosition!,
        EffectController(duration: 0.5, curve: Curves.easeOut),
      ));
    }
    return true;
  }

  bool _isOverGarbagePile() {
    final garbageBounds = Rect.fromLTWH(
      garbageUI.position.x,
      garbageUI.position.y,
      garbageUI.size.x,
      garbageUI.size.y,
    );
    return garbageBounds.contains(position.toOffset());
  }

  bool _isOverTable() {
    final tableBounds = Rect.fromLTWH(
      tableUI.position.x,
      tableUI.position.y,
      tableUI.size.x,
      tableUI.size.y,
    );
    return tableBounds.contains(position.toOffset());
  }
}