import 'rule_set.dart';
import '../entities/deck.dart';
import '../entities/player.dart';
import '../entities/card_entity.dart';

class StandardRuleSet extends RuleSet {
  final Map<String, int> rankValues = {
    'Joker': 0,
    '2': 0,
    '3': 3,
    '4': 4,
    '5': 5,
    '6': 6,
    '7': 7,
    '8': 8,
    '9': 9,
    '10': 10,
    'J': 11,
    'Q': 12,
    'K': 13,
    'A': 14,
  };

  //Mein Plan:
  // Ein Spieler kann immer Karten ablegen. Dabei wird sofort geprüft ob dieser "Move" gültig ist.
  // Ein Spieler kann mehrere "Moves" machen
  // Zum Schluss, wenn die "Discard" Karte abgelegt wird, wird geprüft, ob die Spielzüge dem Austrittskriterium der jeweiligen Runde entsprechen und/oder ob der Spieler bereits "isOut" ist.
  // Wenn der Spieler bereits "isOut" ist, wird nur geprüft, ob die Moves gültig waren
  // Die Moves werden in der Klasse "GameLogic" als "currentMoves" gespeichert.
  // Sobald ein Move jedoch invalide ist, geht dieser wieder direkt zur Ausgangsposition und wird nicht verändert

  

  @override
  bool validateDiscard(CardEntity card) {
    if(card.suit == 'Joker' || card.rank == '2' ) {
      print("Joker or 2 are not allowed to be discarded");
      return false;
    }else{
      return true;
    }
  }

 // Hilfsmethode: Ermittelt, ob eine Karte als Joker gilt.
  // Nur Karten mit suit "Joker" gelten als echte Joker – Karten mit Rank "2" sind normale Karten.
    bool _isJoker(CardEntity c) {
      return c.suit.toLowerCase() == 'joker';
    }

  @override
  bool validateMove(List<CardEntity> cards) {
    if (cards.isEmpty) return false;
    if(cards.length < 3) return false; //Es müssen immer mindestens 3 Karten nebeneinander liegen
    bool isGroup = false;
    bool isSequence = false;

    int JokerCount = 0;
    int twoCount = 0;

    for (var card in cards) {
      if (_isJoker(card)) {
        JokerCount++;
      } else if (card.rank == '2') {
        twoCount++;
      }
    }
    if(JokerCount > cards.length/2){
      print("More Joker than normal cards");
      return false;
    }
    
    //check for groups:
    int rank = rankValues[cards[0].rank]!;
    for(int i=0; i<cards.length; i++){
      if(rankValues[cards[i].rank] != rank){
        if(rankValues[cards[i].rank] == 0){

          continue; //Just a joker
        }else{
          break; //Not a group or wrong move
        }
      }
      isGroup = true;
    } 

    //check for sequence:
    String suit = cards.first.suit == 'Joker' ? cards[1].suit : cards.first.suit;
    for(int i=0; i<cards.length; i++){
      if(cards[i].suit != suit){
        if(rankValues[cards[i].rank] == 0){
          rank++;
          continue; //Just a joker
        }else{
          break; //Not a sequence or wrong move
        }
      }else{
        rank++;
        isSequence = true;
      }
      isSequence = true;
    }

    return isGroup || isSequence;
  }

  @override
  bool validateRoundCondition(List<List<CardEntity>> cards, int roundNumber) {
    return true;
  }
}