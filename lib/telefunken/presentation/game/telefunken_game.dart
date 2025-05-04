import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/config/navigator_key.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/presentation/game/card_component.dart';
import 'package:telefunken/telefunken/presentation/game/labeledTextComponent.dart';
import 'package:telefunken/telefunken/presentation/game/labeled_sprite_component.dart';
import 'package:telefunken/telefunken/service/firestore_controller.dart';
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
  List<TextComponent> roundConditionComponents = [];
  late bool distributed = true;

  final List<String> roundConditions = [
    "2 sets of 3",
    "1 set of 4",
    "2 sets of 4",
    "1 set of 5",
    "2 sets of 5",
    "1 set of 6",
    "Sequence of 7",
  ];

  bool _isGameLogicInitialized = false;
  bool _isGameOverDialogShown = false;
  StreamSubscription? _rematchSubscription;

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
    _listenToGameUpdates();
  }

  @override
  void onRemove() {
    _rematchSubscription?.cancel();
    super.onRemove();
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

    _displayRoundConditions(1);
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

    gameLogic!.onNextRoundStarted = () {
      startRound();
    };

    await gameLogic!.syncWithFirestore();
    gameLogic!.listenToGameState();
    gameLogic!.listenToPlayerUpdates();

    _displayPlayers(gameLogic!.players);
    playerIndex = gameLogic!.players.indexWhere((player) => player.id == playerId);
    startRound();
  }

  void _displayPlayers(List<Player> players) async {
    final radius = players.length > 3 ? 200.0 : 180.0;
    final totalAngleRange = pi * 0.8;
    final startAngle = (pi - totalAngleRange) / 2;

    for (int i = 0; i < players.length; i++) {
      final player = players[i];
      final angle = players.length > 1
          ? startAngle + totalAngleRange * (i / (players.length - 1))
          : pi / 2;
      final playerPos = deckPosition - Vector2(radius * cos(angle), radius * sin(angle));
      playerPositions[player.name] = playerPos;

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
    distributed = false;
    children.whereType<CardComponent>().forEach(remove);
    removeSpriteCards('opponentCards');
    removeSpriteCards('tableGroup_');
    removeSpriteCards('discard');

    if (gameLogic != null && gameLogic!.getDeckLength() > 0 && deckUI.parent == null) {
      add(deckUI);
    }

    int cardsToDealPerPlayer = 11;
    int dealtCount = 0;

    if (playerPositions.length != maxPlayers) {
      await Future.delayed(Duration(milliseconds: 100));
    }

    for (int cardIndex = 0; cardIndex < cardsToDealPerPlayer; cardIndex++) {
      for (int playerIdx = 0; playerIdx < maxPlayers; playerIdx++) {
        final targetPlayer = gameLogic!.players[playerIdx];
        final targetPosition = playerPositions[targetPlayer.name];

        if (targetPosition == null) {
          continue;
        }

        await _dealCardAnimation(
          deckPos,
          targetPosition,
        );
        dealtCount++;
        _updateCardsLeftText(108 - dealtCount);
      }
    }
    distributed = true;
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

    final shouldSpin = Random().nextBool();

    if (shouldSpin) {
      final randomAngle = Random().nextDouble() * pi * 2;
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
        game: this,
      ));
    }
  }

  void handleDragOnPlayedMove(List<CardEntity> moveEntities) {
    final componentsToReset = children.whereType<CardComponent>().where((comp) {
      return comp.ownerId == playerId && moveEntities.any((entity) => entity.toString() == comp.card.toString());
    }).toList();

    if (componentsToReset.isNotEmpty) {
      resetGroupToOriginalPosition(componentsToReset);
    } else {
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
      return;
    }
    if(!distributed) {
      return;
    }

    children.whereType<CardComponent>().forEach(remove);
    removeSpriteCards('opponentCards');
    removeSpriteCards('discard');
    removeSpriteCards('tableGroup_');

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

    await Future.delayed(const Duration(microseconds: 200));
    for (var player in gameLogic!.players) {
      final playerPos = playerPositions[player.name] ?? Vector2.zero();
      var text = player.name == playerName ? 'You' : player.name;

      TextStyle textStyle = const TextStyle(fontSize: 18, color: Colors.white);
      if (gameLogic!.isPlayersTurn(player.id)) {
        textStyle = const TextStyle(
          fontSize: 20,
          color: Colors.orange,
          fontWeight: FontWeight.bold,
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
      if (playerCoinSprites.containsKey(player.id)) {
        for (var coinSprite in playerCoinSprites[player.id]!) {
          remove(coinSprite);
        }
        playerCoinSprites[player.id]!.clear();
      }

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
    final toRemove = children
        .where((c) => c is LabeledSpriteComponent && c.label.startsWith(labelPrefix))
        .toList();
    if (toRemove.isNotEmpty) {
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
        final tableGroupComponents = children
            .whereType<LabeledSpriteComponent>()
            .where((c) => c.label == 'tableGroup_$groupIndex')
            .toList();


        if (tableGroupComponents.isEmpty) continue;

        Rect tableGroupArea = tableGroupComponents.first.toRect();
        for (int i = 1; i < tableGroupComponents.length; i++) {
          tableGroupArea = tableGroupArea.expandToInclude(tableGroupComponents[i].toRect());
        }


        if (tableGroupArea.overlaps(selectedArea)) {
          List<CardEntity> combined = List.from(tableGroup);
          for (var comp in group) {
            combined.add(comp.card);
          }

          if (gameLogic!.validateMove(combined, false)) {
            validAppendFound = true;
            gameLogic!.table[groupIndex] = combined;
            gameLogic!.players[playerIndex].removeCardsFromHand(
              group.map((comp) => comp.card).toList(),
            );

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

            break;
          } else {
            resetGroupToOriginalPosition(group);
            break;
          }
        }
      }
    } else {
      //not out yet
    }

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
      if (!gameLogic!.validateMove(group.map((card) => card.card).toList())) {
        resetGroupToOriginalPosition(group);
      }
    }

    CardComponent.selectedCards.clear();
  }

  void resetGroupToOriginalPosition(List<CardComponent> group) {
    final List<CardEntity> cardEntities = group.map((comp) => comp.card).toList();

    if (gameLogic != null) {
      gameLogic!.removeMove(cardEntities);
    }

    for (var cardComponent in group) {
      cardComponent.setHighlighted(false);
      if (cardComponent.originalPosition != null) {
        cardComponent.add(MoveEffect.to(
          cardComponent.originalPosition!,
          EffectController(duration: 0.5, curve: Curves.easeOut),
        ));
      } else {
        // Fallback
      }
    }
    CardComponent.selectedCards.clear();
  }

  void _displayRoundConditions(int currentRound) {
    removeAll(roundConditionComponents);
    roundConditionComponents.clear();

    final startY = 20.0;
    final spacingY = 20.0;
    final startX = 20.0;

    for (int i = 0; i < roundConditions.length; i++) {
      final roundNum = i + 1;
      final conditionText = "$roundNum. ${roundConditions[i]}";
      final isCurrent = roundNum == currentRound;

      final textStyle = TextStyle(
        fontSize: 16,
        color: isCurrent ? Colors.red : Colors.white,
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

  void startRound() async {
    if (gameLogic == null) {
      return;
    }
    children.whereType<CardComponent>().forEach(remove);
    removeSpriteCards('opponentCards');
    removeSpriteCards('tableGroup_');
    removeSpriteCards('discard');

    _displayRoundConditions(gameLogic!.roundNumber);

    if (gameLogic != null && gameLogic!.getDeckLength() > 0 && deckUI.parent == null) {
      add(deckUI);
    } else if (gameLogic != null && gameLogic!.getDeckLength() == 0 && deckUI.parent != null) {
      remove(deckUI);
    }

    await _distributeCards(deckPosition);

  }

  void listenToGameState() {
    firestoreController.listenToGameState(gameId).listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;

      final currentPlayers = data['current_players'] ?? 0;
      maxPlayers = data['max_players'] ?? 0;

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
    // Placeholder
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

  void _listenToGameUpdates() {
    _rematchSubscription?.cancel();

    _rematchSubscription = firestoreController.listenToGameState(gameId).listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      bool isGameOver = data['isGameOver'] ?? false;
      String? winnerName = data['winner'] as String?;
      int currentRound = data['roundNumber'] ?? 0;

      if (isGameOver && !_isGameOverDialogShown && winnerName != null) {
        _isGameOverDialogShown = true;
        List<Player> finalPlayers = gameLogic?.players ?? [];
        if (buildContext != null) {
           _showGameOverDialog(buildContext!, winnerName, finalPlayers);
        } else {
           Future.delayed(Duration.zero, () {
              if (buildContext != null) {
                 _showGameOverDialog(buildContext!, winnerName, finalPlayers);
              }
           });
        }
      }
      else if (!isGameOver && _isGameOverDialogShown) {
         _isGameOverDialogShown = false;
         if (navigatorKey.currentContext != null && Navigator.of(navigatorKey.currentContext!, rootNavigator: true).canPop()) {
             Navigator.of(navigatorKey.currentContext!, rootNavigator: true).pop();
         }
         if (gameLogic != null) {
            gameLogic!.gameOver = false;
            gameLogic!.roundNumber = 1;
            startRound();
         }
      }
      else if (!isGameOver && gameLogic != null && gameLogic!.roundNumber != currentRound && currentRound > 0) {
         // Normal next round transition
      }

      if (gameLogic != null) {
         gameLogic!.paused = data['isGamePaused'] ?? false;
      }

    });
  }

  void _showGameOverDialog(BuildContext context, String winnerName, List<Player> finalPlayers) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: firestoreController.listenToGameState(gameId),
          builder: (context, snapshot) {
            int readyCount = 0;
            List<dynamic> readyPlayersList = [];
            bool localPlayerIsReady = false;

            if (snapshot.hasData && snapshot.data!.exists) {
              final gameData = snapshot.data!.data()!;
              readyPlayersList = gameData['readyPlayers'] ?? [];
              readyCount = readyPlayersList.length;
              localPlayerIsReady = readyPlayersList.contains(playerId);
            }

            final int totalPlayers = gameLogic?.maxPlayers ?? finalPlayers.length;

            return AlertDialog(
              title: Text('Game Over!'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$winnerName has won the game!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 15),
                    Text('Final Scores:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    DataTable(
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('Player')),
                        DataColumn(label: Text('Points'), numeric: true),
                      ],
                      rows: finalPlayers.map((player) {
                        return DataRow(cells: [
                          DataCell(Text(player.name)),
                          DataCell(Text(player.getPoints().toString())),
                        ]);
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Back to Menu'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  },
                ),
                TextButton(
                  onPressed: localPlayerIsReady ? null : () {
                    gameLogic?.handlePlayAgain(playerId);
                  },
                  child: Text(
                    localPlayerIsReady
                      ? 'Waiting for others...'
                      : 'Play Again ($readyCount/$totalPlayers)',
                  ),
                ),
              ],
            );
          }
        );
      },
    );
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