import 'dart:math';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/presentation/game/card_component.dart';
import 'package:telefunken/telefunken/presentation/game/labeledTextComponent.dart';
import 'package:telefunken/telefunken/presentation/game/labeled_sprite_component.dart';
import 'package:telefunken/telefunken/service/firestore_controller.dart';
import 'package:collection/collection.dart';
import '../../domain/entities/player.dart';
import '../../domain/logic/game_logic.dart';

class TelefunkenGame extends FlameGame with TapDetector {
  final String gameId;
  final String playerId;
  final String playerName;
  final FirestoreController firestoreController;

  GameLogic? gameLogic;
  final Map<String, Vector2> playerPositions = {};
  final Map<String, List<SpriteComponent>> playerCoinSprites = {};

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
    listenToGameState();
    listenToPlayersUpdate();
    listenToDrawAnimationTrigger();

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
    gameLogic!.listenToPlayerUpdates();

    _displayPlayers(gameLogic!.players);
    playerIndex = gameLogic!.players.indexWhere((player) => player.id == playerId);
    _distributeCards(deckPosition);
  }

  void _displayPlayers(List<Player> players) async {
    final radius = 180.0;
    for (int i = 0; i < players.length; i++) {
      final player = players[i];
      final angle = players.length > 1
          ? pi / 3 + (2 * pi / 3 - pi / 3) * (i / (players.length - 1))
          : pi / 3;
      final playerPos = deckPosition - Vector2(radius * cos(angle), radius * sin(angle));
      playerPositions[player.name] = playerPos;

      // Basic TextComponent ohne Label
      add(LabeledTextComponent(
        label: 'playerName',
        text: player.name == playerName ? 'You' : player.name,
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

    final backSprite = Sprite(await images.load('cards/Back_Red.png'));

    for (var player in gameLogic!.players) {
      if (player.id == gameLogic!.players[playerIndex].id) continue;

      final cardCount = player.hand.length;
      final playerPos = playerPositions[player.name] ?? Vector2.zero();
      final startPos = playerPos + Vector2(-((cardCount - 1) * spacing + cardWidth) / 2, 20);

      for (int i = 0; i < cardCount; i++) {
        final pos = startPos + Vector2(i * spacing, 0);
        add(LabeledSpriteComponent(
          label: 'opponentCards',
          sprite: backSprite,
          position: pos,
          anchor: Anchor.topLeft,
          size: Vector2(cardWidth, 42),
          priority: 1
        ));
      }
    }
  }

  void showTable() async {
    children
      .where((c) => c is LabeledSpriteComponent && c.label.startsWith('tableGroup_'))
      .toList()
      .forEach(remove);

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
        add(LabeledSpriteComponent(label: 'tableGroup_$i')
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

    add(LabeledSpriteComponent(
      label: 'discard',
      sprite: Sprite(await images.load('cards/${card.suit}${card.rank}.png')),
      position: Vector2(discardZone.right, discardZone.center.dy),
      size: Vector2(cardWidth, cardHeight),
      anchor: Anchor.topCenter,
    ));
  }

  void updateUI() async {
    if (!_isGameLogicInitialized || gameLogic == null || gameLogic!.players.isEmpty) {
      return;
    }

    if (gameLogic!.isGameOver()) {
      print("Game Over");
      showWinningScreen();
      return;
    }

    removeSpriteCards('opponentCards');
    removeSpriteCards('discard');
    _updateCardsLeftText();
    displayCurrentPlayerHand();
    displayOpponentsHand();
    showTable();
    showDiscardPile();
    updatePlayersText();
    updateCoinTexts();
  }

  void updatePlayersText() async {
    children.whereType<LabeledTextComponent>().forEach((component) {
      if (component.label == 'playerName') {
        remove(component);
      }
    });

    for (var player in gameLogic!.players) {
      final playerPos = playerPositions[player.name] ?? Vector2.zero();
      var text = player.name == playerName
          ? 'You'
          : player.name;

      // Textstil für den aktuellen Spieler
      TextStyle textStyle = const TextStyle(fontSize: 18, color: Colors.white);
      if (gameLogic!.isPlayersTurn(player.id)) {
        textStyle = const TextStyle(
          fontSize: 20, // etwas größer
          color: Colors.orange, // orange Farbe
          fontWeight: FontWeight.bold, // fett
        );
      }

      add(LabeledTextComponent(
        label: 'playerName',
        text: text,
        textRenderer: TextPaint(style: textStyle),
        position: playerPos,
        anchor: Anchor.center,
      ));
    }
  }

  void updateCoinTexts() async {
    for (var player in gameLogic!.players) {
      // Entferne alte Coin-Sprites
      if (playerCoinSprites.containsKey(player.id)) {
        for (var coinSprite in playerCoinSprites[player.id]!) {
          remove(coinSprite);
        }
        playerCoinSprites[player.id]!.clear();
      }

      // Erstelle neue Coin-Sprites
      List<SpriteComponent> coinSprites = [];
      for (int j = 0; j < player.coins; j++) {
        final playerPos = playerPositions[player.name] ?? Vector2.zero();
        final coinSprite = SpriteComponent(
          sprite: await loadSprite('coin.png'),
          size: Vector2(20, 20),
          position: playerPos + Vector2(j * 12 - (player.coins - 1) * 5, -20),
          anchor: Anchor.center,
        );
        add(coinSprite);
        coinSprites.add(coinSprite);
      }
      playerCoinSprites[player.id] = coinSprites;
    }
  }

  void showDrawPile() async {
    if (gameLogic!.deck.isEmpty()) return;

    const cardWidth = 50.0;
    const cardHeight = 70.0;

    add(SpriteComponent()
      ..sprite = Sprite(await images.load('cards/Back_Red.png'))
      ..position = Vector2(deckPosition.x, deckPosition.y)
      ..size = Vector2(cardWidth, cardHeight)
      ..anchor = Anchor.center);
  }

  void removeSpriteCards(String label) {
    final toRemove = children.where((c) =>
    c is LabeledSpriteComponent && (c).label == label).toList();
    for (var comp in toRemove) {
      comp.removeFromParent();
    }
  }

  void handleCardsDrop(List<CardComponent> group) async {
    if (!gameLogic!.isPlayersTurn(gameLogic!.players[playerIndex].id) || gameLogic!.isPaused()) {
      resetGroupToOriginalPosition(group);
      CardComponent.selectedCards.clear();
      return;
    }

    // If collision with other groups on the table:
    // Check if the player has met the round condition (isOut).
    // If yes, try appending the cards. If not, ignore.
    if (gameLogic!.players[playerIndex].isOut()) {
      final selectedArea = group.fold<Rect>(
        group.first.toRect(),
        (previous, card) => previous.expandToInclude(card.toRect()),
      );
      bool validAppendFound = false;

      for (int groupIndex = 0; groupIndex < gameLogic!.table.length && !validAppendFound; groupIndex++) {
        List<CardEntity> tableGroup = gameLogic!.table[groupIndex];
        final groupComponent = children.firstWhereOrNull(
          (c) => c is LabeledSpriteComponent && (c).label == 'tableGroup_$groupIndex',
        ) as LabeledSpriteComponent?;

        print("Collision check with group $groupIndex");

        if (groupComponent == null) continue;

        if (groupComponent.toRect().overlaps(selectedArea)) {
          List<CardEntity> combined = List.from(tableGroup);
          for (var comp in group) {
            combined.add(comp.card);
          }

          // Validate the combined group before updating the table.
          if (gameLogic!.validateMove(combined)) {
            print("Valid append found with group $groupIndex and cards: ${group.map((c) => c.card)}");
            validAppendFound = true;
            gameLogic!.table[groupIndex] = combined;
            gameLogic!.players[playerIndex].removeCardsFromHand(
              group.map((comp) => comp.card).toList(),
            );

            // Update Firestore with new hand and table state
            await firestoreController.updatePlayer(
              gameId,
              gameLogic!.players[playerIndex].id,
              {
                'hand':
                    gameLogic!.players[playerIndex].hand.map((c) => c.toMap()).toList(),
              },
            );
            final tableMap = {
              for (int i = 0; i < gameLogic!.table.length; i++)
                i.toString(): gameLogic!.table[i].map((c) => c.toMap()).toList()
            };
            await firestoreController.updateGameState(gameId, {'table': tableMap});

            break; // stop after a valid append
          }else{
            print("Invalid append found with group $groupIndex and cards: ${group.map((c) => c.card)}");
            resetGroupToOriginalPosition(group);
            break; // stop after an invalid append
          }
        }
      }
    } else {
      print("not out yet");
    }

    // If only one card was dropped, check if it was placed on discard zone
    if (group.length == 1) {
      final card = group.first;
      if (card.position.x > discardZone.left &&
          card.position.x < discardZone.right &&
          card.position.y > discardZone.top &&
          card.position.y < discardZone.bottom) {
        if (await gameLogic!.validateDiscard(card.card)) {
          updateUI();
        } else {
          resetGroupToOriginalPosition(group);
        }
      }
    } else {
      // If multiple cards dropped but not appended to the table, validate them
      if (!gameLogic!.validateMove(group.map((card) => card.card).toList())) {
        resetGroupToOriginalPosition(group);
      }
    }

    CardComponent.selectedCards.clear();
  }

  void resetGroupToOriginalPosition(List<CardComponent> group) {
    for (var cardComponent in group) {
      cardComponent.setHighlighted(false);
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

  //Firestore Controller
  void listenToGameState() {
    firestoreController.listenToGameState(gameId).listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;

      final currentPlayers = data['current_players'] ?? 0;
      maxPlayers = data['max_players'] ?? 0;

      // Check if the game has started
      final isGameStarted = data['isGameStarted'] ?? false;
      if (isGameStarted && !_isGameLogicInitialized) {
        _isGameLogicInitialized = true;
        _initializeGameLogic();
      } else if (waitingForPlayersText.parent != null) {
        _updateWaitingText(currentPlayers);
      }

      if(_isGameLogicInitialized) {
        updateUI();
      }
    });
  }

  void listenToPlayersUpdate() {
    //updateUI();
  }

  void listenToDrawAnimationTrigger() {
    firestoreController.listenToCardDraw(gameId).listen((drawData) {
      if (drawData == null) return;

      final playerIdOfDraw = drawData['playerId'];
      if (playerIdOfDraw == playerId) return;

      final source = drawData['source'];
      final card = source == 'deck'
          ? CardEntity(suit: 'Back', rank: '_Red')
          : CardEntity.fromJson(drawData['card']);

      final Offset from = (source == 'deck')
          ? deckUI.position.toOffset()
          : discardZone.center;

      animateDrawnCard(card, from: from, playerId: playerIdOfDraw);
    });
  }

  @override
  void onTapDown(TapDownInfo info) {
    final tapPosition = info.eventPosition.global;

    if (!gameLogic!.isPlayersTurn(playerId)) return;
    if(gameLogic!.hasDrawnCard) return;

    if (deckUI.toRect().contains(tapPosition.toOffset()) && !gameLogic!.hasDrawnCard) {
      gameLogic!.drawCard('deck');
    } else if (discardZone.contains(tapPosition.toOffset()) && !gameLogic!.hasDrawnCard) {
      if (!gameLogic!.hasDrawnCard) {
        gameLogic!.drawCard('discardPile');
      }
    }
  }

  void animateDrawnCard(CardEntity card, {required Offset from, required String playerId}) async {
    final player = gameLogic!.players.firstWhere(
      (p) => p.id == playerId,
      orElse: () => gameLogic!.players.first,
    );
    final playerName = player.name;

    // Create the animated card
    final animatedCard = SpriteComponent()
      ..sprite = Sprite(await images.load('cards/${card.toString()}.png'))
      ..position =Vector2(from.dx, from.dy)
      ..size = Vector2(50, 70)
      ..anchor = Anchor.center;

    add(animatedCard);

    animatedCard.priority = 100;

    Vector2? targetPosition;

    if (playerId == this.playerId) {
        final currentHandCount = player.hand.length;
        final cardWidth = 50.0;
        final maxSpacing = 50.0;
        final totalWidth = (currentHandCount - 1) * maxSpacing + cardWidth;
        final spacing = totalWidth > size.x ? (size.x - cardWidth) / (currentHandCount - 1) : maxSpacing;
        final handWidth = (currentHandCount - 1) * spacing + cardWidth;
        targetPosition = Vector2((size.x - handWidth) / 2, size.y - 150);
      } else {
        targetPosition = playerPositions[playerName];
      }

    updateUI();
    animatedCard.add(
     MoveEffect.to(
      targetPosition!,
      EffectController(duration: 1.0, curve: Curves.easeInOut),
      onComplete: () {
        remove(animatedCard);
      }
    ));
    await Future.delayed(const Duration(milliseconds: 100));
  }


  void attemptAppendToTable(List<CardComponent> selectedCards) async { // 1) Check if the current player has satisfied the round requirement (isOut). 
    if (!gameLogic!.players[playerIndex].isOut()) { // If not out, no appending allowed: 
      print("Anlegen ist nicht erlaubt, da Spieler nicht aus ist!"); 
      return;
    }
    // 2) Compute the bounding-box for the set of dragged/selected cards.
  //    This helps us detect collisions with existing table groups.
  final selectedArea = selectedCards.fold<Rect>(
    selectedCards.first.toRect(),
    (previous, card) => previous.expandToInclude(card.toRect()),
  );

  bool validAppendFound = false;

  // 3) Loop over all groups already on the table.
  for (int groupIndex = 0; groupIndex < gameLogic!.table.length; groupIndex++) {
    List<CardEntity> tableGroup = gameLogic!.table[groupIndex];

    // For collision detection, we look for a “LabeledSpriteComponent” whose
    // label matches the group index (like 'tableGroup_0', 'tableGroup_1', etc.).
    final groupComponent = children.firstWhere(
      (c) => c is LabeledSpriteComponent && (c).label == 'tableGroup_$groupIndex',
    );

    // If we can’t find a matching group component, continue to next group.
    if (groupComponent == null) continue;

    // 4) Check if the bounding-box for the selected cards overlaps
    //    the bounding-box of the existing group on the table.
    if (groupComponent is PositionComponent && groupComponent.toRect().overlaps(selectedArea)) {
      // Combine the table’s existing group with the currently selected cards.
      List<CardEntity> combined = List.from(tableGroup);
      for (var comp in selectedCards) {
        combined.add(comp.card);
      }

      // 5) Ask our game logic if the combined set is a valid group
      //    (for example, that all suits/ranks match the rules).
      if (gameLogic!.validateMove(combined)) {
        validAppendFound = true;

        // 6) Update the table group in local state:
        gameLogic!.table[groupIndex] = combined;

        // Remove the appended cards from the player’s hand
        // (both locally and in Firestore).
        gameLogic!.players[playerIndex].removeCardsFromHand(
          selectedCards.map((comp) => comp.card).toList(),
        );

        // 7) Update the player’s hand in Firestore
        await firestoreController.updatePlayer(
          gameId,
          gameLogic!.players[playerIndex].id,
          {
            'hand': gameLogic!.players[playerIndex].hand.map((c) => c.toMap()).toList(),
          },
        );

        // 8) Also update the table in Firestore (so that every client sees it).
        final tableMap = {
          for (int i = 0; i < gameLogic!.table.length; i++)
            i.toString(): gameLogic!.table[i].map((c) => c.toMap()).toList()
        };
        await firestoreController.updateGameState(gameId, {'table': tableMap});

        // Because we successfully updated one group, we stop.
        break;
      }
    }
  }

  // 9) If we never found a valid group to attach to, log an error or do an animation.
  if (!validAppendFound) {
    print("Anlegen fehlgeschlagen: Die Kombination ist ungültig oder keine geeignete Tischgruppe gefunden.");
  } else {
    // 10) Otherwise, refresh the UI if successful.
    updateUI();
  }
  }
}