import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import 'post_detail_screen.dart';
import 'new_post_screen.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AppPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() { if (!_tabController.indexIsChanging) _loadForTab(); });
    _load('question');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadForTab() async {
    final types = ['question', 'discussion', 'news'];
    await _load(types[_tabController.index]);
  }

  Future<void> _load(String type) async {
    setState(() => _loading = true);
    final data = await SupabaseService.fetchPosts(type: type);
    if (mounted) setState(() { _posts = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('论坛', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.edit, color: Colors.white, size: 16),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewPostScreen())).then((_) => _loadForTab()),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: kPrimary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: '问答'), Tab(text: '讨论'), Tab(text: '资讯')],
        ),
      ),
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: _loadForTab,
        child: _loading
          ? const LoadingIndicator()
          : _posts.isEmpty
            ? const EmptyState(emoji: '💬', message: '还没有内容，来发第一帖！')
            : ListView.builder(
                itemCount: _posts.length,
                itemBuilder: (ctx, i) => _PostCard(
                  post: _posts[i],
                  onTap: () => Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => PostDetailScreen(postId: _posts[i].id),
                  )),
                ),
              ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final AppPost post;
  final VoidCallback onTap;

  const _PostCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final typeStyle = {
      'question': (label: '问答', color: const Color(0xFF3B82F6)),
      'discussion': (label: '讨论', color: const Color(0xFFA855F7)),
      'news': (label: '资讯', color: const Color(0xFF10B981)),
    };
    final ts = typeStyle[post.type] ?? typeStyle['discussion']!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFFF6A00),
                  child: Text(post.authorNickname?.substring(0, 1) ?? '?', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Text(post.authorNickname ?? '用户', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                if (post.isMentorPost) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified, size: 13, color: kPrimary),
                ],
                const Spacer(),
                Text(timeAgo(post.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: ts.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text(ts.label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ts.color)),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(post.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis)),
              ],
            ),
            if (post.content != null) ...[
              const SizedBox(height: 4),
              Text(post.content!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 4, children: post.tags.take(3).map((t) =>
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                  child: Text('#$t', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)))
              ).toList()),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.thumb_up_outlined, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text('${post.likeCount}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                const SizedBox(width: 12),
                Icon(Icons.chat_bubble_outline, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text('${post.answerCount} 回答', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                const SizedBox(width: 12),
                Icon(Icons.visibility_outlined, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text('${post.viewCount}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
