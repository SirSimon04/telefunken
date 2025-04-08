import 'dart:math';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/presentation/game/card_component.dart';
import 'package:telefunken/telefunken/service/firestore_controller.dart';
import '../../domain/entities/player.dart';
import '../../domain/logic/game_logic.dart';

class TelefunkenGame extends FlameGame with TapDetector {
  final String gameId;
  final String playerId;
  final String playerName;
  final FirestoreController firestoreController;

  GameLogic? gameLogic;
  final Map<String, Vector2> playerPositions = {};

  late int playerIndex;
  late int maxPlayers;
  late TextComponent cardsLeftText;
  late TextComponent waitingForPlayersText;
  late Vector2 deckPosition;
  late SpriteComponent deckUI;
  late Rect discardZone;
  late Rect tableZone;
  
  bool _isGameLogicInitialized = false;

  TelefunkenGame({
    required this.gameId,
    required this.playerId,
    required this.playerName,
    required this.firestoreController,
  });

  @override
  Future<void> onLoad() async {
    await _loadUIComponents();
    _observeGameState();
  }

  Future<void> _loadUIComponents() async {
    add(SpriteComponent()
      ..sprite = await loadSprite('background.png')
      ..size = size);

    deckPosition = Vector2(size.x / 2 - 25, size.y / 3);

    deckUI = SpriteComponent(
      sprite: await loadSprite('cards/Back_Red.png'),
      position: deckPosition,
      anchor: Anchor.center,
      size: Vector2(50, 70),
    );
    add(deckUI);

    discardZone = Rect.fromLTWH(deckPosition.x + 10, deckPosition.y - 70, 50, 70);
    tableZone = Rect.fromLTWH(10, 350, size.x - 10, size.y - 600);

    cardsLeftText = TextComponent(
      text: 'Cards left: 108',
      textRenderer: TextPaint(style: const TextStyle(fontSize: 18, color: Colors.white)),
      position: deckPosition + Vector2(0, 50),
      anchor: Anchor.center,
    );
    add(cardsLeftText);

    waitingForPlayersText = TextComponent(
      text: 'Waiting for players:',
      textRenderer: TextPaint(style: const TextStyle(fontSize: 24, color: Colors.white)),
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
    );
    add(waitingForPlayersText);
  }

