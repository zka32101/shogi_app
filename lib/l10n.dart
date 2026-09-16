// lib/l10n.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';

class L10n {
  static String _lang = 'ja';

  static String get currentLang => _lang;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString('app_language') ?? 'ja';
  }

  static Future<void> setLanguage(String lang) async {
    _lang = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
  }

  static String t(String key) {
    if (_lang == 'en') {
      return _en[key] ?? key;
    }
    return _ja[key] ?? key;
  }

  static const Map<String, String> _ja = {
    'play': '対局',
    'study': '学習',
    'records': '棋譜',
    'settings': '設定',
    'tsume': '詰将棋',
    'tesuji': '手筋トレーニング',
    'joseki_practice': '定跡練習',
    'shodan_road': '初段への道',
    'skill_test': '棋力診断',
    'next_move': '次の一手',
    'castle_break': '囲い崩し道場',
    'pro_kifu': 'プロ棋譜閲覧',
    'calendar': '学習カレンダー',
    'weakness': '弱点分析',
    'tournament': '月例トーナメント',
    'vs_ai': 'AI対局',
    'local_game': 'ローカル対局',
    'online_game': 'ネットワーク対局',
    'stats': '統計',
    'theme': 'テーマ',
    'time_limit': '持ち時間',
    'byoyomi': '秒読み',
    'castle_patterns': '囲いパターン',
    'strategies': '戦法',
    'proverbs': '格言',
    'rank': '段位',
    'ranking': 'ランキング',
    'badges': 'バッジ',
    'correct': '正解！',
    'incorrect': '不正解',
    'hint': 'ヒント',
    'explanation': '解説',
    'next_problem': '次の問題',
    'reset': 'リセット',
    'back': '戻る',
    'clear': 'クリア',
    'save': '保存',
    'generate': '生成する',
    'collection': 'コレクション',
    'join': '参加する',
    'schedule': '大会日程',
    'weekly_review': '週次AI振り返り',
    'coach_mode': 'コーチモード',
    'puzzle_gen': 'AI詰将棋ジェネレーター',
    'language': '言語',
    'japanese': '日本語',
    'english': 'English',
    'game_start': '対局開始',
    'resign': '投了',
    'draw': '引き分け',
    'win': '勝ち',
    'lose': '負け',
    'your_turn': 'あなたの手番',
    'ai_turn': 'AIの手番',
    'checkmate': '詰み',
    'check': '王手',
    'promote': '成る',
    'no_promote': '成らない',
    'drop': '打つ',
    'pieces_in_hand': '持ち駒',
    'moves': '手数',
    'time': '時間',
    'resign': '投了',
    'resign_confirm': '投了しますか？',
    'resign_confirm_match': 'この対局を終了します。',
    'resign_button': '投了する',
    'cancel': 'キャンセル',
    'draw': '引き分け',
    'draw_proposal': '引き分けを申し込む',
    'draw_accept': '承諾',
    'draw_reject': '拒否',
    'opponent_rejected_draw': '相手が引き分けの提案を拒否しました',
    'draw_proposal_sent': '引き分けを申し込みました。相手の応答を待っています...',
    'time_lost': '時間切れで敗北しました',
    'error_occurred': 'エラーが発生しました。時間をおいて再度お試しください',
    'repetition': '千日手',
    'jishogi': '持将棋',
    'continue': '続ける',
    'opponent_moved': '相手が指した',
    'your_turn': 'あなたの手番',
    'game_in_progress': '対局中',
  };

  static const Map<String, String> _en = {
    'play': 'Play',
    'study': 'Study',
    'records': 'Records',
    'settings': 'Settings',
    'tsume': 'Tsume Shogi',
    'tesuji': 'Tesuji Training',
    'joseki_practice': 'Joseki Practice',
    'shodan_road': 'Road to Shodan',
    'skill_test': 'Skill Test',
    'next_move': 'Best Move',
    'castle_break': 'Castle Breaking',
    'pro_kifu': 'Pro Games',
    'calendar': 'Study Calendar',
    'weakness': 'Weakness Analysis',
    'tournament': 'Monthly Tournament',
    'vs_ai': 'vs AI',
    'local_game': 'Local Game',
    'online_game': 'Online Game',
    'stats': 'Statistics',
    'theme': 'Theme',
    'time_limit': 'Time Limit',
    'byoyomi': 'Byo-yomi',
    'castle_patterns': 'Castles',
    'strategies': 'Strategies',
    'proverbs': 'Proverbs',
    'rank': 'Rank',
    'ranking': 'Ranking',
    'badges': 'Badges',
    'correct': 'Correct!',
    'incorrect': 'Incorrect',
    'hint': 'Hint',
    'explanation': 'Explanation',
    'next_problem': 'Next Problem',
    'reset': 'Reset',
    'back': 'Back',
    'clear': 'Clear',
    'save': 'Save',
    'generate': 'Generate',
    'collection': 'Collection',
    'join': 'Join',
    'schedule': 'Schedule',
    'weekly_review': 'Weekly AI Review',
    'coach_mode': 'Coach Mode',
    'puzzle_gen': 'AI Puzzle Generator',
    'language': 'Language',
    'japanese': '日本語',
    'english': 'English',
    'game_start': 'Start Game',
    'resign': 'Resign',
    'draw': 'Draw',
    'win': 'Win',
    'lose': 'Lose',
    'your_turn': 'Your Turn',
    'ai_turn': "AI's Turn",
    'checkmate': 'Checkmate',
    'check': 'Check',
    'promote': 'Promote',
    'no_promote': "Don't promote",
    'drop': 'Drop',
    'pieces_in_hand': 'Pieces in Hand',
    'moves': 'Moves',
    'time': 'Time',
    'resign': 'Resign',
    'resign_confirm': 'Are you sure you want to resign?',
    'resign_confirm_match': 'This game will end.',
    'resign_button': 'Resign',
    'cancel': 'Cancel',
    'draw': 'Draw',
    'draw_proposal': 'Propose Draw',
    'draw_accept': 'Accept',
    'draw_reject': 'Reject',
    'opponent_rejected_draw': 'Opponent rejected the draw proposal',
    'draw_proposal_sent': 'Draw proposal sent. Waiting for opponent response...',
    'time_lost': 'Lost by time',
    'error_occurred': 'An error occurred. Please try again later.',
    'repetition': 'Repetition Draw',
    'jishogi': 'Jishogi Draw',
    'continue': 'Continue',
    'opponent_moved': 'Opponent moved',
    'your_turn': 'Your turn',
    'game_in_progress': 'Game in progress',
  };

  static String pieceLabel(String jaLabel) {
    if (_lang != 'en') return jaLabel;
    const map = {
      '王': 'K', '玉': 'K',
      '飛': 'R', '龍': '+R',
      '角': 'B', '馬': '+B',
      '金': 'G',
      '銀': 'S', '全': '+S',
      '桂': 'N', '圭': '+N',
      '香': 'L', '杏': '+L',
      '歩': 'P', 'と': '+P',
    };
    return map[jaLabel] ?? jaLabel;
  }
}

class LanguageSettingsWidget extends StatefulWidget {
  final VoidCallback onChanged;
  const LanguageSettingsWidget({super.key, required this.onChanged});
  @override
  State<LanguageSettingsWidget> createState() => _LanguageSettingsWidgetState();
}

class _LanguageSettingsWidgetState extends State<LanguageSettingsWidget> {
  String _current = L10n.currentLang;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.language, color: Colors.white70),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('言語 / Language',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 200,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ja', label: Text('日本語')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {_current},
            onSelectionChanged: (val) async {
              final lang = val.first;
              await L10n.setLanguage(lang);
              setState(() => _current = lang);
              widget.onChanged();
            },
            style: SegmentedButton.styleFrom(
              backgroundColor: AppTheme.bg,
              selectedBackgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white70,
              selectedForegroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
