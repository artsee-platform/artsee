import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// 青花瓷典藏版配色方案 (Artiqore 艺衡风格)
// ═══════════════════════════════════════════════════════════════

/// 瓷器白 - 主背景色
const kPorcelain = Color(0xFFF8F9FA);

/// 钴蓝 - 主品牌色
const kCobalt = Color(0xFF003399);

/// 柔和钴蓝 - 辅助色
const kCobaltMuted = Color(0xFF4A6FA5);

/// 墨黑 - 主要文字
const kInk = Color(0xFF1A1A1A);

/// 银灰 - 次要背景/边框
const kSilver = Color(0xFFE9ECEF);

/// 深墨 - 导航背景
const kInkDark = Color(0xFF2D2D2D);

// 保留旧常量名以便兼容，但指向新颜色
const kPrimary = kCobalt;
const kPrimaryLight = kCobaltMuted;

// ═══════════════════════════════════════════════════════════════
// 样式常量
// ═══════════════════════════════════════════════════════════════

/// 大圆角 - 卡片
const double kRadiusLarge = 24.0;

/// 中圆角 - 按钮
const double kRadiusMedium = 16.0;

/// 小圆角 - 标签
const double kRadiusSmall = 12.0;

/// 与 `MainScaffold` 底部悬浮导航 + FAB 占用高度一致（勿与实现脱节）
const double kMainTabOverlayHeight = 118.0;

/// 主 Tab 页内容区底部留白，避免被悬浮栏遮挡
double mainTabBottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + kMainTabOverlayHeight;

/// 主阴影
final kShadowMain = BoxShadow(
  color: kInk.withValues(alpha: 0.06),
  blurRadius: 20,
  offset: const Offset(0, 4),
);

/// 卡片阴影
final kShadowCard = BoxShadow(
  color: kInk.withValues(alpha: 0.04),
  blurRadius: 12,
  offset: const Offset(0, 2),
);

/// 悬浮阴影
final kShadowElevated = BoxShadow(
  color: kCobalt.withValues(alpha: 0.15),
  blurRadius: 24,
  offset: const Offset(0, 8),
);

// ═══════════════════════════════════════════════════════════════
// 字体样式
// ═══════════════════════════════════════════════════════════════

/// 衬线体标题
const kSerifTitle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: kInk,
  height: 1.3,
  letterSpacing: 0.5,
);

/// 衬线体大标题
const kSerifHeadline = TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.w700,
  color: kInk,
  height: 1.2,
  letterSpacing: 0.5,
);

/// 标签文字
const kLabelStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.5,
);

/// 正文文字
const kBodyStyle = TextStyle(
  fontSize: 13,
  color: kInk,
  height: 1.5,
);

/// 次要文字
final kCaptionStyle = TextStyle(
  fontSize: 11,
  color: kInk.withValues(alpha: 0.5),
);

// ═══════════════════════════════════════════════════════════════
// Gradient utility
// ═══════════════════════════════════════════════════════════════

LinearGradient schoolGradient(String? school) {
  final Map<String, List<Color>> map = {
    '牛津大学': [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
    '剑桥大学': [const Color(0xFF0369A1), const Color(0xFF38BDF8)],
    '帝国理工+RCA': [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)],
    'UCL': [const Color(0xFF047857), const Color(0xFF10B981)],
    '伦敦大学学院': [const Color(0xFF047857), const Color(0xFF10B981)],
    '爱丁堡大学': [const Color(0xFFBE185D), const Color(0xFFF43F5E)],
    '中央圣马丁': [const Color(0xFFEA580C), const Color(0xFFF97316)],
    '坎伯韦尔艺术学院': [const Color(0xFF7C3AED), const Color(0xFFA855F7)],
    '皇家艺术学院': [const Color(0xFFDC2626), const Color(0xFFF87171)],
  };
  final colors = map[school] ?? [kCobalt, kCobaltMuted];
  return LinearGradient(
      colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight);
}

LinearGradient resultGradient(String result) {
  if (result == 'admitted') {
    return const LinearGradient(
        colors: [Color(0xFF16A34A), Color(0xFF4ADE80)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight);
  } else if (result == 'waitlisted') {
    return const LinearGradient(
        colors: [Color(0xFFCA8A04), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight);
  }
  return const LinearGradient(
      colors: [Color(0xFFDC2626), Color(0xFFF87171)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
}

String resultLabel(String result) {
  if (result == 'admitted') return '录取';
  if (result == 'waitlisted') return '等候';
  return '拒绝';
}

Color resultBadgeColor(String result) {
  if (result == 'admitted') return const Color(0xFF16A34A);
  if (result == 'waitlisted') return const Color(0xFFCA8A04);
  return const Color(0xFFDC2626);
}

String timeAgo(String dateStr) {
  final dt = DateTime.tryParse(dateStr);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 30) return '${diff.inDays}天前';
  return '${dt.month}月${dt.day}日';
}

// ═══════════════════════════════════════════════════════════════
// Reusable Widgets
// ═══════════════════════════════════════════════════════════════

class TagChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const TagChip(
      {super.key, required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? kCobalt : kSilver.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(kRadiusSmall),
          border: active ? null : Border.all(color: kSilver, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? Colors.white : kInk.withValues(alpha: 0.6),
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader(
      {super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: kSerifTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 2),
              Container(
                  width: 24, height: 2, color: kCobalt.withValues(alpha: 0.3)),
            ],
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kCobalt.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(kRadiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(action!,
                        style: const TextStyle(
                            fontSize: 11,
                            color: kCobalt,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios,
                        size: 10, color: kCobalt.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: kCobalt,
        strokeWidth: 2.5,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String emoji;
  final String message;

  const EmptyState({super.key, required this.emoji, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kSilver.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: kInk.withValues(alpha: 0.5),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class GradientBanner extends StatelessWidget {
  final LinearGradient gradient;
  final Widget child;
  final double height;

  const GradientBanner(
      {super.key,
      required this.gradient,
      required this.child,
      this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(gradient: gradient),
      child: child,
    );
  }
}

class InfoCard extends StatelessWidget {
  final String label;
  final String value;

  const InfoCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRadiusMedium),
          boxShadow: [kShadowCard],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: kCobalt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  color: kInk.withValues(alpha: 0.4),
                  letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 青花瓷风格卡片组件
// ═══════════════════════════════════════════════════════════════

class PorcelainCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  const PorcelainCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRadiusLarge),
          boxShadow: [kShadowCard],
          border: Border.all(color: kSilver.withValues(alpha: 0.5), width: 1),
        ),
        child: child,
      ),
    );
  }
}

/// 钴蓝按钮
class CobaltButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isOutlined;
  final IconData? icon;

  const CobaltButton({
    super.key,
    required this.label,
    this.onTap,
    this.isOutlined = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : kCobalt,
          borderRadius: BorderRadius.circular(kRadiusMedium),
          border: isOutlined ? Border.all(color: kCobalt, width: 1.5) : null,
          boxShadow: isOutlined ? null : [kShadowElevated],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isOutlined ? kCobalt : Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isOutlined ? kCobalt : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 浮动操作按钮（青花瓷风格）
class FloatingCobaltButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;

  const FloatingCobaltButton({
    super.key,
    this.onTap,
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: kCobalt,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kCobalt.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