  void _observeGameState() {
    firestoreController.listenToGameState(gameId).listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;

      final currentPlayers = data['current_players'] ?? 0;
      maxPlayers = data['max_players'] ?? 0;

      // Check if the game has started
      final isGameStarted = data['isGameStarted'] ?? false;
      if (isGameStarted && !_isGameLogicInitialized) {
        _isGameLogicInitialized = true; // Prevent reinitialization
        _initializeGameLogic();
      } else {
        _updateWaitingText(currentPlayers);
      }
    });
  }

  void _updateWaitingText(int currentPlayers) {
    waitingForPlayersText.text = 'Waiting for players: $currentPlayers / $maxPlayers';
  }

  void _initializeGameLogic() async {
    if (waitingForPlayersText.parent != null) {
      remove(waitingForPlayersText);
    }
    gameLogic = GameLogic(
      gameId: gameId,
      firestoreController: firestoreController,
    );

    await gameLogic!.syncWithFirestore();
    gameLogic!.listenToGameState();

    _displayPlayers(gameLogic!.players);
    playerIndex = gameLogic!.players.indexWhere((player) => player.id == playerId);
    _distributeCards(deckPosition);
  }

  void _displayPlayers(List<Player> players) {
    final radius = 180.0;
    for (int i = 0; i < players.length; i++) {
      final angle = players.length > 1
          ? pi / 3 + (2 * pi / 3 - pi / 3) * (i / (players.length - 1))
          : pi / 3;
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
    final totalCards = maxPlayers * 11 + 1;
    for (int i = 0; i < totalCards; i++) {
      final idx = i % maxPlayers;
      await _dealCardAnimation(
        deckPos,
        playerPositions[gameLogic!.players[idx].name] ?? Vector2(size.x / 2, size.y - 100),
      );
      count++;
      _updateCardsLeftText(108 - count);
    }
    updateUI();
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
    if ((gameLogic?.getDeckLength() ?? 0) == 0) remove(deckUI);
  }

  void displayCurrentPlayerHand() async {
    children.whereType<CardComponent>().forEach(remove);

    final cardCount = gameLogic!.players[playerIndex].hand.length;
    final cardWidth = 50.0;
    final minSpacing = 15.0;
    final maxSpacing = 50.0;
    final totalWidth = (cardCount - 1) * maxSpacing + cardWidth;
    final spacing = totalWidth > size.x ? (size.x - cardWidth) / (cardCount - 1) : maxSpacing;
    final handWidth = (cardCount - 1) * spacing + cardWidth;
    final startPos = Vector2((size.x - handWidth) / 2, size.y - 150);

    for (int i = 0; i < cardCount; i++) {
      final pos = startPos + Vector2(i * spacing, 0);
      final card = gameLogic!.players[playerIndex].hand[i];
      add(CardComponent(
        card: card,
        ownerId: gameLogic!.players[playerIndex].id,
        gameLogic: gameLogic!,
        onCardsDropped: handleCardsDrop,
        position: pos,
      ));
    }
  }

  void displayOpponentsHand() async {
    final cardWidth = 30.0;
    final spacing = 10.0;

    for (var player in gameLogic!.players) {
      if (player.id == gameLogic!.players[playerIndex].id) continue;

      final cardCount = player.hand.length;
      final playerPos = playerPositions[player.name] ?? Vector2.zero();
      final startPos = playerPos + Vector2(-((cardCount - 1) * spacing + cardWidth) / 2, 20);

      for (int i = 0; i < cardCount; i++) {
        final pos = startPos + Vector2(i * spacing, 0);
        add(SpriteComponent()
          ..sprite = await loadSprite('cards/Back_Red.png')
          ..position = pos
          ..anchor = Anchor.topLeft
          ..size = Vector2(cardWidth, 42)
          ..priority = 1);
      }
    }
  }

  void showTable() async {
    const cardWidth = 30.0;
    const cardHeight = 50.0;
    const groupPadding = 20.0;
    const cardSpacing = -10.0;

    double currentX = tableZone.left;
    double currentY = tableZone.top;

    for (var group in gameLogic!.table) {
      final groupWidth = group.length * (cardWidth + cardSpacing) - cardSpacing;

      if (currentX + groupWidth > tableZone.right) {
        currentX = tableZone.left;
        currentY += cardHeight + groupPadding;
      }

      for (int i = 0; i < group.length; i++) {
        final card = group[i];
        final position = Vector2(currentX + i * (cardWidth + cardSpacing), currentY);
        add(SpriteComponent()
          ..sprite = Sprite(await images.load('cards/${card.suit}${card.rank}.png'))
          ..position = position
          ..size = Vector2(cardWidth, cardHeight)
          ..anchor = Anchor.topLeft);
      }
      currentX += groupWidth + groupPadding;
    }
  }

  void showDiscardPile() async {
    if (gameLogic!.discardPile.isEmpty) return;

    const cardWidth = 50.0;
    const cardHeight = 70.0;
    final card = gameLogic!.discardPile.last;

    add(SpriteComponent()
      ..sprite = Sprite(await images.load('cards/${card.suit}${card.rank}.png'))
      ..position = Vector2(discardZone.right, discardZone.center.dy)
      ..size = Vector2(cardWidth, cardHeight)
      ..anchor = Anchor.topCenter);
  }

  void updateUI() {
    displayCurrentPlayerHand();
    displayOpponentsHand();
    showTable();
    showDiscardPile();
  }

  void handleCardsDrop(List<CardComponent> group) {
    if (!gameLogic!.isPlayersTurn(gameLogic!.players[playerIndex].id) || gameLogic!.isPaused()) {
      resetGroupToOriginalPosition(group);
      CardComponent.selectedCards.clear();
      return;
    }

    if (group.length == 1) {
      final card = group.first;
      if (card.position.x > discardZone.left &&
          card.position.x < discardZone.right &&
          card.position.y > discardZone.top &&
          card.position.y < discardZone.bottom) {
        if (gameLogic!.validateDiscard(card.card)) {
          updateUI();
        } else {
          resetGroupToOriginalPosition(group);
        }
      }
    } else {
      if (!gameLogic!.validateMove(group.map((card) => card.card).toList())) {
        resetGroupToOriginalPosition(group);
      }
    }
    CardComponent.selectedCards.clear();
  }

  void resetGroupToOriginalPosition(List<CardComponent> group) {
    for (var cardComponent in group) {
      cardComponent.add(MoveEffect.to(
        cardComponent.originalPosition!,
        EffectController(duration: 0.5, curve: Curves.easeOut),
      ));
    }
  }

  void showWinningScreen() async {
    final gameSnapshot = await firestoreController.getGame(gameId);
    final winner = gameSnapshot.data()?['winner'] ?? 'Unbekannt';

    add(TextComponent(
      text: 'Spieler $winner hat gewonnen!',
      textRenderer: TextPaint(style: const TextStyle(fontSize: 48, color: Colors.black)),
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
    ));
  }

  @override
  void onTapDown(TapDownInfo info) {
    final tapPosition = info.eventPosition.global;

    if(!gameLogic!.isPlayersTurn(playerId)) return;
    //später den buy button available lassen

    // Prüfen, ob auf das Deck geklickt wurde
    if (deckUI.toRect().contains(tapPosition.toOffset())) {
      if (gameLogic != null && !gameLogic!.hasDrawnCard) {
        gameLogic!.drawCard('deck');
        updateUI();
      }
    }else if (discardZone.contains(tapPosition.toOffset())) {
      if (gameLogic != null && !gameLogic!.hasDrawnCard) {
        gameLogic!.drawCard('discardPile');
        updateUI();
      }
    }
  }
}