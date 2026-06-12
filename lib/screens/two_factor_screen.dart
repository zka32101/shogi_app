// lib/screens/two_factor_screen.dart
// 二要素認証画面（メール OTP + 電話番号）

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class TwoFactorScreen extends StatefulWidget {
  /// true = 設定画面、false = ログイン確認画面
  final bool isSetup;

  const TwoFactorScreen({super.key, this.isSetup = false});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId; // 電話認証用
  String? _expectedCode;   // メール OTP 用（本来はサーバーサイドで検証）
  int _tab = 0; // 0=メール, 1=電話

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          widget.isSetup ? '2段階認証の設定' : '本人確認',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // アイコン
              const Center(
                child: Icon(Icons.security, size: 64, color: Colors.amber),
              ),
              const SizedBox(height: 16),
              Text(
                widget.isSetup
                    ? '2段階認証を設定してアカウントを保護しましょう'
                    : 'ログインを確認するためにコードを入力してください',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 24),

              // タブ選択
              Row(
                children: [
                  Expanded(
                    child: _tabButton('メール認証', 0),
                  ),
                  Expanded(
                    child: _tabButton('SMS認証', 1),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // コンテンツ
              _tab == 0 ? _buildEmailTab() : _buildPhoneTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final isActive = _tab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _tab = index;
        _codeSent = false;
        _codeController.clear();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? Colors.amber : Colors.white24,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.amber : Colors.white54,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── メール OTP タブ ─────────────────────────────────────────

  Widget _buildEmailTab() {
    final user = _auth.currentUser;
    final email = user?.email ?? '未設定';

    return Column(
      children: [
        // メールアドレス表示
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.email, color: Colors.white54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  email,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (!_codeSent) ...[
          // コード送信ボタン
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _sendEmailCode,
            icon: const Icon(Icons.send),
            label: const Text('確認コードを送信'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ] else ...[
          // コード入力
          _buildCodeInput(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _verifyEmailCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('確認する'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _sendEmailCode,
            child: const Text('コードを再送する',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ],
    );
  }

  // ── SMS タブ ─────────────────────────────────────────────────

  Widget _buildPhoneTab() {
    final phoneController = TextEditingController();

    return Column(
      children: [
        if (!_codeSent) ...[
          // 電話番号入力
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '+81 90-0000-0000',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.phone, color: Colors.white54),
              filled: true,
              fillColor: Colors.grey.shade900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isLoading
                ? null
                : () => _sendSmsCode(phoneController.text),
            icon: const Icon(Icons.sms),
            label: const Text('SMS コードを送信'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ] else ...[
          _buildCodeInput(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _verifySmsCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('確認する'),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'SMS 認証は Firebase Phone Auth が必要です。\n'
          'firebase_auth の PhoneAuthProvider を使用します。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCodeInput() {
    return TextField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        letterSpacing: 12,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        hintText: '000000',
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.grey.shade900,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ── メール OTP 処理 ─────────────────────────────────────────

  Future<void> _sendEmailCode() async {
    setState(() => _isLoading = true);
    try {
      // OTP を生成（本来はサーバーサイドで生成・メール送信）
      final code = _generateOTP();
      _expectedCode = code;

      // Firestore に一時保存（有効期限 10 分）
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('otp_codes').doc(uid).set({
          'code': code,
          'created_at': DateTime.now(),
          'expires_at': DateTime.now().add(const Duration(minutes: 10)),
          'type': 'email',
        });
      }

      // Cloud Functions trigger でメール送信（本実装では Functions が必要）
      // ここでは Firestore に書いてトリガーさせる想定
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '確認コードを ${_auth.currentUser?.email} に送信しました'),
          ),
        );
        setState(() {
          _codeSent = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyEmailCode() async {
    final entered = _codeController.text.trim();
    if (entered.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6桁のコードを入力してください')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('未ログイン');

      // Firestore からコードを検証
      final otpDoc =
          await _firestore.collection('otp_codes').doc(uid).get();
      if (!otpDoc.exists) throw Exception('コードが見つかりません');

      final storedCode = otpDoc['code'] as String?;
      final expiresAt = otpDoc['expires_at'];
      DateTime? expiry;
      if (expiresAt is Timestamp) {
        expiry = expiresAt.toDate();
      }

      if (expiry != null && DateTime.now().isAfter(expiry)) {
        throw Exception('コードの有効期限が切れています');
      }

      if (storedCode != entered) {
        throw Exception('コードが正しくありません');
      }

      // 認証成功 → 2FA フラグを立てる
      await _firestore.collection('users').doc(uid).update({
        'two_factor_enabled': true,
        'two_factor_method': 'email',
      });

      // OTP を削除
      await _firestore.collection('otp_codes').doc(uid).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('2段階認証を設定しました')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // ── SMS 認証処理 ────────────────────────────────────────────

  Future<void> _sendSmsCode(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('電話番号を入力してください')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android 自動検証
          await _auth.currentUser?.linkWithCredential(credential);
          if (mounted) Navigator.pop(context, true);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('認証エラー: ${e.message}')),
            );
            setState(() => _isLoading = false);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _codeSent = true;
              _isLoading = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifySmsCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || _verificationId == null) return;

    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _auth.currentUser?.linkWithCredential(credential);

      // 2FA フラグを更新
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).update({
          'two_factor_enabled': true,
          'two_factor_method': 'phone',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS 認証を設定しました')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // ── ヘルパー ─────────────────────────────────────────────────

  String _generateOTP() {
    final rng = Random.secure();
    return List.generate(6, (_) => rng.nextInt(10)).join();
  }
}
