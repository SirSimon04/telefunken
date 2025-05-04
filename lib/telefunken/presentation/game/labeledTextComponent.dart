import 'package:flame/components.dart';

class LabeledTextComponent extends TextComponent {
  final String label;

  LabeledTextComponent({
    required this.label,
    required String text,
    required TextPaint textRenderer,
    Vector2? position,
    Anchor? anchor,
  }) : super(
          text: text,
          textRenderer: textRenderer,
          position: position,
          anchor: anchor,
        );
}