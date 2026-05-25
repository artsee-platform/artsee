import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'chat_detail_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

final ValueNotifier<String> messagesSearchQueryNotifier = ValueNotifier('');

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const _items = <_MessageEntry>[
    _MessageEntry(
      Icons.auto_awesome_rounded,
      'Artiqore AI',
      '我整理了你刚才问的选校方向，RCA、UAL 和 Pratt 可以先分成三档看。',
    ),
    _MessageEntry(
      Icons.person_rounded,
      '导师王教授',
      '作品集第二个项目的逻辑已经顺了，下一版重点看图文节奏。',
    ),
    _MessageEntry(
      Icons.event_note_rounded,
      '申请提醒',
      'RCA 作品集提交截止还有 3 天，推荐信和个人陈述还差最后确认。',
    ),
    _MessageEntry(
      Icons.favorite_rounded,
      '互动与提醒',
      'Mia 评论了你的案例；另有 2 位同学收藏了你的作品集笔记。',
    ),
    _MessageEntry(
      Icons.campaign_rounded,
      '平台通知',
      '新增作品集分析功能，上传项目后可以获得结构、叙事和呈现建议。',
    ),
    _MessageEntry(
      Icons.chat_bubble_rounded,
      'Nora Studio',
      '周末的 group critique 还有一个名额，你要不要把视觉实验项目带过来？',
    ),
  ];

  final Set<String> _readChats = {};

  List<_MessageEntry> _visibleItems(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items.where((item) {
      final text = [
        item.title,
        item.subtitle,
        _messageType(item),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<String>(
          valueListenable: messagesSearchQueryNotifier,
          builder: (context, query, _) {
            final items = _visibleItems(query);
            return ListView(
              padding:
                  EdgeInsets.fromLTRB(20, 8, 20, mainTabBottomInset(context)),
              children: [
                if (items.isEmpty)
                  _MessageEmptyState(
                    onReset: () => messagesSearchQueryNotifier.value = '',
                  )
                else
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MessageTile(
                        item: item,
                        isRead: _readChats.contains(item.title),
                        onRead: () {
                          setState(() {
                            _readChats.add(item.title);
                          });
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final _MessageEntry item;
  final bool isRead;
  final VoidCallback onRead;

  const _MessageTile({
    required this.item,
    required this.isRead,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _messageAccent(item);
    final unreadCount = isRead ? 0 : _messageUnreadCount(item);
    return GestureDetector(
      onTap: () {
        onRead();
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ChatDetailScreen(
              chatId: item.title.toLowerCase().replaceAll(' ', '_'),
              chatName: item.title,
              avatarIcon: item.icon,
              avatarColor: _messageAccent(item),
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: accent, size: 23),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF315A),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: context.artC.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _messageTime(item),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.artC.ink.withValues(alpha: 0.34),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: context.artC.ink.withValues(alpha: 0.48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageEmptyState extends StatelessWidget {
  final VoidCallback onReset;

  const _MessageEmptyState({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 42,
            color: context.artC.ink.withValues(alpha: 0.22),
          ),
          const SizedBox(height: 12),
          Text(
            '没有找到相关消息',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 14),
          CobaltButton(label: '清空搜索', onTap: onReset),
        ],
      ),
    );
  }
}

class _MessageEntry {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MessageEntry(this.icon, this.title, this.subtitle);
}

String _messageTime(_MessageEntry item) {
  return switch (item.title) {
    'Artiqore AI' => '12:50',
    '导师王教授' => '11:15',
    '申请提醒' => '昨天',
    '互动与提醒' => '昨天',
    '平台通知' => '05-22',
    _ => '05-21',
  };
}

String _messageType(_MessageEntry item) {
  return switch (item.title) {
    'Artiqore AI' => 'AI',
    '导师王教授' || 'Nora Studio' => '私信',
    '申请提醒' => '申请',
    '互动与提醒' => '互动',
    _ => '通知',
  };
}

int _messageUnreadCount(_MessageEntry item) {
  return switch (item.title) {
    'Artiqore AI' => 2,
    '导师王教授' => 1,
    '互动与提醒' => 3,
    _ => 0,
  };
}

Color _messageAccent(_MessageEntry item) {
  return switch (item.title) {
    'Artiqore AI' => const Color(0xFF0A46B7),
    '申请提醒' => const Color(0xFF21A66B),
    '互动与提醒' => const Color(0xFFFF3B6B),
    '平台通知' => const Color(0xFF7B61FF),
    _ => const Color(0xFF222222),
  };
}
