import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/presentation/game/card_component.dart';
import 'package:telefunken/telefunken/presentation/game/labeledTextComponent.dart';
import 'package:telefunken/telefunken/presentation/game/labeled_sprite_component.dart';
import 'package:telefunken/telefunken/presentation/screens/next_round_screen.dart';
import 'package:telefunken/telefunken/service/firestore_controller.dart';
import 'package:collection/collection.dart';
import '../../domain/entities/player.dart';
import '../../domain/logic/game_logic.dart';

class TelefunkenGame extends FlameGame with TapDetector {
  final void Function(
    List<String> playerNames,
    List<List<int>> roundScores,
    List<int> totalScores,
  )? onNextRound;
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
  List<TextComponent> roundConditionComponents = []; // To hold round condition texts

  // Define round conditions (adjust descriptions as needed)
  final List<String> roundConditions = [
    "2 sets of 3", // Round 1
    "1 set of 4", // Round 2
    "2 sets of 4", // Round 3
    "1 set of 5", // Round 4
    "2 sets of 5", // Round 5
    "1 set of 6", // Round 6
    "Sequence of 7", // Round 7
  ];

  bool _isGameLogicInitialized = false;

  TelefunkenGame({
    required this.gameId,
    required this.playerId,
    required this.playerName,
    required this.firestoreController,
    this.onNextRound,
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

    // Initial display of round conditions (will be updated when game starts)
    _displayRoundConditions(1); // Display initially for round 1
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

    // Assign the callback BEFORE syncing, so it's ready
    gameLogic!.onNextRoundStarted = () {
      print("TelefunkenGame: onNextRoundStarted triggered. Starting new round UI.");
      startRound(); // Call the new method to handle UI reset and dealing
    };

    await gameLogic!.syncWithFirestore();
    gameLogic!.listenToGameState();
    gameLogic!.listenToPlayerUpdates();

    _displayPlayers(gameLogic!.players);
    playerIndex = gameLogic!.players.indexWhere((player) => player.id == playerId);
    // Initial round start
    startRound();
  }

  void _displayPlayers(List<Player> players) async {
    // Adjust radius based on player count for better spacing
    final radius = players.length > 3 ? 200.0 : 180.0; // Increase radius for 4+ players
    final totalAngleRange = pi * 0.8; // Distribute over 144 degrees (adjust as needed)
    final startAngle = (pi - totalAngleRange) / 2; // Center the distribution arc

    for (int i = 0; i < players.length; i++) {
      final player = players[i];
      // Calculate angle: distribute evenly across the defined range
      final angle = players.length > 1
          ? startAngle + totalAngleRange * (i / (players.length - 1))
          : pi / 2; // Center single player at the top
      // Calculate position relative to the deck (center point)
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
    // Clear any leftover card components from previous rounds/animations
    children.whereType<CardComponent>().forEach(remove);
    removeSpriteCards('opponentCards');
    removeSpriteCards('tableGroup_'); // Clear all table groups
    removeSpriteCards('discard');

    // Ensure deck UI is visible if deck isn't empty
    if (gameLogic != null && gameLogic!.getDeckLength() > 0 && deckUI.parent == null) {
      add(deckUI);
    }

    int cardsToDealPerPlayer = 11; // Standard Telefunken
    int totalCardsToDeal = maxPlayers * cardsToDealPerPlayer;
    int dealtCount = 0;

    // Make sure playerPositions are ready
    if (playerPositions.length != maxPlayers) {
      print("Warning: Player positions not fully initialized before dealing.");
      // Optionally re-run _displayPlayers or wait
      await Future.delayed(Duration(milliseconds: 100)); // Small delay
    }

    print("Distributing $cardsToDealPerPlayer cards to $maxPlayers players.");
    for (int cardIndex = 0; cardIndex < cardsToDealPerPlayer; cardIndex++) {
      for (int playerIdx = 0; playerIdx < maxPlayers; playerIdx++) {
        final targetPlayer = gameLogic!.players[playerIdx];
        final targetPosition = playerPositions[targetPlayer.name];

        if (targetPosition == null) {
          print("Error: Could not find position for player ${targetPlayer.name}");
          continue; // Skip dealing to this player if position is missing
        }

        await _dealCardAnimation(
          deckPos,
          targetPosition,
        );
        dealtCount++;
        _updateCardsLeftText(108 - dealtCount); // Assuming 108 total cards initially
      }
    }
    print("Finished distributing cards.");
    // Update UI after dealing animation is complete
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

    // Randomly determine if the card should spin
    final shouldSpin = Random().nextBool();

    if (shouldSpin) {
      // Add a rotation effect with a random angle
      final randomAngle = Random().nextDouble() * pi * 2; // Random angle between 0 and 360 degrees
      card.add(
        RotateEffect.by(
          randomAngle,
          EffectController(
            duration: 1.0,
            curve: Curves.easeInOut,
          ),
        ),
      );
    }

    // Add the move effect
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
        game: this, // Pass the TelefunkenGame instance
      ));
    }
  }

  void handleDragOnPlayedMove(List<CardEntity> moveEntities) {
    print("Drag detected on a card within currentMoves. Resetting move: $moveEntities");
    // Find the CardComponent instances corresponding to the moveEntities
    final componentsToReset = children.whereType<CardComponent>().where((comp) {
      // Ensure the component is actually part of the player's hand currently
      return comp.ownerId == playerId && moveEntities.any((entity) => entity.toString() == comp.card.toString());
    }).toList();

    if (componentsToReset.isNotEmpty) {
      resetGroupToOriginalPosition(componentsToReset);
    } else {
      print("Warning: Could not find CardComponents to reset for move: $moveEntities");
      // Fallback: Still remove from gameLogic.currentMoves if possible
      gameLogic?.removeMove(moveEntities);
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

    for (int groupIndex = 0; groupIndex < gameLogic!.table.length; groupIndex++) {
      var group = gameLogic!.table[groupIndex];
      final groupWidth = group.length * (cardWidth + cardSpacing) - cardSpacing;

      if (currentX + groupWidth > tableZone.right) {
        currentX = tableZone.left;
        currentY += cardHeight + groupPadding;
      }

      for (int i = 0; i < group.length; i++) {
        final card = group[i];
        final position = Vector2(currentX + i * (cardWidth + cardSpacing), currentY);
        // Use groupIndex in the label
        add(LabeledSpriteComponent(label: 'tableGroup_$groupIndex')
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
      print("UpdateUI called but game not ready. Skipping.");
      return;
    }
    print("Updating UI...");

    if (gameLogic!.isGameOver()) {
      print("Game Over");
      showWinningScreen();
      return;
    }

    // Clear previous state components first
    children.whereType<CardComponent>().forEach(remove); // Clear player's hand cards
    removeSpriteCards('opponentCards');
    removeSpriteCards('discard');
    removeSpriteCards('tableGroup_'); // Clear all table groups

    _updateCardsLeftText();
    displayCurrentPlayerHand(); // Display new hand
    displayOpponentsHand(); // Display opponent backs
    showTable(); // Display current table state (might be empty at round start)
    showDiscardPile(); // Display current discard pile (might be empty)
    updatePlayersText(); // Update player names/highlighting
    updateCoinTexts(); // Update coin display
    print("UI Update finished.");
  }

  void updatePlayersText() async {
    children.whereType<LabeledTextComponent>().forEach((component) {
      if (component.label == 'playerName') {
        remove(component);
      }
    });

    //wait one second
    await Future.delayed(const Duration(microseconds: 200));
    for (var player in gameLogic!.players) {
      final playerPos = playerPositions[player.name] ?? Vector2.zero();
      var text = player.name == playerName ? 'You' : player.name;

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

  void removeSpriteCards(String labelPrefix) {
    // Use startsWith for labels like 'tableGroup_'
    final toRemove = children
        .where((c) => c is LabeledSpriteComponent && c.label.startsWith(labelPrefix))
        .toList();
    if (toRemove.isNotEmpty) {
      print("Removing ${toRemove.length} components with label prefix '$labelPrefix'");
      removeAll(toRemove);
    }
  }

  void handleCardsDrop(List<CardComponent> group) async {
    if (!gameLogic!.isPlayersTurn(gameLogic!.players[playerIndex].id) || gameLogic!.isPaused()) {
      resetGroupToOriginalPosition(group);
      CardComponent.selectedCards.clear();
      return;
    }

    if (gameLogic!.players[playerIndex].isOut()) {
      final selectedArea = group.fold<Rect>(
        group.first.toRect(),
        (previous, card) => previous.expandToInclude(card.toRect()),
      );
      bool validAppendFound = false;

      for (int groupIndex = 0; groupIndex < gameLogic!.table.length && !validAppendFound; groupIndex++) {
        List<CardEntity> tableGroup = gameLogic!.table[groupIndex];
        // Find ALL components for this group index
        final tableGroupComponents = children
            .whereType<LabeledSpriteComponent>()
            .where((c) => c.label == 'tableGroup_$groupIndex')
            .toList();

        print("Collision check with group $groupIndex");

        if (tableGroupComponents.isEmpty) continue; // Skip if no components found for this group

        // Calculate the combined Rect for the entire group on the table
        Rect tableGroupArea = tableGroupComponents.first.toRect();
        for (int i = 1; i < tableGroupComponents.length; i++) {
          tableGroupArea = tableGroupArea.expandToInclude(tableGroupComponents[i].toRect());
        }

        print("Calculated table group area: $tableGroupArea");
        print("Selected cards area: $selectedArea");

        // Use the combined area for overlap check
        if (tableGroupArea.overlaps(selectedArea)) {
          List<CardEntity> combined = List.from(tableGroup);
          for (var comp in group) {
            combined.add(comp.card);
          }

          // Validate the combined group before updating the table.
          if (gameLogic!.validateMove(combined, false)) {
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
                'hand': gameLogic!.players[playerIndex].hand.map((c) => c.toMap()).toList(),
              },
            );
            final tableMap = {
              for (int i = 0; i < gameLogic!.table.length; i++)
                i.toString(): gameLogic!.table[i].map((c) => c.toMap()).toList()
            };
            await firestoreController.updateGameState(gameId, {'table': tableMap});

            break; // stop after a valid append
          } else {
            print("Invalid append found with group $groupIndex and cards: ${combined.map((c) => c.toString())}");
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
    // Extract the CardEntity list from the CardComponent list
    final List<CardEntity> cardEntities = group.map((comp) => comp.card).toList();

    // Call GameLogic to remove this specific move from currentMoves
    if (gameLogic != null) {
      gameLogic!.removeMove(cardEntities);
    }

    // Reset visual position and highlighting
    for (var cardComponent in group) {
      cardComponent.setHighlighted(false);
      if (cardComponent.originalPosition != null) {
        cardComponent.add(MoveEffect.to(
          cardComponent.originalPosition!,
          EffectController(duration: 0.5, curve: Curves.easeOut),
        ));
      } else {
        // Fallback if originalPosition is somehow null (shouldn't happen often)
        print("Warning: originalPosition was null for card ${cardComponent.card}");
        // Maybe remove the component or move it to a default spot
      }
    }
    // Ensure selectedCards is cleared after resetting
    CardComponent.selectedCards.clear();
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

  // New method to display round conditions
  void _displayRoundConditions(int currentRound) {
    // Remove previous round condition texts
    removeAll(roundConditionComponents);
    roundConditionComponents.clear();

    final startY = 20.0; // Starting Y position for the first condition
    final spacingY = 20.0; // Vertical spacing between conditions
    final startX = 20.0; // X position

    for (int i = 0; i < roundConditions.length; i++) {
      final roundNum = i + 1;
      final conditionText = "$roundNum. ${roundConditions[i]}";
      final isCurrent = roundNum == currentRound;

      final textStyle = TextStyle(
        fontSize: 16,
        color: isCurrent ? Colors.red : Colors.white, // Red if current, white otherwise
        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
      );

      final textComponent = TextComponent(
        text: conditionText,
        textRenderer: TextPaint(style: textStyle),
        position: Vector2(startX, startY + i * spacingY),
        anchor: Anchor.topLeft,
      );

      roundConditionComponents.add(textComponent);
      add(textComponent);
    }
  }

  // New method to start a round
  void startRound() async {
    print("Starting round UI setup...");
    if (gameLogic == null) {
      print("Error: GameLogic not initialized in startRound.");
      return;
    }
    // 1. Clear existing game elements from the board
    children.whereType<CardComponent>().forEach(remove);
    removeSpriteCards('opponentCards');
    removeSpriteCards('tableGroup_'); // Clear all table groups using prefix
    removeSpriteCards('discard');

    // 1.5 Update Round Conditions Display
    _displayRoundConditions(gameLogic!.roundNumber); // Update based on current round

    // 2. Ensure deck is visible (it might have been removed if empty before)
    if (gameLogic != null && gameLogic!.getDeckLength() > 0 && deckUI.parent == null) {
      add(deckUI);
      print("Deck UI added back.");
    } else if (gameLogic != null && gameLogic!.getDeckLength() == 0 && deckUI.parent != null) {
      remove(deckUI);
      print("Deck UI removed (deck empty).");
    }

    // 3. Distribute cards with animation
    await _distributeCards(deckPosition);

    // 4. UpdateUI is called at the end of _distributeCards now.
    //    If you need immediate updates before animation finishes, call parts of updateUI here.
    print("Round UI setup complete.");
  }

  // Firestore Controller
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

      if (_isGameLogicInitialized) {
        updateUI();
      }
    });
  }

  void listenToPlayersUpdate() {
    //
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
    if (gameLogic!.hasDrawnCard) return;

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
      ..position = Vector2(from.dx, from.dy)
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
    animatedCard.add(MoveEffect.to(
      targetPosition!,
      EffectController(duration: 1.0, curve: Curves.easeInOut),
      onComplete: () {
        remove(animatedCard);
      },
    ));
    await Future.delayed(const Duration(milliseconds: 100));
  }
}