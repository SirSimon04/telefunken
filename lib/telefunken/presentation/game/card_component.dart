import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';

class CardComponent extends SpriteComponent with TapCallbacks, DragCallbacks, CollisionCallbacks {
  final CardEntity card;
  final String ownerId; // Um den Besitzer der Karte zu identifizieren
  final void Function(CardComponent)? onCardDropped; 
  final void Function(CardComponent)? onHighlightChanged; // Callback für Highlight-Änderungen
  
  bool isHighlighted = false;
  late Vector2 originalPosition; // Speichert die Startposition der Karte
  Vector2? lastPointerPosition;   // Speichert die letzte Pointerposition während des Drags

  CardComponent({
    required this.card,
    required this.ownerId,
    this.onCardDropped,
    this.onHighlightChanged,
    Sprite? sprite,
    Vector2? position,
    Vector2? size,
  }) : super(sprite: sprite, position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Lade den Sprite basierend auf dem CardEntity-Modell
    final spritePath = 'cards/${card.suit}${card.rank}.png';
    sprite = await Sprite.load(spritePath);
    size ??= Vector2(50, 75);
    anchor = Anchor.topLeft;
    // Setze die ursprüngliche Position (sofern position schon gesetzt ist)
    originalPosition = position?.clone() ?? Vector2.zero();

    // Optional: Füge einen Collision-Hitbox hinzu, falls du Kollisionserkennung benötigst
    add(RectangleHitbox());
  }

  @override
  void onTapDown(TapDownEvent event) {
    // Toggle highlight: Hebe die Karte leicht an, wenn sie ausgewählt wird
    isHighlighted = !isHighlighted;
    onHighlightChanged?.call(this);
    position.add(Vector2(0, isHighlighted ? -10 : 10));
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    // Setze die Priorität höher, damit die Karte über anderen Elementen liegt
    priority = 10;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    print("Draggin Update");
    // Aktualisiere die Position anhand des localDelta
    position.add(event.localDelta);
    // Speichere die aktuelle Pointerposition, damit der Drop später geprüft werden kann
    lastPointerPosition = event.localPosition;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    // Setze Priorität wieder zurück
    priority = 0;
    // Rufe den Callback auf, um den Drop in der übergeordneten Komponente zu verarbeiten.
    // Hier werden die Karten (bzw. diese CardComponent) an die Logik übergeben, die den Drop validiert.
    onCardDropped?.call(this);
  }

  // Beispiel: Collision Callbacks (optional)
  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    print("Collision started with: ${other.runtimeType}");
    // Hier könntest du z.B. die Farbe des Hitboxes ändern, um visuelles Feedback zu geben
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    print("Collision ended with: ${other.runtimeType}");
    // Reagiere auf das Ende der Kollision
  }
}
