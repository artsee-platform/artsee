import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class CommunityPostDetailScreen extends StatefulWidget {
  final String postId;
  final AppCommunityPost? initialPost;

  const CommunityPostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  State<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  AppCommunityPost? _post;
  List<AppCommunityComment> _comments = const [];
  bool _loading = true;
  bool _commentsLoading = true;
  bool _likeBusy = false;
  bool _sendingComment = false;
  bool _liked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _loading = widget.initialPost == null;
    _liked = widget.initialPost?.likedByMe ?? false;
    _likeCount = widget.initialPost?.likeCount ?? 0;
    _commentCount = widget.initialPost?.commentCount ?? 0;
    _load(silent: widget.initialPost != null);
    _loadComments();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final post = await BackendApiService.fetchCommunityPost(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        if (post != null) {
          _liked = post.likedByMe;
          _likeCount = post.likeCount;
          _commentCount = post.commentCount;
        }
        _loading = false;
        _error = post == null ? '内容不存在或已下架' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadComments() async {
    if (mounted) {
      setState(() {
        _commentsLoading = true;
      });
    }
    try {
      final comments =
          await BackendApiService.fetchCommunityComments(widget.postId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _commentsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _commentsLoading = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _load(silent: true),
      _loadComments(),
    ]);
  }

  Future<void> _toggleLike() async {
    if (_likeBusy || _post == null) return;
    setState(() => _likeBusy = true);
    try {
      final result = _liked
          ? await BackendApiService.unlikeCommunityPost(widget.postId)
          : await BackendApiService.likeCommunityPost(widget.postId);
      if (!mounted) return;
      setState(() {
        _liked = result.liked;
        _likeCount = result.likeCount;
        _likeBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _likeBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    try {
      final comment = await BackendApiService.createCommunityComment(
        postId: widget.postId,
        body: text,
      );
      if (!mounted) return;
      _commentCtrl.clear();
      setState(() {
        _comments = [..._comments, comment];
        _commentCount += 1;
        _sendingComment = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('评论失败：$e')),
      );
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: context.artC.porcelain,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.artC.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '社区详情',
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: _loading && post == null
            ? const LoadingIndicator()
            : post == null
                ? _ErrorView(
                    message: _error ?? '内容不存在或已下架',
                    onRetry: () => _load(),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          color: kCobalt,
                          onRefresh: _refreshAll,
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                  child: _ImageGallery(post: post)),
                              SliverToBoxAdapter(
                                child: _PostBody(
                                  post: post,
                                  liked: _liked,
                                  likeCount: _likeCount,
                                  commentCount: _commentCount,
                                  likeBusy: _likeBusy,
                                  onLike: _toggleLike,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: _CommentsSection(
                                  comments: _comments,
                                  loading: _commentsLoading,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                    height: mainTabBottomInset(context)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _CommentComposer(
                        controller: _commentCtrl,
                        sending: _sendingComment,
                        onSend: _sendComment,
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _ImageGallery extends StatefulWidget {
  final AppCommunityPost post;

  const _ImageGallery({required this.post});

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.post.imageUrls;
    if (images.isEmpty) {
      return Container(
        height: 220,
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        decoration: BoxDecoration(
          color: context.artC.silver.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(kRadiusLarge),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.55)),
        ),
        child: Center(
          child: Icon(
            Icons.article_outlined,
            size: 42,
            color: context.artC.ink.withValues(alpha: 0.22),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadiusLarge),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Image.network(
                  images[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: context.artC.silver.withValues(alpha: 0.3),
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: context.artC.ink.withValues(alpha: 0.24),
                    ),
                  ),
                ),
              ),
              if (images.length > 1)
                Positioned(
                  right: 14,
                  top: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.artC.ink.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_page + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostBody extends StatelessWidget {
  final AppCommunityPost post;
  final bool liked;
  final bool likeBusy;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;

  const _PostBody({
    required this.post,
    required this.liked,
    required this.likeBusy,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final body = post.body?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(post: post, radius: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorNickname ?? 'Artsee 用户',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.artC.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeAgo(post.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.artC.ink.withValues(alpha: 0.38),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            post.title.isNotEmpty ? post.title : '作品分享',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.22,
              color: context.artC.ink,
              fontFamily: 'Noto Serif SC',
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              body,
              style: TextStyle(
                fontSize: 15,
                height: 1.75,
                color: context.artC.ink.withValues(alpha: 0.78),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              GestureDetector(
                onTap: likeBusy ? null : onLike,
                child: _Metric(
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  value: likeCount,
                  active: liked,
                ),
              ),
              const SizedBox(width: 12),
              _Metric(icon: Icons.chat_bubble_outline, value: commentCount),
              const SizedBox(width: 12),
              _Metric(icon: Icons.visibility_outlined, value: post.viewCount),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final AppCommunityPost post;
  final double radius;

  const _Avatar({required this.post, required this.radius});

  @override
  Widget build(BuildContext context) {
    final avatar = post.authorAvatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: kCobalt.withValues(alpha: 0.09),
      child: ClipOval(
        child: avatar != null && avatar.isNotEmpty
            ? Image.network(
                avatar,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Initial(post: post),
              )
            : _Initial(post: post),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  final AppCommunityPost post;

  const _Initial({required this.post});

  @override
  Widget build(BuildContext context) {
    final nick = post.authorNickname ?? 'A';
    return Center(
      child: Text(
        nick.characters.first.toUpperCase(),
        style: const TextStyle(
          color: kCobalt,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final int value;
  final bool active;

  const _Metric({
    required this.icon,
    required this.value,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: active ? kCobalt : context.artC.ink.withValues(alpha: 0.42),
          ),
          const SizedBox(width: 5),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color:
                  active ? kCobalt : context.artC.ink.withValues(alpha: 0.58),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  final List<AppCommunityComment> comments;
  final bool loading;

  const _CommentsSection({
    required this.comments,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '评论',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 14),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kCobalt,
                  ),
                ),
              ),
            )
          else if (comments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kRadiusMedium),
                border: Border.all(
                    color: context.artC.silver.withValues(alpha: 0.5)),
              ),
              child: Text(
                '还没有评论，来写下第一句反馈。',
                style: TextStyle(
                  fontSize: 13,
                  color: context.artC.ink.withValues(alpha: 0.42),
                ),
              ),
            )
          else
            ...comments.map((comment) => _CommentTile(comment: comment)),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final AppCommunityComment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final name = comment.authorNickname ?? 'Artsee 用户';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusMedium),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: kCobalt.withValues(alpha: 0.08),
            child: ClipOval(
              child: comment.authorAvatarUrl != null &&
                      comment.authorAvatarUrl!.isNotEmpty
                  ? Image.network(
                      comment.authorAvatarUrl!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _CommentInitial(name: name),
                    )
                  : _CommentInitial(name: name),
            ),
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
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: context.artC.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo(comment.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: context.artC.ink.withValues(alpha: 0.32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: context.artC.ink.withValues(alpha: 0.74),
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

class _CommentInitial extends StatelessWidget {
  final String name;

  const _CommentInitial({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : 'A',
        style: const TextStyle(
          color: kCobalt,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _CommentComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.artC.porcelain,
        border: Border(
          top: BorderSide(color: context.artC.silver.withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: context.artC.silver.withValues(alpha: 0.55)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: '写评论...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: context.artC.ink.withValues(alpha: 0.35),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.artC.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: sending ? null : onSend,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: kCobalt,
                  shape: BoxShape.circle,
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward,
                        color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: context.artC.ink.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.58),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            CobaltButton(label: '重试', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}
