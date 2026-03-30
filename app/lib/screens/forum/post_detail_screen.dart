import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  AppPost? _post;
  List<AppReply> _replies = [];
  bool _loading = true;
  final _replyCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SupabaseService.fetchPost(widget.postId),
      SupabaseService.fetchReplies(widget.postId),
    ]);
    if (mounted) setState(() {
      _post = results[0] as AppPost?;
      _replies = results[1] as List<AppReply>;
      _loading = false;
    });
  }

  Future<void> _submitReply() async {
    if (_replyCtrl.text.trim().isEmpty) return;
    if (!SupabaseService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录后再回复')));
      return;
    }
    setState(() => _submitting = true);
    await SupabaseService.createReply(widget.postId, _replyCtrl.text.trim());
    _replyCtrl.clear();
    await _load();
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingIndicator());
    if (_post == null) return const Scaffold(body: EmptyState(emoji: '❌', message: '找不到该帖子'));

    final p = _post!;
    final typeColors = {'question': const Color(0xFF3B82F6), 'discussion': const Color(0xFFA855F7), 'news': const Color(0xFF10B981)};
    final color = typeColors[p.type] ?? const Color(0xFFA855F7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 140,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(p.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.3), maxLines: 3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Author info
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)]),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 18, backgroundColor: kPrimary,
                          child: Text(p.authorNickname?.substring(0, 1) ?? '?', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.authorNickname ?? '用户', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(timeAgo(p.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          ],
                        )),
                        Icon(Icons.visibility_outlined, size: 13, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Text('${p.viewCount}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        const SizedBox(width: 10),
                        Icon(Icons.thumb_up_outlined, size: 13, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Text('${p.likeCount}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ),

                // Post content
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Text(p.content ?? '暂无内容', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.7)),
                  ),
                ),

                // Replies header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text('${_replies.length} 条回复', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                  ),
                ),

                // Replies
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final r = _replies[i];
                      return Container(
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              CircleAvatar(radius: 12, backgroundColor: Colors.grey.shade400,
                                child: Text(r.authorNickname?.substring(0, 1) ?? '?', style: const TextStyle(color: Colors.white, fontSize: 10))),
                              const SizedBox(width: 8),
                              Text(r.authorNickname ?? '用户', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text(timeAgo(r.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            ]),
                            const SizedBox(height: 6),
                            Text(r.content, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.5)),
                          ],
                        ),
                      );
                    },
                    childCount: _replies.length,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),

          // Reply input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    decoration: InputDecoration(
                      hintText: '写下你的回答...',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _submitting ? null : _submitReply,
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(12)),
                    child: _submitting
                      ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.white, size: 18),
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
