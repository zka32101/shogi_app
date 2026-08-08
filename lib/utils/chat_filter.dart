// lib/utils/chat_filter.dart
// 対局チャット・観戦チャット共通の禁止ワードフィルター。
// 以前は match_chat_widget.dart の PostMatchChatWidget にのみ実装されており、
// 観戦者チャット(spectator_service.dart)には一切適用されていなかったため、
// 共通ユーティリティとして切り出して両方から使えるようにした。

class ChatFilter {
  ChatFilter._();

  // 禁止ワードリスト（追加可能）
  static const bannedWords = [
    'バカ', 'ばか', '馬鹿', 'アホ', 'あほ', '阿呆',
    'クソ', 'くそ', '糞', 'キモい', 'きもい', '気持ち悪い',
    'うざい', 'ウザい', 'うざ', 'ウザ', '死ね', 'しね',
    '消えろ', 'ゴミ', 'ごみ', 'ハゲ', 'デブ', 'ブス',
    'カス', 'かす', 'チート', '不正', 'ソフト指し',
  ];

  // 単語以外の文字（空白・記号・数字・絵文字・ゼロ幅スペース等）をすべて
  // 除去してから比較することで、禁止ワードの文字の間に区切り文字を挟む
  // 回避（例:「し ね」「し.ね」「し0ね」「し🙂ね」）を防ぐ。
  // 以前は特定の区切り文字だけを除去する方式だったため、リストにない文字
  // （数字・絵文字・ゼロ幅スペースU+200B等）を挟むだけで回避できてしまっていた。
  // 逆に「文字(\p{L})以外をすべて除去する」ホワイトリスト方式にすることで、
  // 未知の回避文字にも網羅的に対応する
  static final _nonLetterPattern = RegExp(r'[^\p{L}]+', unicode: true);

  /// 禁止ワードが含まれていれば null、問題なければ trim 済みのテキストを返す
  static String? filter(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;
    final normalized = trimmed.replaceAll(_nonLetterPattern, '');
    for (final word in bannedWords) {
      if (trimmed.contains(word) || normalized.contains(word)) {
        return null; // null = 送信禁止
      }
    }
    return trimmed;
  }
}
