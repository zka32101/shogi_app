// lib/natural_lang_qa_screen.dart — 自然言語AI解説者
import 'package:flutter/material.dart';
import 'dart:async';
import 'piece.dart';
import 'mini_board_widget.dart';

// ────────────────────────────────────────
// NaturalLangQAScreen - 自然言語で盤面を質問するプレミアム機能
// ────────────────────────────────────────

class NaturalLangQAScreen extends StatefulWidget {
  /// 初期盤面（不指定時は初期配置）
  final List<List<Piece?>>? initialBoard;

  const NaturalLangQAScreen({
    super.key,
    this.initialBoard,
  });

  @override
  State<NaturalLangQAScreen> createState() => _NaturalLangQAScreenState();
}

class _NaturalLangQAScreenState extends State<NaturalLangQAScreen> {
  late List<List<Piece?>> _board;
  final TextEditingController _questionController = TextEditingController();
  bool _isLoading = false;
  String? _lastQuestion;
  String? _aiResponse;
  bool _responseVisible = false;

  @override
  void initState() {
    super.initState();
    _board = widget.initialBoard ?? _initialBoard();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  /// 初期盤面を生成（先手vs後手の通常配置）
  List<List<Piece?>> _initialBoard() {
    final b = List.generate(9, (_) => List<Piece?>.filled(9, null, growable: false));

    // 後手（isPlayer1=false, 上側, row 0-2）
    b[0][0] = const Piece(PieceType.lance, false);
    b[0][1] = const Piece(PieceType.knight, false);
    b[0][2] = const Piece(PieceType.silver, false);
    b[0][3] = const Piece(PieceType.gold, false);
    b[0][4] = const Piece(PieceType.king, false);
    b[0][5] = const Piece(PieceType.gold, false);
    b[0][6] = const Piece(PieceType.silver, false);
    b[0][7] = const Piece(PieceType.knight, false);
    b[0][8] = const Piece(PieceType.lance, false);
    b[1][1] = const Piece(PieceType.rook, false);
    b[1][7] = const Piece(PieceType.bishop, false);
    for (int c = 0; c < 9; c++) b[2][c] = const Piece(PieceType.pawn, false);

    // 先手（isPlayer1=true, 下側, row 6-8）
    for (int c = 0; c < 9; c++) b[6][c] = const Piece(PieceType.pawn, true);
    b[7][1] = const Piece(PieceType.bishop, true);
    b[7][7] = const Piece(PieceType.rook, true);
    b[8][0] = const Piece(PieceType.lance, true);
    b[8][1] = const Piece(PieceType.knight, true);
    b[8][2] = const Piece(PieceType.silver, true);
    b[8][3] = const Piece(PieceType.gold, true);
    b[8][4] = const Piece(PieceType.king, true);
    b[8][5] = const Piece(PieceType.gold, true);
    b[8][6] = const Piece(PieceType.silver, true);
    b[8][7] = const Piece(PieceType.knight, true);
    b[8][8] = const Piece(PieceType.lance, true);

    return b;
  }

  /// 盤面をJSONシリアライズ（AI送信用）
  String _boardToJson() {
    final board = [];
    for (int r = 0; r < 9; r++) {
      final row = [];
      for (int c = 0; c < 9; c++) {
        final piece = _board[r][c];
        if (piece == null) {
          row.add(null);
        } else {
          row.add({
            'type': piece.type.index,
            'isPlayer1': piece.isPlayer1,
          });
        }
      }
      board.add(row);
    }
    return board.toString(); // Simple serialization for mock
  }

  /// AI サービス呼び出し（現在はモック実装）
  /// TODO: 実際の Gemini/Claude API に置き換える
  Future<String> _askAboutPosition(String question) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock responses based on question pattern
    if (question.contains('ダメ') || question.contains('なぜ')) {
      return '''（AIサービス実装予定）この手は相手に反撃の隙を与えます。

▼ より良い選択肢：
1. ７六歩 - 駒の活用を急ぐプロの指し方
2. ２六歩 - 美濃囲い方面の争いを制する狙い

▼ コメント：
序盤の選択は流行の進化に左右されます。ここではプロ間でも意見が分かれる局面です。''';
    } else if (question.contains('初心者') || question.contains('簡単') || question.contains('教えて')) {
      return '''（AIサービス実装予定）簡単に言うと、この手は相手の攻撃を招きやすいということです。

▼ 初心者向けの考え方：
• 駒を相手から遠い位置に置く
• 王様の周りに味方を集める（囲いを作る）
• 急に攻める前に準備を整える

▼ 次の一手：
７六歩 が安全でおすすめです。''';
    } else if (question.contains('定跡') || question.contains('棋書')) {
      return '''（AIサービス実装予定）この局面は矢倉戦型です。

▼ 参考図書：
• 「矢倉の急所」- 渡辺竜王の最新理論
• 「基本定跡ABC」- 初心者向けの標準定跡書

▼ 最新の定跡：
最近の AI の影響で、従来の指し方が見直されています。''';
    } else {
      return '''（AIサービス実装予定）盤面を分析しています。

▼ 現局面の評価：
位置は互角ですが、次の数手で勝敗が分かれやすい場面です。

▼ 参考手：
７六歩、２六歩、３六歩 などが候補です。

さらに詳しい質問をしていただけますか？''';
    }
  }

