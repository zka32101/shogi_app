// lib/screens/story_overlay.dart
// ストーリー演出オーバーレイ（スキップ可能）

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/story_data.dart';

class StoryOverlay extends StatefulWidget {
  final StoryEvent storyEvent;
  final VoidCallback onComplete;

  const StoryOverlay({
    Key? key,
    required this.storyEvent,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<StoryOverlay> createState() => _StoryOverlayState();
}

class _StoryOverlayState extends State<StoryOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _delayController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _markAsShown();
  }

  void _initializeAnimations() {
    // フェードイン・フェードアウト（600ms）
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    // 表示時間後に自動クローズ
    if (widget.storyEvent.displayDuration != null) {
      _delayController = AnimationController(
        duration: widget.storyEvent.displayDuration!,
        vsync: this,
      );

      _fadeController.forward().then((_) {
        _delayController.forward().then((_) {
          _fadeController.reverse().then((_) {
            widget.onComplete();
          });
        });
      });
    } else {
      // 手動スキップまで表示
      _fadeController.forward();
    }
  }

  Future<void> _markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.storyEvent.sharedPrefKey, true);
  }

  void _skipStory() {
    _fadeController.reverse().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _delayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _skipStory,
      child: FadeTransition(
        opacity: _fadeController,
        child: Container(
          color: _parseColor(widget.storyEvent.backgroundColor ?? '#000000')
              .withOpacity(0.8),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // キャラクターイメージ（該当する場合）
                if (widget.storyEvent.characterId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 80,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),

                // タイトル
                if (widget.storyEvent.title.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      widget.storyEvent.title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // 説明文
                if (widget.storyEvent.description != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      widget.storyEvent.description!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            height: 1.6,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // スキップ表示
                if (widget.storyEvent.displayDuration == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: Text(
                      'タップでスキップ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    // "#RRGGBB" 形式をパース
    String hexColor = colorString.replaceAll('#', '');
    if (hexColor.length == 6) {
      return Color(int.parse('FF$hexColor', radix: 16));
    }
    return Colors.black;
  }
}

// ===== ストーリー表示ユーティリティ =====

class StoryManager {
  static Future<bool> shouldShowStory(StoryEvent storyEvent) async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.getBool(storyEvent.sharedPrefKey);
  }

  static Future<void> showStoryIfNeeded(
    BuildContext context,
    StoryEvent storyEvent,
  ) async {
    if (await shouldShowStory(storyEvent)) {
      if (!context.mounted) return;

      await _showStoryOverlay(context, storyEvent);
    }
  }

  static Future<void> _showStoryOverlay(
    BuildContext context,
    StoryEvent storyEvent,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black87,
        child: StoryOverlay(
          storyEvent: storyEvent,
          onComplete: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  /// 複数のストーリーイベントを順序付きで表示
  static Future<void> showStoriesInSequence(
    BuildContext context,
    List<StoryEvent> stories,
  ) async {
    for (final story in stories) {
      if (!context.mounted) break;
      await showStoryIfNeeded(context, story);
    }
  }
}

// ===== エンディング選択画面 =====

class EndingChoiceScreen extends StatelessWidget {
  final Function(EndingType) onChoose;

  const EndingChoiceScreen({
    Key? key,
    required this.onChoose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '棋王が崩れ落ちる',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                '「では、貴様が新しい秩序を決めよ」',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              // エンディング選択肢
              ...endingChoices.map((choice) => Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: _EndingChoiceButton(
                      choice: choice,
                      onTap: () {
                        onChoose(choice.type);
                        Navigator.of(context).pop();
                      },
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndingChoiceButton extends StatelessWidget {
  final EndingChoice choice;
  final VoidCallback onTap;

  const _EndingChoiceButton({
    Key? key,
    required this.choice,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                choice.title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 8),
              Text(
                choice.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(height: 8),
              Text(
                '報酬: ${choice.reward}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
