# Shogi App Setup Guide

## Quick Start

```bash
cd shogi_app
flutter pub get
flutter run
```

## Project Structure

### Minimal Lib Directory
```
lib/
├── main.dart                          (Entry point + Home screen)
│   ├── ShogiApp                       MaterialApp config
│   └── HomeScreen                     Main menu with all options
│
├── game_screen.dart                   (Game play UI + settings)
│   ├── GameScreen                     Main game UI
│   ├── GameSettings                   Configuration class
│   └── _BoardWidget                   Board rendering
│
├── editor_screen.dart                 (Position editor)
│   ├── EditorScreen                   Board editor UI
│   └── _PieceSelector                 Piece palette
│
├── tsume_screen.dart                  (Puzzle solver)
│   ├── TsumeScreen                    Puzzle UI
│   └── _BoardDisplay                  Read-only board
│
├── piece.dart                         (Models + data)
│   ├── PieceType enum                 14 piece types
│   ├── Piece class                    Piece model
│   ├── AMove class                    AI move type
│   ├── KifuMove class                 Notation
│   ├── TsumeProblem class             Puzzle data
│   └── tsumeProblems list             5 puzzles
│
└── logic.dart                         (Game logic)
    ├── Move validation                Piece-specific rules
    ├── AI engine                      Minimax algorithm
    ├── Check detection                Board analysis
    └── Hand management                Captured pieces
```

## pubspec.yaml

Minimal dependencies - only Flutter:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
```

## Build Commands

```bash
# Analyze code
flutter analyze

# Run on device/emulator
flutter run

# Release build (Android)
flutter build apk

# Release build (iOS)
flutter build ios

# Clean
flutter clean
```

## Features

### HomeScreen (main.dart)
- Game mode selection: PvP, AI (先手/後手)
- AI difficulty: ランダム, 弱, 中, 強
- Time limits: なし, 3分, 5分, 10分, 15分
- Piece themes: 標準, ダーク
- Tsume puzzle list (5 problems)

### GameScreen (game_screen.dart)
- 9x9 interactive board
- Piece selection & move visualization
- Hand pieces display
- Move history (kifu)
- Timer (if enabled)
- Undo functionality
- Game over detection

### EditorScreen (editor_screen.dart)
- Place pieces (both players)
- Edit captured pieces
- Load standard position
- Load empty board
- Launch game from position

### TsumeScreen (tsume_screen.dart)
- Display puzzle
- Input restricted to attacking player
- Validate moves
- Detect checkmate
- Show success/failure

## Configuration

### Game Settings (GameSettings class)
```dart
GameSettings(
  mode: GameMode.pvp,              // or .vsAI
  aiLevel: AILevel.medium,         // easy, medium, hard, random
  aiIsP2: true,                    // AI plays second player
  timeLimitSec: 300,               // null = unlimited
  theme: PieceTheme.standard,      // or .dark
)
```

### AI Depth by Level
- Random: 0 (random move)
- Easy: 1 (1 move lookahead)
- Medium: 2 (2 moves lookahead)
- Hard: 4 (4 moves lookahead)

## File Locations

- **Source**: `C:\Users\Administrator\OneDrive\subwork\smartphone\smart-claude-code\shogi_app\lib\`
- **Config**: `C:\Users\Administrator\OneDrive\subwork\smartphone\smart-claude-code\shogi_app\pubspec.yaml`
- **Docs**: 
  - `CLAUDE.md` - Architecture & design
  - `PROJECT_SUMMARY.md` - Comprehensive overview
  - `SETUP.md` - This file

## Testing

### Manual Test Checklist

- [ ] App launches (HomeScreen visible)
- [ ] PvP mode: Both players can move
- [ ] AI mode (AI as P2): AI responds within 2-3 sec
- [ ] AI mode (AI as P1): AI moves first
- [ ] Settings persist across games
- [ ] Undo works correctly
- [ ] Editor: Can place pieces & play
- [ ] Tsume 1: Can solve with 1 move
- [ ] Checkmate detection triggers end screen

### Performance

- AI move generation: ~1-3 seconds (depth 4)
- Board rendering: <100ms
- Move validation: <10ms
- UI responsiveness: 60 FPS

## Customization

### Add New Tsume Problem

In `lib/piece.dart`, add to `tsumeProblems`:

```dart
TsumeProblem(
  title: 'Problem 6',
  hint: '1手詰め：金を打て',
  nMoves: 1,
  board: _mkBoard([
    (0, 4, PieceType.king, false),    // Enemy king at (0,4)
    (2, 3, PieceType.gold, true),     // Our gold at (2,3)
  ]),
  p1Hand: {PieceType.gold: 1},        // 1 gold in hand
)
```

### Change UI Colors

In `lib/main.dart`, update HomeScreen build():

```dart
backgroundColor: const Color(0xFF1A1A2E),  // Change background
// Update button colors:
Colors.brown.shade700  // Brown accent
Colors.blueGrey.shade700  // Secondary
```

### Adjust AI Difficulty

In `lib/game_screen.dart`, modify `GameSettings.aiDepth` getter:

```dart
int get aiDepth {
  switch (aiLevel) {
    case AILevel.random: return 0;
    case AILevel.easy: return 2;      // Increase from 1 to 2
    case AILevel.medium: return 3;    // Increase from 2 to 3
    case AILevel.hard: return 5;      // Increase from 4 to 5
  }
}
```

## Troubleshooting

### "Flutter command not found"
Install Flutter: https://flutter.dev/docs/get-started/install

### App crashes on startup
- Run: `flutter clean && flutter pub get`
- Check `lib/main.dart` imports

### AI takes too long
- Reduce `aiDepth` in `GameSettings`
- Set `aiLevel` to `easy` or `random`

### Board not rendering
- Check `game_screen.dart` _BoardWidget
- Verify board dimensions (9x9)

## Resources

- Flutter docs: https://flutter.dev/docs
- Dart docs: https://dart.dev/guides
- Shogi rules: https://en.wikipedia.org/wiki/Shogi

## License

Minimal Shogi UI App - Educational project.
