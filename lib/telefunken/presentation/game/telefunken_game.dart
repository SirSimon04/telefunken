import 'dart:math';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:telefunken/telefunken/domain/entities/card_entity.dart';
import 'package:telefunken/telefunken/domain/rules/rule_set.dart';
import 'package:telefunken/telefunken/presentation/game/card_component.dart';

// Domain-Klassen (Beispiel)
import '../../domain/entities/player.dart';
import '../../domain/logic/game_logic.dart';

class TelefunkenGame extends FlameGame {
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
  late SpriteComponent deckUI;
  late RectangleComponent garbageUI;

  TelefunkenGame({
    required this.playerName,
    required this.playerCount,
    required this.roundDuration,
    required this.ruleSet,
  });

  @override
  Future<void> onLoad() async {
    // Lade Hintergrund, UI-Komponenten, etc.
    add(SpriteComponent()
      ..sprite = await loadSprite('background.png')
      ..size = size);

    final deckPosition = Vector2(size.x / 2, size.y / 3);

    // Deck UI
    deckUI = SpriteComponent(
      sprite: await loadSprite('cards/Back_Red.png'),
      position: deckPosition,
      anchor: Anchor.centerRight,
      size: Vector2(50, 70),
    );
    add(deckUI);

    // Garbage UI (Ablagestapel)
    garbageUI = RectangleComponent(
      position: deckPosition + Vector2(10, 0),
      size: Vector2(50, 70),
      anchor: Anchor.centerLeft,
      paint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white,
    );
    add(garbageUI);

    // Text für verbleibende Karten
    cardsLeftText = TextComponent(
      text: 'Cards left: 108',
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
      position: deckPosition + Vector2(0, 50),
      anchor: Anchor.center,
    );
    add(cardsLeftText);

    // Zeige einen Warte-Text, solange noch nicht alle Spieler beigetreten sind.
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
    print('Player ${player.name} joined the game');
    if (!lobbyPlayers.any((p) => p.id == player.id)) {
      lobbyPlayers.add(player);
      updateWaitingText();
    }

    if (lobbyPlayers.length >= playerCount && gameLogic == null) {
      _initializeGameLogic();
    }
  }

  /// Initialisiert die GameLogic und startet das Spiel
  void _initializeGameLogic() {
    gameLogic = GameLogic(
      players: lobbyPlayers,
      ruleSet: ruleSet,
    );

    //Zeige die neue Reihenfolge der Spieler an
    gameLogic!.startGame();
    _displayPlayers(gameLogic!.players);
    playerIndex = gameLogic!.players.indexWhere((player) => player.name == playerName);
    distributeCards(Vector2(size.x / 2, size.y / 3));

  //   for (var player in gameLogic!.players) {
  //     for (var i = 0; i < player.hand.length; i++) {
  //       final cardComponent = CardComponent(
  //         card: player.hand[i],
  //         gameLogic: gameLogic,
  //         onCardTapped: (CardEntity tappedCard) {
  //           print("Karte geklickt: ${tappedCard.toString()}");
  //         },
  //       )
  //         ..position = Vector2(i * 60, gameLogic!.players.indexOf(player) * 100);
  //       add(cardComponent);
  //     }
  //   }
  }

  void updateWaitingText() {
    if(lobbyPlayers.length == playerCount) {
      // Der Text soll für eine Sekunde stehen bleiben, danach soll er entfernt werden
      waitingForPlayersText.text = 'All players joined. Starting game...';
      Future.delayed(Duration(seconds: 1), () {
        remove(waitingForPlayersText);
      });
    } else{
      waitingForPlayersText.text = 'Waiting for ${playerCount - lobbyPlayers!.length} players...';
    }
  }
  void updateCardsLeftText([int? cardsLeft]) {
    cardsLeftText.text = 'Cards left: ${cardsLeft ?? gameLogic?.getDeckLength() ?? 0}';
    if ((gameLogic?.getDeckLength() ?? 0) == 0) {
      remove(deckUI);
    }
  }