  /// 質問を送信
  void _submitQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _isLoading = true;
      _lastQuestion = question;
      _aiResponse = null;
      _responseVisible = false;
    });

    try {
      final response = await _askAboutPosition(question);
      setState(() {
        _aiResponse = response;
        _responseVisible = true;
      });
    } catch (e) {
      setState(() {
        _aiResponse = 'エラーが発生しました: $e';
        _responseVisible = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 盤面にピースを配置（タップ操作）
  void _placePiece(int row, int col) {
    showDialog(
      context: context,
      builder: (ctx) => _PieceSelectorDialog(
        onPiecePicked: (piece) {
          setState(() {
            _board[row][col] = piece;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自然言語AI解説者'),
        elevation: 0,
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ────────────────────────────
              // 盤面セクション
              // ────────────────────────────
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.grid_3x3, size: 20, color: Colors.indigo),
                          const SizedBox(width: 8),
                          const Text(
                            '盤面を編集',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _board = _initialBoard();
                              });
                            },
                            icon: const Icon(Icons.restore, size: 18),
                            label: const Text('初期化'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.indigo.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'マス目をタップして駒を配置・削除できます',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTapDown: (details) {
                          // Find which cell was tapped
                          _findTappedCell(details.localPosition);
                        },
                        child: Container(
                          color: Colors.grey.shade100,
                          child: MiniBoardWidget(
                            board: _board,
                            showLabels: true,
                            size: 340,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ────────────────────────────
              // 質問入力セクション
              // ────────────────────────────
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.help_outline, size: 20, color: Colors.indigo),
                          const SizedBox(width: 8),
                          const Text(
                            '質問する',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _questionController,
                        maxLines: 3,
                        minLines: 1,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: '例：\n「なんでこの手ダメ？」\n「初心者向けに教えて」\n「この局面の定跡は？」',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _submitQuestion,
                          icon: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.indigo.shade600,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            _isLoading ? 'AI が分析中...' : '質問する',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ────────────────────────────
              // 応答セクション
              // ────────────────────────────
              if (_responseVisible && _aiResponse != null) ...[
                AnimatedOpacity(
                  opacity: _responseVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.indigo.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, size: 20, color: Colors.indigo),
                              const SizedBox(width: 8),
                              const Text(
                                'AI の解説',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const Spacer(),
                              Chip(
                                label: const Text('プレミアム'),
                                backgroundColor: Colors.amber.shade100,
                                side: BorderSide(color: Colors.amber.shade400),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_lastQuestion != null)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.indigo.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ご質問',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _lastQuestion!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _aiResponse!,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ────────────────────────────
                          // アクションボタン
                          // ────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _responseVisible = false;
                                    });
                                  },
                                  icon: const Icon(Icons.thumb_up_outlined, size: 18),
                                  label: const Text('参考になった'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.indigo.shade600,
                                    side: BorderSide(color: Colors.indigo.shade600),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _questionController.clear();
                                    setState(() {
                                      _responseVisible = false;
                                      _lastQuestion = null;
                                      _aiResponse = null;
                                    });
                                  },
                                  icon: const Icon(Icons.refresh_outlined, size: 18),
                                  label: const Text('もう一度'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.indigo.shade600,
                                    side: BorderSide(color: Colors.indigo.shade600),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ────────────────────────────
              // ユースケースヒント
              // ────────────────────────────
              if (_aiResponse == null && !_isLoading)
                Card(
                  elevation: 0,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.blue.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lightbulb_outline, size: 18, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'こんな質問ができます',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildHintItem('この手ダメ？', 'なぜその手が悪いのかを分析'),
                        _buildHintItem('初心者向けに', '簡単な言葉で説明'),
                        _buildHintItem('定跡を教えて', '参考図書や最新理論の紹介'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// ヒント項目を構築
  Widget _buildHintItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.blue.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// タップされたセルを検出（簡易版）
  void _findTappedCell(Offset localPosition) {
    // Calculate approximate cell from position
    // This is a simplified version - in production, consider using GestureDetector per cell
    final cellSize = 340 / 9;
    final labelOffset = 340 * 0.05;

    int col = ((localPosition.dx - labelOffset) / cellSize).floor();
    int row = ((localPosition.dy) / cellSize).floor();

    if (row >= 0 && row < 9 && col >= 0 && col < 9) {
      _placePiece(row, col);
    }
  }
}

// ────────────────────────────────────────
// 駒選択ダイアログ
// ────────────────────────────────────────

class _PieceSelectorDialog extends StatefulWidget {
  final Function(Piece?) onPiecePicked;

  const _PieceSelectorDialog({required this.onPiecePicked});

  @override
  State<_PieceSelectorDialog> createState() => _PieceSelectorDialogState();
}

class _PieceSelectorDialogState extends State<_PieceSelectorDialog> {
  bool _isPlayer1 = true;
  PieceType? _selectedType;

  final List<PieceType> _pieceTypes = [
    PieceType.pawn,
    PieceType.lance,
    PieceType.knight,
    PieceType.silver,
    PieceType.gold,
    PieceType.bishop,
    PieceType.rook,
    PieceType.king,
    PieceType.promotedPawn,
    PieceType.promotedLance,
    PieceType.promotedKnight,
    PieceType.promotedSilver,
    PieceType.promotedBishop,
    PieceType.promotedRook,
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('駒を選択'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 先手/後手切り替え
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: const Text('先手'),
                          icon: const Icon(Icons.person),
                        ),
                        ButtonSegment(
                          value: false,
                          label: const Text('後手'),
                          icon: const Icon(Icons.person_outline),
                        ),
                      ],
                      selected: {_isPlayer1},
                      onSelectionChanged: (selected) {
                        setState(() {
                          _isPlayer1 = selected.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      widget.onPiecePicked(null);
                    },
                    child: const Text('削除', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
            // 駒タイプグリッド
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: _pieceTypes.map((type) {
                final isSelected = _selectedType == type;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedType = type;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.indigo.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: Colors.indigo.shade600, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        Piece(type, _isPlayer1).label,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _isPlayer1 ? Colors.black87 : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _selectedType != null
              ? () {
                  widget.onPiecePicked(
                    Piece(_selectedType!, _isPlayer1),
                  );
                }
              : null,
          child: const Text('確定'),
        ),
      ],
    );
  }
}
