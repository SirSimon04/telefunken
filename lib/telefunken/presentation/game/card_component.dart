import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/domain/logic/game_logic.dart';

class CardComponent extends SpriteComponent with TapCallbacks, DragCallbacks, CollisionCallbacks {
  final CardEntity card;
  late String? ownerId;
  final GameLogic gameLogic;
  final void Function(List<CardComponent>)? onCardsDropped;
  final void Function(CardComponent)? onHighlightChanged;
  bool isHighlighted = false;
  Vector2? originalPosition;
  Vector2? lastPointerPosition;

  static List<CardComponent> selectedCards = [];

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
    // Überprüfe, ob die Karte einen gültigen Besitzer hat
    if (ownerId == -1) {
      print("Diese Karte hat keinen Besitzer und kann nicht ausgewählt werden.");
      return;
    }

    // Toggle die Hervorhebung der Karte
    isHighlighted = !isHighlighted;

    if (isHighlighted) {
      selectedCards.add(this); // Karte zur Gruppe hinzufügen
      position.add(Vector2(0, -10)); // Karte nach oben verschieben
    } else {
      selectedCards.remove(this); // Karte aus der Gruppe entfernen
      position.add(Vector2(0, 10)); // Karte zurück nach unten verschieben
    }

    onHighlightChanged?.call(this);
  }

  bool isPlayersMove(){
    return gameLogic.players[gameLogic.currentPlayerIndex].id == ownerId;
  }

  void removeOwner() {
    ownerId = null;
    originalPosition = null;
    print("Nutzerspezifische Eigenschaften der Karte wurden entfernt.");
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (!isPlayersMove() || ownerId == -1) {
      print("Nicht dein Zug! Du kannst keine Karten ziehen.");
      return;
    }

    // Überprüfe, ob die Liste der ausgewählten Karten korrekt ist
    if (selectedCards.isEmpty || !selectedCards.contains(this)) {
      print("Keine gültige Gruppe ausgewählt.");
      return;
    }

    super.onDragStart(event);
    priority = 10; // Setze die Priorität höher, damit die Karte über anderen Elementen liegt
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!isPlayersMove() || ownerId == -1) {
      return;
    }

    // Kopiere die Liste, um ConcurrentModificationError zu vermeiden
    final selectedCardsCopy = List<CardComponent>.from(selectedCards);

    for (var card in selectedCardsCopy) {
      card.position.add(event.localDelta);
    }
    lastPointerPosition = event.localPosition;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (!isPlayersMove() || ownerId == -1) {
      return;
    }

    // Kopiere die Liste, um ConcurrentModificationError zu vermeiden
    final selectedCardsCopy = List<CardComponent>.from(selectedCards);

    if (onCardsDropped != null && selectedCardsCopy.isNotEmpty) {
      onCardsDropped!(selectedCardsCopy);
    }
    super.onDragEnd(event);
    priority = 0;
  }
}
