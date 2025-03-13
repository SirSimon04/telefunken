import 'card_entity.dart';

class Player {
  final int id;
  final String name;
  List<CardEntity> hand = [];

  Player({required this.id, required this.name});

  @override
  String toString() => 'Player $id: $name';
}
