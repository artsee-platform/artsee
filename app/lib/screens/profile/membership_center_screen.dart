import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class MembershipCenterScreen extends StatefulWidget {
  const MembershipCenterScreen({super.key});

  @override
  State<MembershipCenterScreen> createState() => _MembershipCenterScreenState();
}

class _MembershipCenterScreenState extends State<MembershipCenterScreen> {
  Map<String, dynamic>? _membership;
  String _plan = 'yearly';
  bool _loading = true;
  bool _submitting = false;
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
      final membership = await BackendApiService.fetchMembership();
      if (!mounted) return;
      setState(() {
        _membership = membership;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _upgrade() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final checkout = await BackendApiService.createMembershipUpgrade(
        plan: _plan,
      );
      final rawUrl = checkout['checkoutUrl']?.toString() ?? '';
      final orderId = _checkoutOrderId(checkout);
      if (rawUrl.startsWith('/orders/') && orderId.isNotEmpty) {
        await BackendApiService.confirmExistingOrder(orderId);
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('会员已开通')),
        );
        return;
      }
      if (rawUrl.isNotEmpty) {
        final url = rawUrl.startsWith('http')
            ? rawUrl
            : '${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}$rawUrl';
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
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建会员订单失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: context.artC.porcelain,
        elevation: 0,
        foregroundColor: context.artC.ink,
        title: const Text(
          '会员中心',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: kCobalt, strokeWidth: 2.5),
            )
          : RefreshIndicator(
              color: kCobalt,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  if (_error != null)
                    _ErrorPanel(error: _error!, onRetry: _load),
                  if (_error == null) ...[
                    _MembershipStatusCard(membership: _membership),
                    const SizedBox(height: 14),
                    const _BenefitPanel(),
                    const SizedBox(height: 14),
                    _PlanChooser(
                      value: _plan,
                      enabled: !_submitting,
                      onChanged: (value) => setState(() => _plan = value),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _upgrade,
                        style: FilledButton.styleFrom(backgroundColor: kCobalt),
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.workspace_premium_outlined),
                        label: Text(
                          _submitting
                              ? '创建订单中'
                              : _plan == 'monthly'
                                  ? '开通月度会员'
                                  : '开通年度会员',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _MembershipStatusCard extends StatelessWidget {
  final Map<String, dynamic>? membership;

  const _MembershipStatusCard({required this.membership});

  @override
  Widget build(BuildContext context) {
    final isMember = membership?['is_member'] == true;
    final status = membership?['status']?.toString() ?? 'free';
    final expiresAt = membership?['expires_at']?.toString();
    final expired = status == 'expired';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isMember
                  ? kCobalt
                  : expired
                      ? const Color(0xFFD06124).withValues(alpha: 0.16)
                      : context.artC.silver.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isMember
                  ? Icons.verified_rounded
                  : expired
                      ? Icons.event_busy_outlined
                      : Icons.lock_outline_rounded,
              color: isMember
                  ? Colors.white
                  : expired
                      ? const Color(0xFFD06124)
                      : context.artC.ink.withValues(alpha: 0.42),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMember
                      ? '会员权益已开启'
                      : expired
                          ? '会员已过期'
                          : '当前为免费用户',
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isMember && expiresAt != null
                      ? '有效期至 ${_dateText(expiresAt)}'
                      : expired && expiresAt != null
                          ? '已于 ${_dateText(expiresAt)} 到期，可续费恢复权益'
                          : '开通后可联系官方组织',
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.48),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _BenefitPanel extends StatelessWidget {
  const _BenefitPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: const Column(
        children: [
          _BenefitRow(
              icon: Icons.chat_bubble_outline_rounded, label: '向官方组织发起线上会话'),
          SizedBox(height: 10),
          _BenefitRow(icon: Icons.storefront_outlined, label: '查看线下地址、电话和企业微信'),
          SizedBox(height: 10),
          _BenefitRow(icon: Icons.description_outlined, label: '签约后上传合同存档'),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BenefitRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kCobalt, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanChooser extends StatelessWidget {
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _PlanChooser({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PlanTile(
            title: '月度会员',
            subtitle: '短期体验',
            selected: value == 'monthly',
            enabled: enabled,
            onTap: () => onChanged('monthly'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PlanTile(
            title: '年度会员',
            subtitle: '完整申请周期',
            selected: value == 'yearly',
            enabled: enabled,
            onTap: () => onChanged('yearly'),
          ),
        ),
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PlanTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? kCobalt.withValues(alpha: 0.08)
                : context.artC.cardIconBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? kCobalt.withValues(alpha: 0.38)
                  : context.artC.silver.withValues(alpha: 0.24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? kCobalt
                    : context.artC.ink.withValues(alpha: 0.34),
                size: 18,
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? kCobalt : context.artC.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.48),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorPanel({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: context.artC.ink.withValues(alpha: 0.32),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.58),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration(BuildContext context) {
  return BoxDecoration(
    color: context.artC.cardIconBg,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: context.artC.silver.withValues(alpha: 0.24)),
  );
}

String _dateText(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw.length > 10 ? raw.substring(0, 10) : raw;
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
}

String _checkoutOrderId(Map<String, dynamic> checkout) {
  final direct = checkout['orderId']?.toString().trim() ?? '';
  if (direct.isNotEmpty) return direct;
  final order = checkout['order'];
  if (order is Map) return order['id']?.toString().trim() ?? '';
  return '';
}
