// lib/subscription_card.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'purchase_service.dart';

class SubscriptionCard extends StatefulWidget {
  const SubscriptionCard({super.key});

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  bool _subLoading = false;
  bool _themeLoading = false;

  Future<void> _purchaseSub() async {
    setState(() => _subLoading = true);
    await PurchaseService.purchase();
    if (mounted) setState(() => _subLoading = false);
  }

  Future<void> _restore() async {
    if (!PurchaseService.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('この端末では課金機能が利用できません'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    setState(() => _subLoading = true);
    await PurchaseService.restore();
    if (mounted) {
      setState(() => _subLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('復元処理を開始しました。\n購入済みの場合は自動で反映されます。'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _purchaseThemePack() async {
    setState(() => _themeLoading = true);
    await PurchaseService.purchaseThemePack();
    if (mounted) setState(() => _themeLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProPlanCard(
          loading: _subLoading,
          onPurchase: _purchaseSub,
          onRestore: _restore,
        ),
        const SizedBox(height: 12),
        _ThemePackCard(
          loading: _themeLoading,
          onPurchase: _purchaseThemePack,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Proプランカード（月額サブスクリプション）
// ---------------------------------------------------------------------------
class _ProPlanCard extends StatelessWidget {
  const _ProPlanCard({
    required this.loading,
    required this.onPurchase,
    required this.onRestore,
  });

  final bool loading;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;

  String get _priceLabel {
    final p = PurchaseService.product;
    return p != null ? p.price : '¥250/月';
  }

  @override
  Widget build(BuildContext context) {
    final hasSub = PurchaseService.hasSubscription;
    final canPurchase = PurchaseService.isAvailable && !kIsWeb;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasSub
              ? [Colors.green.shade900, Colors.teal.shade900]
              : [Colors.amber.shade900, Colors.orange.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSub ? Colors.green.shade400 : Colors.amber.shade400,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: hasSub ? _activeView() : _inactiveView(canPurchase),
    );
  }

  Widget _activeView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: const [
          Icon(Icons.workspace_premium, color: Colors.greenAccent, size: 22),
          SizedBox(width: 8),
          Text(
            'Proプラン',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(width: 8),
          Chip(
            label: Text('有効中', style: TextStyle(color: Colors.white, fontSize: 10)),
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
      const SizedBox(height: 12),
      _BenefitRow(icon: Icons.block, label: '対局中の広告を非表示'),
      _BenefitRow(icon: Icons.palette, label: 'プレミアムテーマパック（込み）'),
      _BenefitRow(icon: Icons.analytics, label: '週次AI振り返りレポート'),
      _BenefitRow(
        icon: Icons.extension,
        label: '詰将棋・手筋問題 Pro解放（予定）',
        dimmed: true,
      ),
      const SizedBox(height: 8),
      const Text(
        'ご利用ありがとうございます',
        style: TextStyle(color: Colors.white60, fontSize: 12),
      ),
    ],
  );

  Widget _inactiveView(bool canPurchase) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: const [
          Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 22),
          SizedBox(width: 8),
          Text(
            'Proプラン',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _BenefitRow(icon: Icons.block, label: '対局中の広告を非表示'),
      _BenefitRow(icon: Icons.palette, label: 'プレミアムテーマパック（込み）'),
      _BenefitRow(icon: Icons.analytics, label: '週次AI振り返りレポート'),
      _BenefitRow(
        icon: Icons.extension,
        label: '詰将棋・手筋問題 Pro解放（予定）',
        dimmed: true,
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canPurchase
                    ? Colors.amber.shade600
                    : Colors.grey.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: canPurchase && !loading ? onPurchase : null,
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      canPurchase ? '購読する  $_priceLabel' : '購入不可',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: canPurchase && !loading ? onRestore : null,
            child: const Text(
              '購入を復元',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
        ],
      ),
      if (!canPurchase)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            '※ このデバイスでは購入できません',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// テーマパックカード（一回払い）
// ---------------------------------------------------------------------------
class _ThemePackCard extends StatelessWidget {
  const _ThemePackCard({
    required this.loading,
    required this.onPurchase,
  });

  final bool loading;
  final VoidCallback onPurchase;

  String get _priceLabel {
    final p = PurchaseService.themePackProduct;
    return p != null ? '${p.price} (買い切り)' : '¥120 (買い切り)';
  }

  @override
  Widget build(BuildContext context) {
    final hasPack = PurchaseService.hasThemePack;
    final canPurchase = PurchaseService.isAvailable && !kIsWeb;

    return Container(
      decoration: BoxDecoration(
        gradient: hasPack
            ? LinearGradient(
                colors: [Colors.purple.shade900, Colors.indigo.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: hasPack ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPack ? Colors.purple.shade400 : Colors.purple.shade700,
          width: hasPack ? 1 : 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: hasPack ? _purchasedView() : _unpurchasedView(canPurchase),
    );
  }

  Widget _purchasedView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: const [
          Icon(Icons.palette, color: Colors.purpleAccent, size: 22),
          SizedBox(width: 8),
          Text(
            'プレミアムテーマパック',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          SizedBox(width: 8),
          Chip(
            label: Text('所持中', style: TextStyle(color: Colors.white, fontSize: 10)),
            backgroundColor: Colors.purple,
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
      const SizedBox(height: 10),
      _ThemePreviewRow(),
    ],
  );

  Widget _unpurchasedView(bool canPurchase) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.palette, color: Colors.purple.shade300, size: 22),
          const SizedBox(width: 8),
          const Text(
            'プレミアムテーマパック',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _ThemePreviewRow(),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canPurchase
                    ? Colors.purple.shade700
                    : Colors.grey.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: canPurchase && !loading ? onPurchase : null,
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      canPurchase ? '購入する  $_priceLabel' : '購入不可',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
      if (!canPurchase)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            '※ このデバイスでは購入できません',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// テーマプレビュー行（エメラルド / 桜）
// ---------------------------------------------------------------------------
class _ThemePreviewRow extends StatelessWidget {
  const _ThemePreviewRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ThemeChip(emoji: '🌿', label: 'エメラルド'),
        const SizedBox(width: 10),
        _ThemeChip(emoji: '🌸', label: '桜'),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.emoji, required this.label});

  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 特典アイテム行
// ---------------------------------------------------------------------------
class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.label,
    this.dimmed = false,
  });

  final IconData icon;
  final String label;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final color = dimmed ? Colors.white38 : Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
