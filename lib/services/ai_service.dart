// lib/services/ai_service.dart
class AIService {
  // Will be Gemini or Claude
  static Future<String> explainPosition(String boardJson, String question) async {
    // TODO: Implement with Gemini or Claude
    return "（AI解説実装予定）まずは質問をありがとうございます。この局面について詳しく考えてみますね...";
  }

  static Future<String> generateCoachFeedback(String gameResult, String playStyle) async {
    // TODO: Implement with Gemini or Claude
    return "（AIコーチ実装予定）今局のあなたの指し方について...";
  }

  static Future<String> analyzeBoardFromImage(String imagePath) async {
    // TODO: Implement OCR + Claude
    return "（OCR分析実装予定）撮影した盤面から...";
  }
}
