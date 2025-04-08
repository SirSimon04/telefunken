import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/domain/logic/game_logic.dart';

class CardComponent extends SpriteComponent with TapCallbacks, DragCallbacks, CollisionCallbacks {
  final CardEntity card;
  String? ownerId;
  final GameLogic gameLogic;
  final void Function(List<CardComponent>)? onCardsDropped;
  final void Function(CardComponent)? onHighlightChanged;
  bool isHighlighted = false;
  Vector2? originalPosition;
  Vector2? lastPointerPosition;

  static Set<CardComponent> selectedCards = {};

  CardComponent({
    required this.card,
    required this.ownerId,
    required this.gameLogic,
    this.onCardsDropped,
    this.onHighlightChanged,
    Sprite? sprite,
    Vector2? position,
    Vector2? size,
  }) : super(sprite: sprite, position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final spritePath = 'cards/${card.suit}${card.rank}.png';
    sprite = await Sprite.load(spritePath);
    size = Vector2(50, 75);
    anchor = Anchor.topLeft;
    originalPosition = position?.clone() ?? Vector2.zero();
    add(RectangleHitbox());
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (ownerId == null) {
      return;
    }

    isHighlighted = !isHighlighted;
    position.add(Vector2(0, isHighlighted ? -10 : 10));

    if (isHighlighted) {
      selectedCards.add(this);
    } else {
      selectedCards.remove(this);
    }

    onHighlightChanged?.call(this);
  }

  bool isPlayersMove() {
    return gameLogic.players[gameLogic.currentPlayerIndex].id == ownerId;
  }

  void removeOwner() {
    ownerId = null;
    originalPosition = null;
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (!isPlayersMove() || ownerId == null || gameLogic.isPaused()) {
      return;
    }

    if (selectedCards.isEmpty || !selectedCards.contains(this)) {
            return;
    }

    super.onDragStart(event);
    priority = 10;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!isPlayersMove() || ownerId == null || gameLogic.isPaused()) {
      return;
    }

    final selectedCardsCopy = List<CardComponent>.from(selectedCards);

    for (var card in selectedCardsCopy) {
      card.position.add(event.localDelta);
    }
    lastPointerPosition = event.localPosition;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    try {
      if (!isPlayersMove() || ownerId == null || gameLogic.isPaused()) {
        return;
      }

      final selectedCardsCopy = List<CardComponent>.unmodifiable(selectedCards);

      if (onCardsDropped != null && selectedCardsCopy.isNotEmpty) {
        onCardsDropped!(selectedCardsCopy.toList());
      }
    } finally {
      priority = 0;
    }
    super.onDragEnd(event);
  }
}
