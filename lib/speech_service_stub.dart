// lib/speech_service_stub.dart — モバイル/デスクトップ用スタブ（音声読み上げ非対応）

class SpeechService {
  static bool _enabled = false;
  static bool get enabled => _enabled;

  static void setEnabled(bool v) => _enabled = v;

  /// No-op on non-web platforms
  static void speak(String text) {}

  static String moveText(bool isP1, String note) => note;
}
