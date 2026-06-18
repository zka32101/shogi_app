// lib/strategies_screen.dart — 戦法（開き方）説明

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'piece.dart';
import 'mini_board_widget.dart';

enum _Difficulty { beginner, intermediate, advanced }

class _DifficultyHelper {
  static String label(_Difficulty difficulty) {
    switch (difficulty) {
      case _Difficulty.beginner:
        return '初級';
      case _Difficulty.intermediate:
        return '中級';
      case _Difficulty.advanced:
        return '上級';
    }
  }

  static Color color(_Difficulty difficulty) {
    switch (difficulty) {
      case _Difficulty.beginner:
        return Colors.green;
      case _Difficulty.intermediate:
        return Colors.orange;
      case _Difficulty.advanced:
        return Colors.red;
    }
  }
}

class StrategiesScreen extends StatefulWidget {
  const StrategiesScreen({super.key});

  @override
  State<StrategiesScreen> createState() => _StrategiesScreenState();
}

class _StrategiesScreenState extends State<StrategiesScreen> {
  _Difficulty? _selectedDifficulty;
  String? _selectedSource;

  List<Map<String, dynamic>> get _strategies => [
    // 既存戦法
    {
      'name': '角換わり',
      'description': 'お互いの角を交換する戦法。中盤の戦いが複雑になる傾向があります。',
      'memo': 'この戦法は高度なテクニックが必要で、プロの将棋でもよく使われます。',
      'difficulty': _Difficulty.advanced,
      'sourceTitle': '将棋研究',
      'sourceUrl': 'https://www.shougi.jp/learn/strategy/',
      'boardBuilder': () => _kakugawariBoard(),
      'highlights': const {(1, 7), (7, 1)},
    },
    {
      'name': '相掛かり',
      'description': 'お互いが同じ方向に飛車を置く戦法。力強い攻撃になりやすいです。',
      'memo': 'シンプルながら奥が深く、初心者から上級者まで愛用される戦法です。',
      'difficulty': _Difficulty.beginner,
      'sourceTitle': '将棋講座.com',
      'sourceUrl': 'https://xn--pet04dr1n5x9a.com/strategy/',
      'boardBuilder': () => _aiakariBoard(),
      'highlights': const {(1, 1), (7, 7)},
    },
    {
      'name': '四間飛車（先手）',
      'description': '先手が飛車を4筋（4八）に移動させる振飛車。バランスが良い基本の戦法。',
      'memo': '攻守バランスが良く、多くの対局で見られる振飛車の代表格です。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '',
      'boardBuilder': () => _shikenbishaBoard(),
      'highlights': const {(7, 5)},
    },
    {
      'name': '四間飛車（後手）',
      'description': '後手が飛車を6二に振る四間飛車。先手と左右が逆になります。',
      'memo': '後手番での振飛車は居飛車穴熊対策として有力です。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '',
      'boardBuilder': () => _shikenbishaLeftBoard(),
      'highlights': const {(1, 3)},
    },
    {
      'name': '三間飛車（先手）',
      'description': '飛車を3筋（3八）に移動させる戦法。攻撃的なスタイルが特徴。',
      'memo': '急戦もできる攻撃的な振飛車です。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '将棋研究',
      'sourceUrl': 'https://www.shougi.jp/learn/strategy/',
      'boardBuilder': () => _sankenbishaBoard(),
      'highlights': const {(7, 6)},
    },
    {
      'name': '三間飛車（後手）',
      'description': '後手が飛車を7二に振る三間飛車。石田流など多彩な変化があります。',
      'memo': '石田流三間飛車は積極的な攻めが持ち味です。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '将棋研究',
      'sourceUrl': 'https://www.shougi.jp/learn/strategy/',
      'boardBuilder': () => _sankenbishaLeftBoard(),
      'highlights': const {(1, 2)},
    },
    // 新規戦法
    {
      'name': '横歩取り',
      'description': '後手の3四歩を先手飛車が取りに行く攻撃的な戦法。複雑な変化が特徴。',
      'memo': 'プロ将棋でも採用される高度な戦法です。',
      'difficulty': _Difficulty.advanced,
      'sourceTitle': '将棋研究',
      'sourceUrl': 'https://www.shougi.jp/learn/strategy/',
      'boardBuilder': () => _yokofuBoard(),
      'highlights': const {(3, 2)},
    },
    {
      'name': '相振飛車',
      'description': '先手も後手も飛車を振る珍しい戦法。どちらが優位になるか未知数。',
      'memo': '振飛車同士の対抗形は独特の魅力があります。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '',
      'boardBuilder': () => _aivibrBoard(),
      'highlights': const {(1, 3), (7, 5)},
    },
    {
      'name': '中飛車',
      'description': '飛車を5筋に持つ戦法。柔軟な対応が可能。',
      'memo': '現代将棋で注目度が高い戦法です。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '将棋講座.com',
      'sourceUrl': 'https://xn--pet04dr1n5x9a.com/strategy/',
      'boardBuilder': () => _nakabishaBoard(),
      'highlights': const {(7, 4)},
    },
    {
      'name': '居角',
      'description': '角を初期位置に置いたまま戦う戦法。初心者向け。',
      'memo': '基本的な形を学ぶのに最適です。',
      'difficulty': _Difficulty.beginner,
      'sourceTitle': '将棋講座.com',
      'sourceUrl': 'https://xn--pet04dr1n5x9a.com/strategy/',
      'boardBuilder': () => _iokakuBoard(),
      'highlights': const {(7, 1), (1, 7)},
    },
    {
      'name': '石田流',
      'description': '三間飛車の一種で、急戦的な変化が豊富。複雑な思考が必要。',
      'memo': '古くから使われている由緒ある戦法です。',
      'difficulty': _Difficulty.advanced,
      'sourceTitle': '将棋研究',
      'sourceUrl': 'https://www.shougi.jp/learn/strategy/',
      'boardBuilder': () => _ishidaryuBoard(),
      'highlights': const {(7, 6), (6, 5)},
    },
  ];

