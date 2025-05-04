import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/domain/logic/game_logic.dart';
import 'package:telefunken/telefunken/presentation/game/telefunken_game.dart';

class CardComponent extends SpriteComponent with TapCallbacks, DragCallbacks, CollisionCallbacks {
  final CardEntity card;
  String? ownerId;
  final GameLogic gameLogic;
  final Function(List<CardComponent>)? onCardsDropped;
  final Function(CardComponent)? onHighlightChanged;
  final TelefunkenGame game;

  Vector2? originalPosition;
  bool isHighlighted = false;
  Vector2? lastPointerPosition;

  static final List<CardComponent> selectedCards = [];

  CardComponent({
    required this.card,
    this.ownerId,
    required this.gameLogic,
    this.onCardsDropped,
    this.onHighlightChanged,
    required this.game,
    Vector2? position,
  }) : super(position: position);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final spritePath = 'cards/${card.suit}${card.rank}.png';
    sprite = await Sprite.load(spritePath);
    size = Vector2(50, 75);
    anchor = Anchor.topLeft;
    originalPosition = position.clone();

    children.whereType<ShapeHitbox>().forEach(remove);
    add(RectangleHitbox()
      ..collisionType = CollisionType.active
      ..renderShape = false);
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

    List<CardEntity>? moveContainingThisCard;
    for (final move in gameLogic.currentMoves) {
      if (move.any((c) => c.toString() == card.toString())) {
        moveContainingThisCard = move;
        break;
      }
    }

    if (moveContainingThisCard != null) {
      game.handleDragOnPlayedMove(moveContainingThisCard);
      return;
    }

    if (selectedCards.isEmpty || !selectedCards.contains(this)) {
      if (isHighlighted) {
        isHighlighted = false;
        position.y += 10;
      }
      selectedCards.clear();
      isHighlighted = true;
      position.y -= 10;
      selectedCards.add(this);
      onHighlightChanged?.call(this);
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
    lastPointerPosition = event.localDelta;

    arrangeSelectedCardsAroundDraggedCard(this);
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

  void arrangeSelectedCardsAroundDraggedCard(CardComponent draggedCard) {
    final spacing = draggedCard.size.x * 0.1;
    final selected = List<CardComponent>.from(selectedCards);

    selected.sort((a, b) => a.position.x.compareTo(b.position.x));

    final indexOfDragged = selected.indexOf(draggedCard);
    final basePosition = draggedCard.position;

    for (int i = 0; i < selected.length; i++) {
      final card = selected[i];
      final dx = (i - indexOfDragged) * (card.size.x + spacing);
      card.position = basePosition + Vector2(dx, 0);
    }
  }

  void setHighlighted(bool highlight) {
    if (isHighlighted != highlight) {
      isHighlighted = highlight;
      position.add(Vector2(0, isHighlighted ? -10 : 10));
      if (!isHighlighted) {
        selectedCards.remove(this);
      }
    }
  }
}
