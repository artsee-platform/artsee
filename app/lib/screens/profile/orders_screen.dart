import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await BackendApiService.fetchMyOrders(limit: 50);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.artC.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '我的订单',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.artC.ink,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: kCobalt,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: const Center(
              child:
                  CircularProgressIndicator(color: kCobalt, strokeWidth: 2.5),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.receipt_long_outlined,
              size: 42, color: context.artC.ink.withValues(alpha: 0.18)),
          const SizedBox(height: 14),
          Text(
            '订单加载失败',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: context.artC.ink.withValues(alpha: 0.42)),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: kCobalt),
              child: const Text('重试'),
            ),
          ),
        ],
      );
    }

    if (_orders.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 140),
          Icon(Icons.receipt_long_outlined,
              size: 46, color: context.artC.ink.withValues(alpha: 0.16)),
          const SizedBox(height: 14),
          Text(
            '暂无订单',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '课程、咨询与服务支付记录会显示在这里。',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: context.artC.ink.withValues(alpha: 0.42)),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _OrderCard(order: _orders[index]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString() ?? 'pending';
    final meta = _statusMeta(status);
    final amount = ((order['amount_total'] as num?)?.toInt() ?? 0) / 100;
    final currency = order['currency']?.toString().toUpperCase() ?? 'CNY';
    final subject = order['subject']?.toString() ?? 'Artiqore 服务订单';
    final orderNo = order['order_no']?.toString() ?? '';
    final createdAt = order['created_at']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLarge),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.45)),
        boxShadow: [kShadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  subject,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.artC.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  meta.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: meta.color,
                  ),
                ),
              ),
            ],
          ),
          if (orderNo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '订单号 $orderNo',
              style: TextStyle(
                  fontSize: 10,
                  color: context.artC.ink.withValues(alpha: 0.34)),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '下单时间',
                    style: TextStyle(
                        fontSize: 10,
                        color: context.artC.ink.withValues(alpha: 0.32)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _dateText(createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.artC.ink.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
              Text(
                currency == 'CNY'
                    ? '¥${amount.toStringAsFixed(2)}'
                    : '$currency ${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: kCobalt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ({String label, Color color}) _statusMeta(String status) {
    switch (status) {
      case 'paid':
        return (label: '已支付', color: const Color(0xFF16A34A));
      case 'failed':
        return (label: '支付失败', color: const Color(0xFFDC2626));
      case 'canceled':
        return (label: '已取消', color: const Color(0xFF64748B));
      case 'expired':
        return (label: '已过期', color: const Color(0xFF64748B));
      case 'refunded':
        return (label: '已退款', color: kCobaltMuted);
      default:
        return (label: '待支付', color: const Color(0xFFCA8A04));
    }
  }

  String _dateText(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '—';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
