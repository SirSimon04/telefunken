# Telefunken Card Game


## Podman usage
- only tested with podman, but docker should work as well
- Podman version: 5.4.2
- `docker build -t telefunken .` to build the image
- `podman run -i -p 8080:9000 -td localhost/telefunken:latest`

## Overview
The Telefunken project implements a card game with specific rules for validating moves. The game allows players to use cards in groups or sequences, with special handling for wildcards (Jokers and 2s). This README provides an overview of the project structure, setup instructions, and testing guidelines.

## Project Structure
```
telefunkenMain
├── lib
│   └── telefunken
│       └── domain
│           └── rules
│               └── standard_rule_set.dart  # Contains the StandardRuleSet class for game rules
├── test
│   └── rulesets
│       └── standardruleset_test.dart       # Contains unit tests for the StandardRuleSet class
└── README.md                                 # Project documentation
```

## Setup Instructions
1. Clone the repository:
   ```
   git clone <repository-url>
   ```
2. Navigate to the project directory:
   ```
   cd telefunkenMain
   ```
3. Install the necessary dependencies:
   ```
   flutter pub get
   ```

## Running Tests
To ensure that the game rules are correctly implemented, unit tests are provided. You can run the tests using the following command:
```
flutter test
```

## Usage
The `StandardRuleSet` class in `standard_rule_set.dart` implements the rules for validating moves in the game. It includes methods for:
- Validating groups of cards
- Validating sequences of cards
- Handling wildcards (Jokers and 2s)
- Ensuring that the number of wildcards does not exceed the number of normal cards

The test cases in `standardruleset_test.dart` cover various scenarios to ensure the correctness of the game logic.

## Contributing
Contributions to the project are welcome. Please submit a pull request with your changes or open an issue for discussion.

## License
This project is licensed under the MIT License. See the LICENSE file for details.
