import 'package:flutter/material.dart';
import '../../widgets/artsee_ui.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// 第一层：申请状态总览
class ApplicationStatusOverview extends StatelessWidget {
  final int percentage;
  final int targetSchoolCount;
  final int materialCount;
  final int completedMaterialCount;
  final bool hasTargetSchools;
  final VoidCallback? onPrimaryAction;

  const ApplicationStatusOverview({
    super.key,
    required this.percentage,
    required this.targetSchoolCount,
    required this.materialCount,
    required this.completedMaterialCount,
    required this.hasTargetSchools,
    this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final primaryAction = targetSchoolCount == 0
        ? '先添加目标院校'
        : targetSchoolCount == 1
            ? '继续添加院校'
            : '生成申请计划';
    final statusHint = targetSchoolCount == 0
        ? '当前建议：先添加 2-5 所目标院校'
        : targetSchoolCount == 1
            ? '当前建议：再添加 1-4 所院校，方便对比冲刺 / 匹配 / 保底'
            : '当前状态：可以生成申请时间线和材料清单';

    return ArtseeSurface(
      padding: const EdgeInsets.all(16),
      radius: 18,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '2026 Fall 申请工作台',
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: percentage == 0
                      ? context.artC.silver.withOpacity(0.2)
                      : kCobalt.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '准备度 $percentage%',
                  style: TextStyle(
                    color: percentage == 0
                        ? context.artC.ink.withOpacity(0.5)
                        : kCobalt,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatusItem(
                label: '目标院校',
                value: '$targetSchoolCount 所',
                isEmpty: targetSchoolCount == 0,
              ),
              const SizedBox(width: 20),
              _StatusItem(
                label: '材料',
                value: '$completedMaterialCount/$materialCount 项',
                isEmpty: materialCount == 0,
              ),
              const SizedBox(width: 20),
              _StatusItem(
                label: 'DDL',
                value: '待生成',
                isEmpty: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            statusHint,
            style: TextStyle(
              color: kCobalt,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (!hasTargetSchools) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: kCobalt,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '先添加 2-5 所目标院校，系统会帮你生成时间线、材料清单和作品集任务。',
                      style: TextStyle(
                        color: kCobalt,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: onPrimaryAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCobalt,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  primaryAction,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isEmpty;

  const _StatusItem({
    required this.label,
    required this.value,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.artC.ink.withOpacity(0.45),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isEmpty
                  ? context.artC.ink.withOpacity(0.3)
                  : context.artC.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// 第二层：下一步任务
class NextStepTasks extends StatelessWidget {
  final bool hasTargetSchools;

  const NextStepTasks({
    super.key,
    required this.hasTargetSchools,
  });

  @override
  Widget build(BuildContext context) {
    final tasks = [
      (title: '添加目标院校', subtitle: '建议 2-5 所', done: false),
      (title: '选择申请专业方向', subtitle: '确认学位类型', done: false),
      (title: '建立作品集项目', subtitle: '规划项目数量', done: false),
    ];

    return ArtseeSurface(
      padding: const EdgeInsets.all(18),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '下一步建议',
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...tasks.asMap().entries.map((entry) {
            final index = entry.key;
            final task = entry.value;
            return Padding(
              padding:
                  EdgeInsets.only(bottom: index < tasks.length - 1 ? 12 : 0),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: task.done ? kCobalt : context.artC.silver,
                        width: 2,
                      ),
                      color: task.done ? kCobalt : Colors.transparent,
                    ),
                    child: task.done
                        ? const Icon(Icons.check, color: Colors.white, size: 12)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: context.artC.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          task.subtitle,
                          style: TextStyle(
                            color: context.artC.ink.withOpacity(0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.artC.silver.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '未开始',
                      style: TextStyle(
                        color: context.artC.ink.withOpacity(0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
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

/// 第三层：核心工具网格
class CoreToolsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> tools;
  final int materialCount;
  final int completedMaterialCount;
  final bool hasTargetSchools;

  const CoreToolsGrid({
    super.key,
    required this.tools,
    required this.materialCount,
    required this.completedMaterialCount,
    required this.hasTargetSchools,
  });

  @override
  Widget build(BuildContext context) {
    // 固定的核心工具（优先级高于后端返回的工具）
    final coreTools = [
      (
        title: '申请时间线',
        status: hasTargetSchools ? '已生成' : '未生成',
        icon: Icons.timeline_outlined,
        color: const Color(0xFF2563EB),
        isEmpty: !hasTargetSchools,
      ),
      (
        title: '材料清单',
        status: materialCount > 0
            ? '$completedMaterialCount/$materialCount'
            : '0/0',
        icon: Icons.checklist_rtl,
        color: const Color(0xFF059669),
        isEmpty: materialCount == 0,
      ),
      (
        title: '作品集进度',
        status: '未创建',
        icon: Icons.dashboard_customize_outlined,
        color: const Color(0xFF7C3AED),
        isEmpty: true,
      ),
      (
        title: '咨询记录',
        status: '待跟进',
        icon: Icons.support_agent_outlined,
        color: const Color(0xFFEA580C),
        isEmpty: false,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: coreTools.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.48,
      ),
      itemBuilder: (context, index) {
        final tool = coreTools[index];
        return _CompactToolCard(
          title: tool.title,
          status: tool.status,
          icon: tool.icon,
          color: tool.color,
          isEmpty: tool.isEmpty,
        );
      },
    );
  }
}

class _CompactToolCard extends StatelessWidget {
  final String title;
  final String status;
  final IconData icon;
  final Color color;
  final bool isEmpty;

  const _CompactToolCard({
    required this.title,
    required this.status,
    required this.icon,
    required this.color,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      padding: const EdgeInsets.all(11),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isEmpty
                      ? context.artC.silver.withOpacity(0.2)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isEmpty ? context.artC.ink.withOpacity(0.4) : color,
                    fontSize: 9,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 13,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isEmpty ? '建议先添加目标院校' : '点击查看详情',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink.withOpacity(0.35),
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 第四层：申请资源
class ApplicationResources extends StatelessWidget {
  const ApplicationResources({super.key});

  @override
  Widget build(BuildContext context) {
    final resources = [
      (title: '语言考试备考', icon: Icons.translate),
      (title: '面试经验', icon: Icons.video_call_outlined),
      (title: '成功案例', icon: Icons.emoji_events_outlined),
      (title: '推荐信指南', icon: Icons.mail_outline),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: resources.map((resource) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: context.artC.silver.withOpacity(0.38)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                resource.icon,
                color: kCobalt,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                resource.title,
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
