import 'dart:math';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/domain/rules/rule_set.dart';
import 'package:telefunken/telefunken/presentation/game/card_component.dart';
import '../../domain/entities/player.dart';
import '../../domain/logic/game_logic.dart';

class TelefunkenGame extends FlameGame with TapDetector {
  final String playerName;
  final int playerCount;
  final Duration roundDuration;
  final RuleSet ruleSet;

  List<Player> lobbyPlayers = [];
  GameLogic? gameLogic;
  final Map<String, Vector2> playerPositions = {};

  late int playerIndex;
  late TextComponent cardsLeftText;
  late TextComponent waitingForPlayersText;
  late Vector2 deckPosition;
  late SpriteComponent deckUI;
  late Rect discardZone;
  late Rect tableZone;

  TelefunkenGame({
    required this.playerName,
    required this.playerCount,
    required this.roundDuration,
    required this.ruleSet,
  });

  @override
  Future<void> onLoad() async {
    // Lade Hintergrund
    add(SpriteComponent()
      ..sprite = await loadSprite('background.png')
      ..size = size);

    deckPosition = Vector2(size.x / 2 - 25, size.y / 3); // Anpassen, sodass das Deck zentriert erscheint

    // UI-Komponenten laden
    deckUI = SpriteComponent(
      sprite: await loadSprite('cards/Back_Red.png'),
      position: deckPosition,
      anchor: Anchor.center,
      size: Vector2(50, 70),
    );
    add(deckUI);

    // DiscardZone: Rechts neben dem Deck
    discardZone = Rect.fromLTWH(
      deckPosition.x + 10,
      deckPosition.y - 70,
      50,
      70
    );


    tableZone = Rect.fromLTWH(
      10,
      350,
      size.x - 10,
      size.y - 600,
    );

    cardsLeftText = TextComponent(
      text: 'Cards left: 108',
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
      position: deckPosition + Vector2(0, 50),
      anchor: Anchor.center,
    );
    add(cardsLeftText);

    waitingForPlayersText = TextComponent(
      text: 'Waiting for ${playerCount - lobbyPlayers.length} players...',
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 24, color: Colors.white),
      ),
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
    );
    add(waitingForPlayersText);
  }

  void joinGame(Player player) {
    if (!lobbyPlayers.any((p) => p.id == player.id)) {
      lobbyPlayers.add(player);
      _updateWaitingText();
    }
    if (lobbyPlayers.length >= playerCount && gameLogic == null) {
      _initializeGameLogic();
    }
  }

  void _updateWaitingText() {
    if (lobbyPlayers.length == playerCount) {
      waitingForPlayersText.text = 'All players joined. Starting game...';
      Future.delayed(const Duration(seconds: 1), () {
        remove(waitingForPlayersText);
      });
    } else {
      waitingForPlayersText.text = 'Waiting for ${playerCount - lobbyPlayers.length} players...';
    }
  }

  void _initializeGameLogic() {
    gameLogic = GameLogic(
      players: lobbyPlayers,
      ruleSet: ruleSet,
    );
    gameLogic!.startGame();
    _displayPlayers(gameLogic!.players);
    playerIndex = gameLogic!.players.indexWhere((player) => player.name == playerName);
    _distributeCards(deckPosition);
  }

  void _displayPlayers(List<Player> players) {
    final radius = 180.0;
    for (int i = 0; i < players.length; i++) {
      // Für einen schönen Bogen oberhalb des Decks: Fester Winkelbereich von 60° bis 120°
      final double startAngle = pi / 3;
      final double endAngle = 2 * pi / 3;
      double angle = startAngle;
      if (players.length > 1) {
        angle = startAngle + (endAngle - startAngle) * (i / (players.length - 1));
      }
      final playerPos = deckPosition - Vector2(radius * cos(angle), radius * sin(angle));
      playerPositions[players[i].name] = playerPos;
      add(TextComponent(
        text: players[i].name,
        textRenderer: TextPaint(style: const TextStyle(fontSize: 18, color: Colors.white)),
        position: playerPos,
        anchor: Anchor.center,
      ));
    }
  }

  Future<void> _distributeCards(Vector2 deckPos) async {
    int count = 0;
    final totalCards = lobbyPlayers.length * 11 + 1; // 12 für den Startspieler, 11 für alle anderen
    for (int i = 0; i < totalCards; i++) {
      final idx = i % lobbyPlayers.length;
      await _dealCardAnimation(
        deckPos,
        playerPositions[gameLogic!.players[idx].name] ?? Vector2(size.x / 2, size.y - 100),
      );
      count++;
      _updateCardsLeftText(108 - count);
    }
    displayCurrentPlayerHand();
    displayOpponentsHand();
  }

  Future<void> _dealCardAnimation(Vector2 startPos, Vector2 endPos) async {
    final card = SpriteComponent()
      ..sprite = Sprite(await images.load('cards/Back_Red.png'))
      ..position = startPos
      ..size = Vector2(50, 70)
      ..anchor = Anchor.center;
    add(card);
    card.priority = 10;
    card.add(MoveEffect.to(
      endPos,
      EffectController(duration: 1.0, curve: Curves.easeInOut),
      onComplete: () => remove(card),
    ));
    await Future.delayed(const Duration(milliseconds: 100));
  }

  void _updateCardsLeftText([int? cardsLeft]) {
    cardsLeftText.text = 'Cards left: ${cardsLeft ?? gameLogic?.getDeckLength() ?? 0}';
    if ((gameLogic?.getDeckLength() ?? 0) == 0) {
      remove(deckUI);
    }
  }

  void displayCurrentPlayerHand() async {
    // Entferne alle bisherigen Karten (sicherstellen, dass keine alten Komponenten übrig sind)
    children.whereType<CardComponent>().forEach(remove);

    final int cardCount = gameLogic!.players[playerIndex].hand.length;
    final double cardWidth = 50.0;
    final double minSpacing = 15.0;
    final double maxSpacing = 50.0;
    final double totalWidth = (cardCount - 1) * maxSpacing + cardWidth;
    double spacing = totalWidth > size.x ? (size.x - cardWidth) / (cardCount - 1) : maxSpacing;
    spacing = spacing.clamp(minSpacing, maxSpacing);
    final double handWidth = (cardCount - 1) * spacing + cardWidth;
    final Vector2 startPos = Vector2((size.x - handWidth) / 2, size.y - 150);

    for (int i = 0; i < cardCount; i++) {
      final Vector2 pos = startPos + Vector2(i * spacing, 0);
      final card = gameLogic!.players[playerIndex].hand[i];
      final cardComponent = CardComponent(
        card: card,
        ownerId: gameLogic!.players[playerIndex].id,
        gameLogic: gameLogic!,
        onCardsDropped: handleCardsDrop,
        position: pos,
      );
      add(cardComponent);
    }
  }

  void displayOpponentsHand() async {
    final double cardWidth = 30.0;
    final double spacing = 10.0;

    for (var player in gameLogic!.players) {

      if (player.id != gameLogic!.players[playerIndex].id) {
            final int cardCount = player.hand.length;
        final Vector2 playerPos = playerPositions[player.name] ?? Vector2.zero();
        final Vector2 startPos = playerPos + Vector2(-((cardCount - 1) * spacing + cardWidth) / 2, 20);
        for (int i = 0; i < cardCount; i++) {
          final Vector2 pos = startPos + Vector2(i * spacing, 0);
          add(SpriteComponent()
            ..sprite = await loadSprite('cards/Back_Red.png')
            ..position = pos
            ..anchor = Anchor.topLeft
            ..size = Vector2(cardWidth, 42)
            ..priority = 1);
        }
      }
    }
  }

  void nextTurn() {
    playerIndex = (playerIndex + 1) % lobbyPlayers.length;
    if (lobbyPlayers[playerIndex].isAI) {
      nextTurn();
    } else {
      displayCurrentPlayerHand();
    }
  }

  void showTable() async{
    const double cardWidth = 30.0;
    const double cardHeight = 50.0;
    const double groupPadding = 20.0;
    const double cardSpacing = -10.0;

    double currentX = tableZone.left;
    double currentY = tableZone.top;

    for (var group in gameLogic!.table) {
      // Berechne die Breite der Gruppe
      final double groupWidth = group.length * (cardWidth + cardSpacing) - cardSpacing;

      // Wenn die Gruppe nicht mehr in die aktuelle Zeile passt, springe in die nächste Zeile
      if (currentX + groupWidth > tableZone.right) {
        currentX = tableZone.left;
        currentY += cardHeight + groupPadding;
      }

      // Platziere die Karten der Gruppe
      for (int i = 0; i < group.length; i++) {
        final card = group[i];
        final Vector2 position = Vector2(
          currentX + i * (cardWidth + cardSpacing),
          currentY,
        );

        add(SpriteComponent()
          ..sprite = Sprite(await images.load('cards/${card.suit}${card.rank}.png'))
          ..position = position
          ..size = Vector2(cardWidth, cardHeight)
          ..anchor = Anchor.topLeft);
      }
      currentX += groupWidth + groupPadding;
    }
  }

  void showDiscardPile() async{
    const double cardWidth = 50.0;
    const double cardHeight = 70.0;

    if(gameLogic!.discardPile.isEmpty) return;
    final card = gameLogic!.discardPile.last;
    add(SpriteComponent()
      ..sprite = Sprite(await images.load('cards/${card.suit}${card.rank}.png'))
      ..position = Vector2(discardZone.right, discardZone.center.dy)
      ..size = Vector2(cardWidth, cardHeight)
      ..anchor = Anchor.topCenter);
  }

  void updateUI(){
    displayCurrentPlayerHand();
    displayOpponentsHand();
    showTable();
    showDiscardPile();
  }

  void handleCardsDrop(List<CardComponent> group) {
    // Überprüfe, ob der Spieler am Zug ist
    if (!gameLogic!.isPlayersTurn(gameLogic!.players[playerIndex].id)) {
      print("Nicht dein Zug! Aktion abgebrochen.");
      resetGroupToOriginalPosition(group);
      CardComponent.selectedCards.clear();
      return;
    }else{
      if(group.length == 1){
        //check if the card is with the discard offset
        if(group[0].position.x > discardZone.left && group[0].position.x < discardZone.right &&
           group[0].position.y > discardZone.top && group[0].position.y < discardZone.bottom){
            print("Discarding");
          if(gameLogic!.validateDiscard(group.first.card)){
            updateUI();
          }else{
            resetGroupToOriginalPosition(group);
          }
        }
      }else{
        if(gameLogic!.validateMove(group.map((card) => card.card).toList())){

        }else{
          resetGroupToOriginalPosition(group);
        }
      }
      CardComponent.selectedCards.clear();
    }
  }

  // Hilfsmethode zum Zurücksetzen der Kartenpositionen
  void resetGroupToOriginalPosition(List<CardComponent> group) {
    for (var cardComponent in group) {
      cardComponent.add(MoveEffect.to(
        cardComponent.originalPosition!,
        EffectController(duration: 0.5, curve: Curves.easeOut),
      ));
    }
  }
}