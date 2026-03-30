import 'package:flutter/material.dart';

const kPrimary = Color(0xFFFF6A00);
const kPrimaryLight = Color(0xFFFF9A3C);

// ── Gradient utility ──────────────────────────────────────────
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
  final colors = map[school] ?? [const Color(0xFF64748B), const Color(0xFF94A3B8)];
  return LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight);
}

LinearGradient resultGradient(String result) {
  if (result == 'admitted') {
    return const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF4ADE80)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  } else if (result == 'waitlisted') {
    return const LinearGradient(colors: [Color(0xFFCA8A04), Color(0xFFFBBF24)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  }
  return const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFF87171)], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

String resultLabel(String result) {
  if (result == 'admitted') return '🎉 录取';
  if (result == 'waitlisted') return '⏳ 等候';
  return '❌ 拒绝';
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

// ── Reusable Widgets ─────────────────────────────────────────

class TagChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const TagChip({super.key, required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? kPrimary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
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

  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: const TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w500)),
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
    return const Center(child: CircularProgressIndicator(color: kPrimary));
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
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}

class GradientBanner extends StatelessWidget {
  final LinearGradient gradient;
  final Widget child;
  final double height;

  const GradientBanner({super.key, required this.gradient, required this.child, this.height = 120});

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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
