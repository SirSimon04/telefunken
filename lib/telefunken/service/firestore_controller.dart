// Enthält alle Firestore-CRUD-Operationen (Spiel erstellen, joinen, Starten, Spielstatus beobachten, etc.).

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:logging/logging.dart';

// class FirestoreController {
//   static final _log = Logger('FirestoreController');
//   final FirebaseFirestore instance;
//   final BoardState boardState;

//   FirestoreController(this.instance, this.boardState);

//   Future<void> initializeGame({
//     required int playerCount,
//     required String gameName,
//     required String password,
//     required String ruleset,
//   }) async {
//     try {
//       await instance.collection('games').add({
//         'playerCount': playerCount,
//         'gameName': gameName,
//         'password': password,
//         'ruleset': ruleset,
//         'createdAt': FieldValue.serverTimestamp(),
//       });
//       _log.info('Game initialized successfully');
//     } catch (e) {
//       _log.severe('Failed to initialize game: $e');
//     }
//   }
// }