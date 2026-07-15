import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/artsee_ui.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Map<String, dynamic> _order;
  List<Map<String, dynamic>> _refunds = [];
  Map<String, dynamic>? _paymentProviders;
  bool _loading = false;
  bool _checkingOut = false;
  bool _requestingRefund = false;
  String? _error;
  String? _paymentProviderError;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _load();
  }

  Future<void> _load() async {
    final id = _order['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await BackendApiService.fetchMyOrder(id);
      final refunds = await BackendApiService.fetchOrderRefunds(id);
      Map<String, dynamic>? paymentProviders;
      String? paymentProviderError;
      try {
        paymentProviders = await BackendApiService.fetchPaymentProviders();
      } catch (e) {
        paymentProviderError = e.toString();
      }
      if (!mounted) return;
      setState(() {
        _order = data;
        _refunds = refunds;
        _paymentProviders = paymentProviders;
        _paymentProviderError = paymentProviderError;
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

  Future<void> _checkout() async {
    final id = _order['id']?.toString();
    if (id == null || id.isEmpty || _checkingOut) return;
    setState(() => _checkingOut = true);
    try {
      final data = await BackendApiService.checkoutExistingOrder(id);
      final order = data['order'];
      if (!mounted) return;
      if (order is Map<String, dynamic>) {
        setState(() => _order = order);
      }
      final checkoutUrl = data['checkoutUrl']?.toString();
      if (checkoutUrl != null && checkoutUrl.startsWith('/orders/')) {
        final paid = await BackendApiService.confirmExistingOrder(id);
        if (!mounted) return;
        setState(() => _order = paid);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支付已确认')),
        );
        return;
      }
      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        final url = checkoutUrl.startsWith('http')
            ? checkoutUrl
            : '${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}$checkoutUrl';
        final opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        if (!opened) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('请在浏览器打开：$url')),
          );
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('支付单已创建')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建支付失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  Future<void> _requestRefund() async {
    final id = _order['id']?.toString();
    if (id == null || id.isEmpty || _requestingRefund) return;
    final reason = await _showRefundReasonSheet();
    if (reason == null) return;
    setState(() => _requestingRefund = true);
    try {
      await BackendApiService.requestOrderRefund(id: id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('退款申请已提交')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交退款失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _requestingRefund = false);
    }
  }

  Future<String?> _showRefundReasonSheet() async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 22,
          ),
          decoration: BoxDecoration(
            color: context.artC.cardIconBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kCobalt.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.undo_rounded, color: kCobalt),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '申请退款',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: context.artC.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: '退款原因',
                    hintText: '请简要说明退款原因，运营会在后台处理。',
                    filled: true,
                    fillColor: context.artC.porcelain.withValues(alpha: 0.72),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: context.artC.silver.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kCobalt),
                    onPressed: () =>
                        Navigator.of(context).pop(controller.text.trim()),
                    child: const Text(
                      '提交申请',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final status = _order['status']?.toString() ?? 'pending';
    final statusMeta = _orderStatusMeta(status);
    final subject = _order['subject']?.toString() ?? 'Artiqore 服务订单';
    final orderNo = _order['order_no']?.toString();
    final amount = _formatOrderAmount(_order);
    final canRequestRefund = status == 'paid' && !_hasActiveRefund(_refunds);

    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: context.artC.porcelain,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: '返回',
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.artC.ink, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '订单详情',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: context.artC.ink,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: context.artC.ink.withValues(alpha: 0.56),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kCobalt,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            if (_loading) const _LoadingStrip(),
            if (_error != null) ...[
              _NoticeCard(
                title: '订单详情加载失败',
                body: _error!,
              ),
              const SizedBox(height: 12),
            ],
            ArtseeSurface(
              padding: const EdgeInsets.all(18),
              radius: 20,
              elevated: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: statusMeta.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: statusMeta.color,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.22,
                                fontWeight: FontWeight.w900,
                                color: context.artC.ink,
                              ),
                            ),
                            if (_notBlank(orderNo)) ...[
                              const SizedBox(height: 5),
                              Text(
                                '订单号 $orderNo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      context.artC.ink.withValues(alpha: 0.42),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(meta: statusMeta),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: kCobalt,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _InfoCard(
              rows: [
                _InfoRow(
                  label: '订单状态',
                  value: statusMeta.label,
                ),
                _InfoRow(
                  label: '订单类型',
                  value: _itemTypeLabel(_order['item_type']?.toString()),
                ),
                _InfoRow(
                  label: '创建时间',
                  value: _formatDetailTime(_order['created_at']) ?? '-',
                ),
                if (_formatDetailTime(_order['paid_at']) != null)
                  _InfoRow(
                    label: '支付时间',
                    value: _formatDetailTime(_order['paid_at'])!,
                  ),
              ],
            ),
            if (_isCheckoutable(status)) ...[
              const SizedBox(height: 16),
              _PaymentProvidersCard(
                data: _paymentProviders,
                error: _paymentProviderError,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kCobalt,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _checkingOut ? null : _checkout,
                icon: _checkingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.payments_outlined, size: 18),
                label: Text(
                  _checkoutButtonLabel(
                    status,
                    _paymentProviders,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
            if (_refunds.isNotEmpty) ...[
              const SizedBox(height: 12),
              _RefundsCard(refunds: _refunds),
            ],
            if (canRequestRefund) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCobalt,
                  side: BorderSide(color: kCobalt.withValues(alpha: 0.28)),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _requestingRefund ? null : _requestRefund,
                icon: _requestingRefund
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kCobalt,
                        ),
                      )
                    : const Icon(Icons.undo_rounded, size: 18),
                label: const Text(
                  '申请退款',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RefundsCard extends StatelessWidget {
  final List<Map<String, dynamic>> refunds;

  const _RefundsCard({required this.refunds});

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      padding: const EdgeInsets.all(16),
      radius: 18,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '退款记录',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 10),
          ...refunds.map((refund) {
            final status = refund['status']?.toString() ?? 'requested';
            final meta = _refundStatusMeta(status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(Icons.undo_rounded, size: 16, color: meta.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatRefundAmount(refund),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: context.artC.ink,
                                ),
                              ),
                            ),
                            _StatusPill(meta: meta),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (_notBlank(refund['reason']?.toString()))
                              refund['reason'].toString(),
                            _formatDetailTime(refund['requested_at']) ?? '',
                          ].where((item) => item.isNotEmpty).join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: context.artC.ink.withValues(alpha: 0.48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: LinearProgressIndicator(
        minHeight: 2,
        color: kCobalt,
        backgroundColor: Color(0x00000000),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;

  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      padding: const EdgeInsets.all(16),
      radius: 18,
      elevated: false,
      child: Column(
        children: rows.map((row) => _InfoLine(row: row)).toList(),
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });
}

class _InfoLine extends StatelessWidget {
  final _InfoRow row;

  const _InfoLine({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              row.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: context.artC.ink.withValues(alpha: 0.42),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                height: 1.38,
                fontWeight: FontWeight.w800,
                color: context.artC.ink.withValues(alpha: 0.76),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentProvidersCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  final String? error;

  const _PaymentProvidersCard({
    required this.data,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = _enabledPaymentProviders(data);
    final hasError = error != null && error!.isNotEmpty;
    final isInternalOnly =
        enabled.isNotEmpty && enabled.every((item) => item['id'] == 'internal');
    return ArtseeSurface(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      radius: 16,
      elevated: false,
      color: Colors.white.withValues(alpha: 0.78),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isInternalOnly
                    ? Icons.science_outlined
                    : Icons.account_balance_wallet_outlined,
                size: 18,
                color: kCobalt,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '支付方式',
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (enabled.isEmpty)
            Text(
              hasError ? '支付渠道暂时无法读取，仍可尝试创建支付单。' : '正在确认可用支付渠道。',
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.46),
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: enabled
                  .map(
                    (item) => _PaymentProviderChip(
                      label: item['label']?.toString() ?? '支付方式',
                      test: item['test'] == true,
                    ),
                  )
                  .toList(),
            ),
          if (isInternalOnly) ...[
            const SizedBox(height: 9),
            Text(
              '当前为内部测试支付，会直接确认订单状态；正式环境需配置微信、支付宝或银行卡支付服务商。',
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.42),
                fontSize: 10.5,
                height: 1.42,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentProviderChip extends StatelessWidget {
  final String label;
  final bool test;

  const _PaymentProviderChip({
    required this.label,
    required this.test,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: test
            ? context.artC.silver.withValues(alpha: 0.18)
            : kCobalt.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        test ? '$label · 测试' : label,
        style: TextStyle(
          color: test ? context.artC.ink.withValues(alpha: 0.58) : kCobalt,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ({String label, Color color}) meta;

  const _StatusPill({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        meta.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: meta.color,
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String title;
  final String body;

  const _NoticeCard({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: context.artC.ink.withValues(alpha: 0.48),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: context.artC.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.38,
                    fontWeight: FontWeight.w700,
                    color: context.artC.ink.withValues(alpha: 0.52),
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

({String label, Color color}) _orderStatusMeta(String status) {
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
    case 'checkout_created':
      return (label: '待支付', color: const Color(0xFFCA8A04));
    default:
      return (label: '待支付', color: const Color(0xFFCA8A04));
  }
}

({String label, Color color}) _refundStatusMeta(String status) {
  switch (status) {
    case 'approved':
      return (label: '已通过', color: kCobalt);
    case 'processing':
      return (label: '处理中', color: const Color(0xFF4F46E5));
    case 'succeeded':
      return (label: '已退款', color: const Color(0xFF16A34A));
    case 'failed':
      return (label: '退款失败', color: const Color(0xFFDC2626));
    case 'rejected':
      return (label: '未通过', color: const Color(0xFFDC2626));
    case 'canceled':
      return (label: '已取消', color: const Color(0xFF64748B));
    default:
      return (label: '待审核', color: const Color(0xFFCA8A04));
  }
}

bool _hasActiveRefund(List<Map<String, dynamic>> refunds) {
  const active = {'requested', 'approved', 'processing', 'succeeded'};
  return refunds.any((refund) => active.contains(refund['status']?.toString()));
}

bool _isCheckoutable(String status) {
  return status == 'pending' ||
      status == 'checkout_created' ||
      status == 'failed' ||
      status == 'expired';
}

List<Map<String, dynamic>> _enabledPaymentProviders(
    Map<String, dynamic>? data) {
  final raw = data?['providers'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .where((item) => item['enabled'] == true)
      .toList();
}

String _checkoutButtonLabel(String status, Map<String, dynamic>? providers) {
  final enabled = _enabledPaymentProviders(providers);
  final internalOnly =
      enabled.isNotEmpty && enabled.every((item) => item['id'] == 'internal');
  if (internalOnly) return status == 'checkout_created' ? '确认测试支付' : '创建测试支付';
  return status == 'checkout_created' ? '继续支付' : '去支付';
}

String _formatOrderAmount(Map<String, dynamic> order) {
  final raw = order['amount_total'];
  final cents = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  final amount = (cents ?? 0) / 100;
  final currency = order['currency']?.toString().toUpperCase() ?? 'CNY';
  if (currency == 'CNY') return '¥${amount.toStringAsFixed(2)}';
  return '$currency ${amount.toStringAsFixed(2)}';
}

String _formatRefundAmount(Map<String, dynamic> refund) {
  final raw = refund['amount'];
  final cents = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  final amount = (cents ?? 0) / 100;
  final currency = refund['currency']?.toString().toUpperCase() ?? 'CNY';
  if (currency == 'CNY') return '退款 ¥${amount.toStringAsFixed(2)}';
  return '退款 $currency ${amount.toStringAsFixed(2)}';
}

String _itemTypeLabel(String? type) {
  switch (type) {
    case 'consultation':
      return '咨询转化服务';
    case 'course':
      return '课程';
    case 'service':
      return '服务';
    default:
      return type == null || type.isEmpty ? '服务' : type;
  }
}

bool _notBlank(String? value) => value != null && value.trim().isNotEmpty;

String? _formatDetailTime(dynamic raw) {
  final value = raw?.toString();
  if (value == null || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
