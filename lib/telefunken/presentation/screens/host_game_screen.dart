import 'package:flutter/material.dart';
import 'base_screen.dart';

class HostGameScreen extends StatefulWidget {
  const HostGameScreen({super.key});

  @override
  _HostGameScreenState createState() => _HostGameScreenState();
}

class _HostGameScreenState extends State<HostGameScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controller und Variablen
  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Dropdowns
  int _selectedPlayers = 2; // Standardanzahl
  String _selectedRuleSet = 'Standard'; // Beispielregelwerk
  String _selectedRoundDuration = '60'; // Rundendauer in Sekunden

  bool _usePassword = false;

  // Mögliche Werte
  final List<int> _playerOptions = [2, 3, 4];
  final List<String> _ruleSetOptions = ['Standard', 'Pro', 'Fun'];
  final List<String> _roundDurationOptions = ['30', '60', '90', '120']; // in Sekunden

  @override
  void dispose() {
    _playerNameController.dispose();
    _roomNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startGame() {
    if (_formKey.currentState!.validate()) {
      // Alle Eingaben validiert, hier kannst du den Firestore-Controller aufrufen
      String playerName = _playerNameController.text.trim();
      String roomName = _roomNameController.text.trim();
      String? password = _usePassword ? _passwordController.text.trim() : null;
      int maxPlayers = _selectedPlayers;
      String ruleSet = _selectedRuleSet;
      int roundDuration = int.parse(_selectedRoundDuration);

      // Beispiel-Ausgabe in der Konsole – hier wird dann dein Firestore-Aufruf erfolgen.
      debugPrint('HostGame: playerName=$playerName, roomName=$roomName, maxPlayers=$maxPlayers, '
          'password=${password ?? "no password"}, ruleSet=$ruleSet, roundDuration=$roundDuration sec');

      // Anschließend Navigieren zum GameScreen (oder weitere Logik)
      // Navigator.pushReplacement(...);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      child: Container(

        padding: EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  "Host a Game",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _playerNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _roomNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a room name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Anzahl der Teilnehmer Dropdown
              DropdownButtonFormField<int>(
                value: _selectedPlayers,
                decoration: const InputDecoration(
                  labelText: 'Number of Players',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                items: _playerOptions.map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlayers = value ?? _selectedPlayers;
                  });
                },
              ),
              const SizedBox(height: 20),
              // Regelwerk Dropdown
              DropdownButtonFormField<String>(
                value: _selectedRuleSet,
                decoration: const InputDecoration(
                  labelText: 'Rule Set',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                items: _ruleSetOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRuleSet = value ?? _selectedRuleSet;
                  });
                },
              ),
              const SizedBox(height: 20),
              // Rundendauer Dropdown
              DropdownButtonFormField<String>(
                value: _selectedRoundDuration,
                decoration: const InputDecoration(
                  labelText: 'Round Duration (sec)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                items: _roundDurationOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRoundDuration = value ?? _selectedRoundDuration;
                  });
                },
              ),
              const SizedBox(height: 20),
              // Passwort-Switch und Passwortfeld
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Require Password",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Switch(
                    value: _usePassword,
                    onChanged: (value) {
                      setState(() {
                        _usePassword = value;
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                ],
              ),
              if (_usePassword) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (_usePassword && (value == null || value.trim().isEmpty)) {
                      return 'Please enter a password';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 40),
              Center(
                child: ElevatedButton(
                  onPressed: _startGame,
                  child: const Text("Start Game"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
