import 'package:flame/components.dart';

class LabeledSpriteComponent extends SpriteComponent {
  final String label;

  LabeledSpriteComponent({
    required this.label,
    Sprite? sprite,
    Vector2? position,
    Vector2? size,
    Anchor? anchor,
    int priority = 0,
  }) : super(
          sprite: sprite,
          position: position ?? Vector2.zero(),
          size: size ?? Vector2.zero(),
          anchor: anchor ?? Anchor.topLeft,
          priority: priority,
        );
}