  void _displayPlayers(List<Player> players) {
    final deckPosition = Vector2(size.x / 2, size.y / 3);
    final radius = 180.0;

    for(int i=0; i<players.length; i++){
      final angle = (i+1) * (pi / (playerCount + 1));
      final playerPosition = deckPosition - Vector2(radius * cos(angle), radius * sin(angle));
     playerPositions[players[i].name] = playerPosition;
      add(TextComponent(
        text: players[i].name,
        textRenderer: TextPaint(
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
        position: playerPosition,
        anchor: Anchor.center,
      ));
    }
  }

  /// Hier nur die Animation, da die Karten in der Game_Logic verteilt werden!
  Future<void> distributeCards(Vector2 deckPosition) async {
    int count = 0;
    var amountOfCards = lobbyPlayers.length * 11 + 1;
    for(int i=0; i<amountOfCards; i++){
      var playerIndex = i % lobbyPlayers.length;
      await dealCardAnimation(deckPosition, playerPositions[gameLogic?.players[playerIndex].name] ?? Vector2(size.x / 2, size.y - 100));
      count++;
      updateCardsLeftText(108 - count);
    }
    displayCurrentPlayerHand();
    
    for (var player in gameLogic!.players) {
      displayOpponentsHand(player);
    }
  }

  /// Animiert das Austeilen einer Karte vom Deck zu einer Spielerposition
  Future<void> dealCardAnimation(Vector2 startPosition, Vector2 endPosition) async {
    final card = SpriteComponent()
      ..sprite = Sprite(await images.load('cards/Back_Red.png'))
      ..position = startPosition
      ..size = Vector2(50, 70)
      ..anchor = Anchor.centerRight;
    add(card);
    await Future.delayed(Duration(milliseconds: 500));
    //Die Karte soll ganz oben liegen
    card.priority = 10;
    card.add(MoveEffect.to(
      endPosition,
      EffectController(duration: 1.0, curve: Curves.easeInOut),
      onComplete: () => remove(card),
    ));
  }

  /// Zeigt die Hand des aktiven Spielers an
  void displayCurrentPlayerHand() async {
    final int cardCount = gameLogic!.players[playerIndex].hand.length;
    final double cardWidth = 50.0;
    final double minSpacing = 15.0;
    final double maxSpacing = 50.0;
    
    final double totalWidth = (cardCount - 1) * maxSpacing + cardWidth;
    double spacing = totalWidth > size.x ? (size.x - cardWidth) / (cardCount - 1) : maxSpacing;
    spacing = spacing.clamp(minSpacing, maxSpacing);
    final double handWidth = (cardCount - 1) * spacing + cardWidth;
    final Vector2 startPosition = Vector2((size.x - handWidth) / 2, size.y - 150);
    
    for (int i = 0; i < cardCount; i++) {
      final Vector2 cardPosition = startPosition + Vector2(i * spacing, 0);
      // Im Offline-Modus: Aktiver Spieler sieht seine eigene Hand
      String cardAsset = 'cards/${gameLogic?.players[playerIndex].hand[i].toString()}.png';
      
      add(SpriteComponent()
        ..sprite = await loadSprite(cardAsset)
        ..position = cardPosition
        ..anchor = Anchor.bottomLeft
        ..size = Vector2(cardWidth, 70)
        ..priority = 1);
    }
  }

  void displayOpponentsHand(Player player) async {
    final int cardCount = player.hand.length;
    final double cardWidth = 30.0;
    final double spacing = 10.0;
    final Vector2 playerPosition = playerPositions[player.name] ?? Vector2.zero();
    final Vector2 startPosition = playerPosition + Vector2(-((cardCount - 1) * spacing + cardWidth) / 2, 20);

    for (int i = 0; i < cardCount; i++) {
      final Vector2 cardPosition = startPosition + Vector2(i * spacing, 0);
      add(SpriteComponent()
        ..sprite = await loadSprite('cards/Back_Red.png')
        ..position = cardPosition
        ..anchor = Anchor.topLeft
        ..size = Vector2(cardWidth, 42)
        ..priority = 1);
    }
  }

  /// Wechselt zur nächsten Runde (Sprich: zum nächsten Spieler, der nicht KI ist)
  void nextTurn() {
    playerIndex = (playerIndex + 1) % lobbyPlayers.length;
    if (lobbyPlayers[playerIndex].isAI) {
      nextTurn(); // Überspringe KI-Spieler im Offline-Modus
    } else {
      displayCurrentPlayerHand();
    }
  }

  //Buy Button
  void buyCard() {
    if (gameLogic!.getDeckLength() > 0) {
      final card = gameLogic!.deck.dealOne();
      gameLogic!.players[playerIndex].addCardToHand(card);
      displayCurrentPlayerHand();
      updateCardsLeftText();
    }
  }
}