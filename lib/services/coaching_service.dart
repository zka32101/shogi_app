import 'package:flutter/foundation.dart';

/// Game result model for feedback generation
class GameResult {
  final bool isWin;
  final int movesPlayed;
  final List<String> keyMoves;
  final String? winCondition; // 'checkmate', 'resignation', 'timeout', etc.

  const GameResult({
    required this.isWin,
    required this.movesPlayed,
    this.keyMoves = const [],
    this.winCondition,
  });
}

/// Coach personality model
class CoachPersonality {
  final String characterName;
  final String description;
  final String feedbackStyle; // 'encouraging', 'strict', 'balanced'
  final List<String> motivationalQuotes;

  const CoachPersonality({
    required this.characterName,
    required this.description,
    required this.feedbackStyle,
    required this.motivationalQuotes,
  });
}

/// Play style analysis result
enum PlayStyle {
  aggressive,
  defensive,
  balanced,
}

/// Coaching service for personalized feedback and relationship management
class CoachingService extends ChangeNotifier {
  // Relationship level with coach (0-10)
  int _relationshipLevel = 0;

  // Coach personality based on play style
  late CoachPersonality _coachPersonality;

  // Tracked game history for analysis
  final List<GameResult> _gameHistory = [];

  // Detected play style
  PlayStyle _playStyle = PlayStyle.balanced;

  // Unlocked techniques
  final Set<String> _unlockedTechniques = {};

  CoachingService() {
    _initializeCoach();
  }

  /// Initialize coach with default personality
  void _initializeCoach() {
    _playStyle = PlayStyle.balanced;
    _coachPersonality = _getCoachPersonalityForStyle(_playStyle);
  }

  /// Analyze game history to determine play style
  PlayStyle getPlayStyle(List<GameResult> gameHistory) {
    if (gameHistory.isEmpty) {
      return PlayStyle.balanced;
    }

    int wins = 0;
    int totalMoves = 0;
    int aggressiveMoveCount = 0;

    for (final game in gameHistory) {
      if (game.isWin) {
        wins++;
      }
      totalMoves += game.movesPlayed;

      // Count aggressive patterns
      for (final move in game.keyMoves) {
        // Simple heuristic: moves containing 成 (promotion) or 取 (capture) are aggressive
        if (move.contains('成') || move.contains('取')) {
          aggressiveMoveCount++;
        }
      }
    }

    // Calculate win rate
    double winRate = wins / gameHistory.length;

    // Determine play style based on patterns
    if (aggressiveMoveCount > gameHistory.length * 2) {
      // More than 2 aggressive moves per game on average
      _playStyle = PlayStyle.aggressive;
    } else if (winRate < 0.4 && totalMoves > gameHistory.length * 40) {
      // Low win rate but plays long defensive games
      _playStyle = PlayStyle.defensive;
    } else {
      _playStyle = PlayStyle.balanced;
    }

    _gameHistory.addAll(gameHistory);
    notifyListeners();

    return _playStyle;
  }

  /// Get coach personality based on play style
  CoachPersonality getCoachPersonality(PlayStyle playStyle) {
    _playStyle = playStyle;
    _coachPersonality = _getCoachPersonalityForStyle(playStyle);
    notifyListeners();
    return _coachPersonality;
  }

  /// Internal method to retrieve coach personality for given style
  CoachPersonality _getCoachPersonalityForStyle(PlayStyle style) {
    switch (style) {
      case PlayStyle.aggressive:
        return CoachPersonality(
          characterName: '武士丸（ぶしまる）',
          description: '戦いの香りを好む、豪胆な将棋武士。積極的な攻めを重視する。',
          feedbackStyle: 'encouraging',
          motivationalQuotes: [
            '攻撃こそが最高の防御じゃ！',
            '躊躇するな！いまが勝機！',
            'その攻めの精神、見事じゃ！',
            '臆病者に勝利はない。己を信じよ！',
            'もっと気合を入れて攻めよ！',
          ],
        );

      case PlayStyle.defensive:
        return CoachPersonality(
          characterName: '賢狐（けんこ）',
          description: '深い思慮と忍耐の将棋哲学を持つ狐の導師。防御と正確さを尊ぶ。',
          feedbackStyle: 'balanced',
          motivationalQuotes: [
            '急がば回れ。焦りは敵じゃぞ。',
            'その粘り強さこそが勝利への道。',
            '防御を固めて機を待つ。それが知恵じゃ。',
            '一手一手を大切に。無駄な一手はない。',
            'その慎重さ、大事にせよ。',
          ],
        );

      case PlayStyle.balanced:
        return CoachPersonality(
          characterName: '八百比丘尼（やおびくに）',
          description: '攻守のバランスを極めた、神秘的な将棋の導師。柔軟な思考を教える。',
          feedbackStyle: 'balanced',
          motivationalQuotes: [
            '攻めと守りのバランスが勝利を呼ぶ。',
            'その判断、いかにも正しい。',
            '柔軟に、そして強く。それが道じゃ。',
            '流れを読み、時を見極めよ。',
            'お主の工夫は光っておる。',
          ],
        );
    }
  }

