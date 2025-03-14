import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

class PlayOfflineScreen extends StatelessWidget {
  const PlayOfflineScreen({super.key});


  // wie viele Nutzer sollen spielen?
  // wie viele KI-Spieler sollen spielen?
  // Schwierigkeitsgrad der KI-Spieler
  // Spiel starten
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: Flame.images.load('background.png'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/background.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Center(
                  child: Text("Hier kommt der Play-Offline Screen", style: TextStyle(color: Colors.white)),
                ),
                Positioned(
                  top: 40,
                  left: 10,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, size: 30, color: Colors.white,),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
