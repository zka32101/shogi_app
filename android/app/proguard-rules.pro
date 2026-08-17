# android/app/proguard-rules.pro
# R8/ProGuardの難読化・リソース削減(isMinifyEnabled/isShrinkResources)を
# 有効化するにあたり追加した標準的なkeepルール。
#
# 注意: Flutter/Dartのアプリ本体コードはAOTコンパイルされてlibapp.soに
# ネイティブコードとして組み込まれるため、R8の影響を受けない。R8が処理するのは
# Androidプラットフォームチャンネル側のJava/Kotlinコード（各pluginのAndroid実装）
# のみで、多くの最新pluginはAAR内にconsumer-proguard-rules.proを同梱しており
# 自動的に適用されるため、本ファイルは主に念のための保険的なルールである。
#
# ⚠️ この環境にはFlutter実行環境が無く実機/実ビルドでの動作確認ができていない。
# 有効化に伴いリリースビルドが正しく動作するか、必ず実際に
# `flutter build appbundle --release` 相当のビルドで動作確認すること
# （Firebase認証・Firestore/RTDB同期・AdMob広告表示・課金・音声入力等の
# 主要機能を一通り触って確認するのが望ましい）。

# Flutter本体（念のため）
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase（Auth/Firestore/Realtime Database/Cloud Messaging/Functions）
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Google Play In-App Purchase / Billing
-keep class com.android.vending.billing.** { *; }
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# speech_to_text（音声認識プラグイン）
-keep class com.csdcorp.speech_to_text.** { *; }

# JSON等のリフレクションを使うモデルクラスがある場合に備え、
# アノテーション・シグネチャ情報は保持する
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
