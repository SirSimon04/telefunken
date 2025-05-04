import 'package:flutter/material.dart';

class NextRoundScreen extends StatefulWidget {
  final List<String> playerNames;
  final List<List<int>> roundScores;
  final List<int> totalScores;

  const NextRoundScreen({
    Key? key,
    required this.playerNames,
    required this.roundScores,
    required this.totalScores,
  }) : super(key: key);

  @override
  _NextRoundScreenState createState() => _NextRoundScreenState();
}

class _NextRoundScreenState extends State<NextRoundScreen> {
  @override
  void initState() {
    super.initState();
    // Automatische Navigation zurück nach 10 Sekunden
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.of(context).pop(); // Zurück zum vorherigen Bildschirm
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rundenübersicht'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Table(
            border: TableBorder.all(),
            columnWidths: {
              0: const FixedColumnWidth(100.0), // Runde
              1: const FlexColumnWidth(), // Spieler 1
              2: const FlexColumnWidth(), // Spieler 2
            },
            children: _buildTableRows(),
          ),
        ),
      ),
    );
  }

  List<TableRow> _buildTableRows() {
    List<TableRow> rows = [
      // Kopfzeile
      TableRow(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(''),
          ),
          ...widget.playerNames.map((name) => Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(name, textAlign: TextAlign.center),
              )),
        ],
      ),
      // Runden
      ...List.generate(
        7,
        (index) => TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Runde ${index + 1}'),
            ),
            ...widget.playerNames.asMap().entries.map((entry) {
              final playerIndex = entry.key;
              final score = widget.roundScores.length > index
                  ? (widget.roundScores[index].length > playerIndex
                      ? '${widget.roundScores[index][playerIndex]} Punkte'
                      : '-')
                  : '-';
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(score, textAlign: TextAlign.center),
              );
            }),
          ],
        ),
      ),
      // Gesamtpunktzahl
      TableRow(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Gesamtpunktzahl'),
          ),
          ...widget.playerNames.asMap().entries.map((entry) {
            final playerIndex = entry.key;
            final totalScore = '${widget.totalScores[playerIndex]} Punkte';
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(totalScore, textAlign: TextAlign.center),
            );
          }),
        ],
      ),
    ];
    return rows;
  }
}