  List<Map<String, dynamic>> get _filteredStrategies {
    return _strategies.where((strategy) {
      if (_selectedDifficulty != null &&
          strategy['difficulty'] != _selectedDifficulty) {
        return false;
      }
      if (_selectedSource != null &&
          strategy['sourceTitle'] != _selectedSource) {
        return false;
      }
      return true;
    }).toList();
  }

  // ---- Board position helpers ----

  List<List<Piece?>> _baseBoard({bool includeBishops = true}) {
    final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
    // 後手（上）初期配置
    b[0][0] = const Piece(PieceType.lance, false);
    b[0][1] = const Piece(PieceType.knight, false);
    b[0][2] = const Piece(PieceType.silver, false);
    b[0][3] = const Piece(PieceType.gold, false);
    b[0][4] = const Piece(PieceType.king, false);
    b[0][5] = const Piece(PieceType.gold, false);
    b[0][6] = const Piece(PieceType.silver, false);
    b[0][7] = const Piece(PieceType.knight, false);
    b[0][8] = const Piece(PieceType.lance, false);
    b[1][1] = const Piece(PieceType.rook, false);   // 後手飛車 8二
    if (includeBishops) b[1][7] = const Piece(PieceType.bishop, false);  // 後手角 2二
    for (int c = 0; c < 9; c++) { b[2][c] = const Piece(PieceType.pawn, false); }
    // 先手（下）初期配置
    b[8][0] = const Piece(PieceType.lance, true);
    b[8][1] = const Piece(PieceType.knight, true);
    b[8][2] = const Piece(PieceType.silver, true);
    b[8][3] = const Piece(PieceType.gold, true);
    b[8][4] = const Piece(PieceType.king, true);
    b[8][5] = const Piece(PieceType.gold, true);
    b[8][6] = const Piece(PieceType.silver, true);
    b[8][7] = const Piece(PieceType.knight, true);
    b[8][8] = const Piece(PieceType.lance, true);
    b[7][7] = const Piece(PieceType.rook, true);    // 先手飛車 2八
    if (includeBishops) b[7][1] = const Piece(PieceType.bishop, true);  // 先手角 8八
    for (int c = 0; c < 9; c++) { b[6][c] = const Piece(PieceType.pawn, true); }
    return b;
  }

