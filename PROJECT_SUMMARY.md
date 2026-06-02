# Shogi App - Project Summary

## Project Structure

```
shogi_app/
├── lib/
│   ├── main.dart           (261 lines)  - App entry + HomeScreen with settings
│   ├── game_screen.dart    (34.9 KB)   - Full game UI + gameplay logic
│   ├── editor_screen.dart  (14.9 KB)   - Board position editor
│   ├── tsume_screen.dart   (13.2 KB)   - Puzzle solver screen
│   ├── piece.dart          (7.7 KB)    - Models + puzzle data
│   ├── logic.dart          (12.3 KB)   - Game logic + AI
│   └── CLAUDE.md           (Project documentation)
├── pubspec.yaml            (Minimal dependencies)
├── android/, ios/, windows/, macos/  (Platform config)
└── PROJECT_SUMMARY.md      (This file)
```

## pubspec.yaml (Minimal)

```yaml
name: shogi_app
description: "A minimal Shogi UI application with board display, game play, and kifu editing."
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: ^3.11.5

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

**No external packages required** - Pure Flutter Material Design

## File Descriptions

### lib/main.dart
- **ShogiApp**: MaterialApp with brown color scheme, Material3 enabled
- **HomeScreen**: Main menu with full feature access
  - Game mode buttons (PvP, AI 先手, AI 後手)
  - AI difficulty selector (SegmentedButton: ランダム/弱/中/強)
  - Time limit selector (DropdownButton: なし/3分/5分/10分/15分)
  - Piece theme selector (SegmentedButton: 標準/ダーク)
  - Tsume (puzzle) problem list (5 built-in problems)
- Dark theme (0xFF1A1A2E background, 0xFF16213E cards)
- Japanese UI text throughout

### lib/game_screen.dart
- **GameScreen**: Main gameplay UI
  - 9x9 board display with piece rendering
  - Piece selection and move visualization
  - Hand (captured pieces) display for both players
  - Move counter and current player indicator
  - Timer display (if time limit enabled)
  - Move history (kifu) in Japanese notation
  - Undo button (reverts last move)
  - Game over detection and notification
- **GameSettings**: Configuration class
  - `mode`: PvP or vs AI
  - `aiLevel`: random/easy/medium/hard (→ aiDepth: 0/1/2/4)
  - `aiIsP2`: whether AI plays as second player (後手)
  - `timeLimitSec`: per-player time limit (null = unlimited)
  - `theme`: piece display theme
- Move validation integrated with logic.dart
- AI move generation on separate thread (async)

### lib/editor_screen.dart
- **EditorScreen**: Interactive position builder
  - Piece selector palette (14 piece types, both players)
  - Board grid for placing/removing pieces
  - Hand (captured pieces) editors for each player
  - Player 1/2 toggle for piece ownership
  - Erase mode for clearing cells
  - Standard position loader (initial shogi setup)
  - Empty board loader
  - "Play" button to launch game from edited position
  - Displays which player can move first

### lib/tsume_screen.dart
- **TsumeScreen**: Puzzle solver
  - Display puzzle board and hand pieces
  - Problem title, hint, and required move count
  - Move input interface (restricted to attacking player)
  - Legal move validation for puzzle context
  - Checkmate detection
  - Success message on completion
  - Failure feedback with reset option
  - Back to home navigation

### lib/piece.dart
- **Enums**:
  - `PieceType`: 14 types (pawn, lance, knight, silver, gold, bishop, rook, king + 6 promoted versions)
  - Game settings enums (GameMode, AILevel, PieceTheme)
- **Piece class**: Core piece model
  - type, isPlayer1, label (kanji)
  - isPromoted, canPromote, promotedType, baseType helpers
  - mustPromote(toRow) for move validation
- **AMove class**: AI move representation (from, to, drop, promote flags)
- **KifuMove class**: Move notation in Japanese (▲/△ with piece labels)
- **TsumeProblem class**: Puzzle data
- **tsumeProblems list**: 5 built-in puzzles (1-3 hand solutions)

### lib/logic.dart
- **Move validation**: Legal moves for each piece type
  - Pawn, lance, knight, silver, gold, bishop, rook, king
  - Piece-specific movement patterns
  - Board boundary checking
  - Capture vs empty square logic
- **AI engine**:
  - Minimax algorithm with configurable depth
  - Move generation and evaluation
  - Position scoring (material + positional)
- **Board utilities**:
  - Piece attack calculation
  - Check/checkmate detection
  - Board state snapshot/restore for undo
- **Hand management**: Captured piece tracking

## Features Implemented

### Game Modes
- **Two Player (PvP)**: Local multiplayer on same device
- **vs AI**: Choose AI difficulty (4 levels)
  - AI plays as 先手 (first player) or 後手 (second player)
- **Tsume Puzzles**: 5 built-in checkmating puzzles with solutions

### UI Elements
- Dark material theme with brown accents
- Japanese text throughout (駒, 玉, 王, etc.)
- Responsive grid-based board
- Piece selection with drag-to-move
- Captured pieces display
- Move history/kifu panel
- Settings (AI, time, theme)

### Game Logic
- Full Shogi move validation
- Piece promotion rules
- Check and checkmate detection
- Undo functionality
- Time tracking (optional per-player limits)
- AI opponent (minimax-based)

## How to Run

```bash
cd shogi_app
flutter pub get
flutter run
```

### Requirements
- Flutter SDK 3.11.5+
- Dart 3.11.5+
- Android SDK or iOS SDK (for device testing)

### Testing Checklist
- [ ] HomeScreen loads with all buttons visible
- [ ] PvP mode: Two players can make moves alternately
- [ ] AI mode: AI responds within 2-3 seconds
- [ ] Editor: Can place pieces and launch game
- [ ] Tsume: Can solve 1-hand puzzle (Problem 1)
- [ ] Settings: AI/time/theme changes persist
- [ ] Undo works correctly
- [ ] Game detects checkmate and ends

## Code Statistics

| File | Lines | Purpose |
|------|-------|---------|
| main.dart | 261 | Entry + HomeScreen |
| game_screen.dart | ~800 | Game UI + gameplay |
| editor_screen.dart | ~450 | Position editor |
| tsume_screen.dart | ~400 | Puzzle solver |
| piece.dart | ~300 | Models + data |
| logic.dart | ~400 | Game logic |
| **Total** | ~2,611 | **UI-first implementation** |

## Design Philosophy

- **Minimal dependencies**: Only Flutter standard library
- **Dark theme**: Easy on the eyes, traditional aesthetic
- **Japanese UI**: Full localization (no English except labels)
- **UI-focused**: Complex logic delegated to game_screen.dart and logic.dart
- **Modular screens**: Each feature in separate screen file
- **Easy to extend**: Add new game modes, puzzles, or AI strategies

## Future Enhancements

1. **Kifu loading/saving**: Load .kif files, export game records
2. **Online multiplayer**: Network play via WebSocket
3. **Endgame analysis**: Show best moves/evaluation
4. **Problem difficulty**: Categorize puzzles by difficulty
5. **Sound effects**: Move/capture sounds
6. **Theme customization**: Custom board/piece colors
7. **Game replay**: Step through saved games move-by-move
8. **Statistics**: Track win/loss records

## Known Limitations

- No network play (local only)
- Limited AI (depth 4 = ~1s per move)
- No persistent game saving
- No problem hints (only title/hint text)
- No OCR for image-based board input

## File Paths

- **Main entry**: `C:\Users\Administrator\OneDrive\subwork\smartphone\smart-claude-code\shogi_app\lib\main.dart`
- **Game logic**: `C:\Users\Administrator\OneDrive\subwork\smartphone\smart-claude-code\shogi_app\lib\logic.dart`
- **Config**: `C:\Users\Administrator\OneDrive\subwork\smartphone\smart-claude-code\shogi_app\pubspec.yaml`
- **Documentation**: `C:\Users\Administrator\OneDrive\subwork\smartphone\smart-claude-code\shogi_app\CLAUDE.md`