  /// Increment relationship level with coach
  void levelUpCoach() {
    if (_relationshipLevel < 10) {
      _relationshipLevel++;
      notifyListeners();

      // Check if technique should be unlocked
      if (_relationshipLevel == 10) {
        unlockTechnique(_relationshipLevel);
      }
    }
  }

  /// Unlock techniques at specific relationship levels
  void unlockTechnique(int level) {
    String? technique;

    switch (level) {
      case 3:
        technique = '飛び角';
        break;
      case 5:
        technique = '銀冠';
        break;
      case 7:
        technique = '穴熊囲い';
        break;
      case 10:
        technique = '${_coachPersonality.characterName}の奥義';
        break;
      default:
        return;
    }

    if (technique != null && !_unlockedTechniques.contains(technique)) {
      _unlockedTechniques.add(technique);
      notifyListeners();
    }
  }

  /// Generate personalized feedback based on game result and coach personality
  String generateFeedback(GameResult gameResult, CoachPersonality coachPersonality) {
    List<String> feedbackLines = [];

    // Opening line - based on win/loss and personality
    if (gameResult.isWin) {
      feedbackLines.add('${coachPersonality.characterName}からのお言葉：');
      feedbackLines.add('');

      if (coachPersonality.feedbackStyle == 'encouraging') {
        feedbackLines.add('素晴らしい勝利じゃ！');
      } else {
        feedbackLines.add('見事な勝利だ。学ぶべきことも多い。');
      }
    } else {
      feedbackLines.add('${coachPersonality.characterName}からのお言葉：');
      feedbackLines.add('');
      feedbackLines.add('敗北からも学べることがある。');
    }

    // Add move-based feedback
    feedbackLines.add('');
    if (gameResult.keyMoves.isNotEmpty) {
      feedbackLines.add('注目の一手：');
      for (final move in gameResult.keyMoves.take(3)) {
        feedbackLines.add('・$move');
      }
    }

    // Add move count feedback
    feedbackLines.add('');
    if (gameResult.movesPlayed < 30) {
      feedbackLines.add('素早い決着。');
    } else if (gameResult.movesPlayed > 60) {
      feedbackLines.add('長い戦いだったな。粘り強さが試される局面じゃ。');
    } else {
      feedbackLines.add('バランスの取れた戦いぶりだ。');
    }

    // Add motivational quote
    feedbackLines.add('');
    final quote = coachPersonality.motivationalQuotes[
        DateTime.now().millisecond % coachPersonality.motivationalQuotes.length];
    feedbackLines.add('"$quote"');

    // Add next step advice
    feedbackLines.add('');
    if (gameResult.isWin) {
      feedbackLines.add('この調子で修行を積むがよい。次の相手はさらに強かろう。');
    } else {
      feedbackLines.add('敗因を分析し、同じ過ちを繰り返すな。道は長いぞ。');
    }

    return feedbackLines.join('\n');
  }

  // Getters
  int get relationshipLevel => _relationshipLevel;
  PlayStyle get playStyle => _playStyle;
  CoachPersonality get coachPersonality => _coachPersonality;
  Set<String> get unlockedTechniques => Set.unmodifiable(_unlockedTechniques);
  List<GameResult> get gameHistory => List.unmodifiable(_gameHistory);

  /// Reset coach and relationship
  void reset() {
    _relationshipLevel = 0;
    _gameHistory.clear();
    _unlockedTechniques.clear();
    _initializeCoach();
    notifyListeners();
  }

  /// Get feedback for relationship milestone
  String getMilestoneMessage() {
    switch (_relationshipLevel) {
      case 1:
        return '${_coachPersonality.characterName}が修行をサポートします。';
      case 3:
        return '${_coachPersonality.characterName}が「飛び角」を教えてくれた！';
      case 5:
        return '${_coachPersonality.characterName}が「銀冠」を伝授した！';
      case 7:
        return '${_coachPersonality.characterName}が「穴熊囲い」の秘密を明かした！';
      case 10:
        return '${_coachPersonality.characterName}が「奥義」の伝承者として認めてくれた！';
      default:
        return '';
    }
  }
}