  List<List<Piece?>> _kakugawariBoard() {
    // 角換わり: 両角が交換済み（持ち駒）— 角のマスは空
    // _baseBoard(false)で飛車は既に正しい位置に置かれる
    return _baseBoard(includeBishops: false);
  }

  List<List<Piece?>> _aiakariBoard() {
    // 相掛かり: 飛車は初期位置のまま、歩を少し動かした形
    return _baseBoard();
  }

  List<List<Piece?>> _yokofuBoard() {
    // 横歩取り: 後手の3四歩を先手飛車が取りに行く
    final b = _baseBoard();
    b[6][2] = null; // 先手3六歩を突く
    b[3][2] = null; // 後手3四歩
    return b;
  }

  List<List<Piece?>> _shikenbishaLeftBoard() {
    // 左四間飛車: 後手から見た四間飛車（後手が6二へ）
    final b = _baseBoard();
    b[1][1] = null; // 後手飛車を移動
    b[1][3] = const Piece(PieceType.rook, false); // 後手6二へ
    return b;
  }

  List<List<Piece?>> _sankenbishaLeftBoard() {
    // 左三間飛車: 後手が7二へ
    final b = _baseBoard();
    b[1][1] = null;
    b[1][2] = const Piece(PieceType.rook, false); // 後手7二へ
    return b;
  }

  List<List<Piece?>> _shikenbishaBoard() {
    // 四間飛車: 先手飛車を4八 (row=7, col=5) に移動
    final b = _baseBoard();
    b[7][7] = null;                                    // 2八から飛車を除去
    b[7][5] = const Piece(PieceType.rook, true);       // 4八に飛車
    return b;
  }

  List<List<Piece?>> _sankenbishaBoard() {
    // 三間飛車: 先手飛車を3八 (row=7, col=6) に移動
    final b = _baseBoard();
    b[7][7] = null;                                    // 2八から飛車を除去
    b[7][6] = const Piece(PieceType.rook, true);       // 3八に飛車
    return b;
  }

  List<List<Piece?>> _aivibrBoard() {
    // 相振飛車: 先手も後手も飛車を振る
    final b = _baseBoard();
    b[1][1] = null;
    b[1][3] = const Piece(PieceType.rook, false); // 後手6二へ
    b[7][7] = null;
    b[7][5] = const Piece(PieceType.rook, true);  // 先手4八へ
    return b;
  }

  List<List<Piece?>> _nakabishaBoard() {
    // 中飛車: 先手飛車を5筋（row=7, col=4）に移動
    final b = _baseBoard();
    b[7][7] = null;
    b[7][4] = const Piece(PieceType.rook, true);
    return b;
  }

  List<List<Piece?>> _iokakuBoard() {
    // 居角: 角を初期位置に置いたまま戦う（通常配置）
    return _baseBoard();
  }

  List<List<Piece?>> _ishidaryuBoard() {
    // 石田流: 三間飛車の一種で、歩を6五に突く準備
    final b = _baseBoard();
    b[7][7] = null;
    b[7][6] = const Piece(PieceType.rook, true); // 3八に飛車
    b[6][5] = null; // 6五歩を突く
    b[3][5] = const Piece(PieceType.pawn, true);
    return b;
  }

  @override
  Widget build(BuildContext context) {
    final sources = {'将棋講座.com', '将棋研究'};

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('戦法（開き方）'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: '戻る',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('戦法とは'),
          _StrategyItem(
            '戦法の基本',
            'ゲームの序盤に、特定の手順で駒を動かし、優位な立場を作る作戦のことを「戦法」と呼びます。相手の対抗手段を読みながら戦いを進めます。',
          ),
          const SizedBox(height: 20),
          _SectionTitle('フィルター'),
          // 難度フィルター
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '難度',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _FilterChip(
                      label: '全て',
                      isSelected: _selectedDifficulty == null,
                      onPressed: () => setState(() => _selectedDifficulty = null),
                    ),
                    ..._Difficulty.values.map((d) {
                      return _FilterChip(
                        label: _DifficultyHelper.label(d),
                        isSelected: _selectedDifficulty == d,
                        color: _DifficultyHelper.color(d),
                        onPressed: () => setState(
                          () => _selectedDifficulty =
                              _selectedDifficulty == d ? null : d,
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          // 出典フィルター
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '出典',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _FilterChip(
                      label: '全て',
                      isSelected: _selectedSource == null,
                      onPressed: () => setState(() => _selectedSource = null),
                    ),
                    ...sources.map((source) {
                      return _FilterChip(
                        label: source,
                        isSelected: _selectedSource == source,
                        onPressed: () => setState(
                          () => _selectedSource =
                              _selectedSource == source ? null : source,
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          _SectionTitle('戦法一覧 (${_filteredStrategies.length}件)'),
          if (_filteredStrategies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'マッチする戦法がありません',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ..._filteredStrategies.map((strategy) {
              final board = (strategy['boardBuilder'] as Function)();
              return _DetailedStrategy(
                strategy['name'] as String,
                strategy['description'] as String,
                strategy['memo'] as String,
                board,
                difficulty: strategy['difficulty'] as _Difficulty,
                sourceUrl: strategy['sourceUrl'] as String?,
                sourceTitle: strategy['sourceTitle'] as String?,
                highlights: strategy['highlights'] as Set<(int, int)>,
              );
            }),
          const SizedBox(height: 20),
          _SectionTitle('戦法選びのコツ'),
          _TipItem(
            '自分のスタイルに合わせる',
            '攻撃的なのか防御的なのか、得意なスタイルで戦法を選びましょう。',
          ),
          _TipItem(
            '相手の動きを読む',
            '相手がどの戦法を選んでくるか予測することが重要です。',
          ),
          _TipItem(
            '練習を重ねる',
            '同じ戦法を何度も練習することで、その戦法の強さを引き出せます。',
          ),
          _TipItem(
            'バリエーションを学ぶ',
            '戦法には様々な応手があります。複数のバリエーションを学びましょう。',
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _StrategyItem extends StatelessWidget {
  final String title;
  final String description;
  const _StrategyItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.brown.shade600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text(
                '⚔️',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailedStrategy extends StatelessWidget {
  final String name;
  final String description;
  final String memo;
  final List<List<Piece?>> board;
  final Set<(int, int)> highlights;
  final String? sourceUrl;
  final String? sourceTitle;
  final _Difficulty difficulty;

  const _DetailedStrategy(
    this.name,
    this.description,
    this.memo,
    this.board, {
    this.highlights = const {},
    this.sourceUrl,
    this.sourceTitle,
    required this.difficulty,
  });

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          border: const Border(left: BorderSide(color: Colors.cyan, width: 4)),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー: 名前 + 難度バッジ
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _DifficultyHelper.color(difficulty).withOpacity(0.3),
                    border: Border.all(
                      color: _DifficultyHelper.color(difficulty),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _DifficultyHelper.label(difficulty),
                    style: TextStyle(
                      color: _DifficultyHelper.color(difficulty),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 出典リンク
            if (sourceTitle != null && sourceUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _launchUrl(sourceUrl!),
                  child: Text(
                    '出典: $sourceTitle →',
                    style: TextStyle(
                      color: Colors.blue.shade300,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: MiniBoardWidget(
                board: board,
                highlightSquares: highlights,
                size: 220,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0D3C66),
                borderRadius: BorderRadius.circular(3),
              ),
              padding: const EdgeInsets.all(8),
              child: Text(
                '💡 $memo',
                style: const TextStyle(
                  color: Colors.lightBlue,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String title;
  final String description;
  const _TipItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: Colors.cyan.shade600,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                '✓',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onPressed;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.cyan;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withOpacity(0.3)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? effectiveColor : Colors.white30,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? effectiveColor : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
