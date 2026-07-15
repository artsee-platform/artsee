import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/artsee_ui.dart';
import '../../widgets/common.dart';
import '../profile/public_user_profile_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class CommunityPostDetailScreen extends StatefulWidget {
  final String postId;
  final AppCommunityPost? initialPost;
  final bool focusAnswer;

  const CommunityPostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
    this.focusAnswer = false,
  });

  @override
  State<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final GlobalKey _commentComposerKey = GlobalKey();
  AppCommunityPost? _post;
  List<AppCommunityComment> _comments = const [];
  bool _loading = true;
  bool _commentsLoading = true;
  bool _likeBusy = false;
  bool _saveBusy = false;
  bool _sendingComment = false;
  bool _liked = false;
  bool _saved = false;
  int _likeCount = 0;
  int _saveCount = 0;
  int _commentCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _loading = widget.initialPost == null;
    _liked = widget.initialPost?.likedByMe ?? false;
    _saved = widget.initialPost?.savedByMe ?? false;
    _likeCount = widget.initialPost?.likeCount ?? 0;
    _saveCount = widget.initialPost?.saveCount ?? 0;
    _commentCount = widget.initialPost?.commentCount ?? 0;
    _load(silent: widget.initialPost != null);
    _loadComments();
    if (widget.focusAnswer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _commentFocusNode.requestFocus();
      });
    }
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
          _saved = post.savedByMe;
          _likeCount = post.likeCount;
          _saveCount = post.saveCount;
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

  Future<void> _toggleSave() async {
    if (_saveBusy || _post == null) return;
    setState(() => _saveBusy = true);
    try {
      final result = _saved
          ? await BackendApiService.unsaveCommunityPost(widget.postId)
          : await BackendApiService.saveCommunityPost(widget.postId);
      if (!mounted) return;
      setState(() {
        _saved = result.saved;
        _saveCount = result.saveCount;
        _saveBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.saved ? '已收藏' : '已取消收藏')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('收藏失败：$e')),
      );
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    try {
      final AppCommunityComment comment;
      final AppCommunityComment? aiReply;
      if (_isPlazaPost) {
        final result = await BackendApiService.createPlazaComment(
          postId: widget.postId,
          body: text,
        );
        comment = result.comment;
        aiReply = result.aiReply;
      } else {
        comment = await BackendApiService.createCommunityComment(
          postId: widget.postId,
          body: text,
        );
        aiReply = null;
      }
      if (!mounted) return;
      _commentCtrl.clear();
      setState(() {
        _comments = [comment, if (aiReply != null) aiReply, ..._comments];
        _commentCount += aiReply == null ? 1 : 2;
        _sendingComment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              aiReply == null ? (_isQa ? '回答已发布' : '评论已发布') : '评论已发布，AI 已接上'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_isQa ? '回答' : '评论'}失败：$e')),
      );
    }
  }

  bool get _isQa => _post?.metadata['kind'] == 'qa';

  bool get _isPlazaPost {
    final metadata = _post?.metadata ?? widget.initialPost?.metadata ?? {};
    final surface = metadata['surface']?.toString().trim().toLowerCase();
    final source = metadata['source']?.toString().trim().toLowerCase() ?? '';
    return surface == 'plaza' || source.startsWith('plaza_');
  }

  void _openPostAuthorProfile(AppCommunityPost post) {
    final anonymous = _isQa && post.metadata['anonymous'] == true;
    if (anonymous) return;
    final name = post.authorNickname?.trim().isNotEmpty == true
        ? post.authorNickname!.trim()
        : 'Artsee 用户';
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserProfileScreen(
          userId: post.authorId,
          name: name,
          handle: _publicHandleFromName(name),
          avatarUrl: post.authorAvatarUrl,
          roleLabel: _isQa ? '社区提问者' : '社区创作者',
          kind: PublicUserProfileKind.user,
          featuredActivity: post.title,
        ),
      ),
    );
  }

  void _openCommentAuthorProfile(AppCommunityComment comment) {
    final name = comment.authorNickname?.trim().isNotEmpty == true
        ? comment.authorNickname!.trim()
        : 'Artsee 用户';
    final certifiedAnswer = _isQa && comment.likeCount > 0;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserProfileScreen(
          userId: comment.authorId,
          name: name,
          handle: _publicHandleFromName(name),
          avatarUrl: comment.authorAvatarUrl,
          roleLabel: certifiedAnswer ? '认证回答者' : '社区用户',
          kind: certifiedAnswer
              ? PublicUserProfileKind.mentor
              : PublicUserProfileKind.user,
          featuredAnswerContext: _isQa ? '来自问答区的回答' : '来自评论区的观点',
          featuredAnswer: comment.body,
        ),
      ),
    );
  }

  void _focusCommentComposer() {
    final composerContext = _commentComposerKey.currentContext;
    if (composerContext != null) {
      Scrollable.ensureVisible(
        composerContext,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
    }
    _commentFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: context.artC.cardIconBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.artC.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: post == null
            ? Text(
                _isQa ? '问题详情' : '动态详情',
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              )
            : _DetailAuthorTitle(
                post: post,
                isQa: _isQa,
                onTap: () => _openPostAuthorProfile(post),
              ),
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share, color: context.artC.ink, size: 23),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('分享功能即将开放')),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
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
                              if (!_isQa)
                                SliverToBoxAdapter(
                                  child: _ImageGallery(
                                    post: post,
                                    edgeToEdge: true,
                                  ),
                                ),
                              SliverToBoxAdapter(
                                child: _PostBody(
                                  post: post,
                                  isQa: _isQa,
                                ),
                              ),
                              if (_isQa && post.imageUrls.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: _ImageGallery(post: post),
                                ),
                              SliverToBoxAdapter(
                                child: _CommentsSection(
                                  comments: _comments,
                                  loading: _commentsLoading,
                                  isQa: _isQa,
                                  commentCount: _commentCount,
                                  engagementCount: _likeCount + _saveCount,
                                  composer: KeyedSubtree(
                                    key: _commentComposerKey,
                                    child: _CommentComposer(
                                      controller: _commentCtrl,
                                      focusNode: _commentFocusNode,
                                      sending: _sendingComment,
                                      isQa: _isQa,
                                      onSend: _sendComment,
                                    ),
                                  ),
                                  onAuthorTap: _openCommentAuthorProfile,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 18 + mainTabBottomInset(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _DetailBottomActions(
                        isQa: _isQa,
                        liked: _liked,
                        saved: _saved,
                        likeBusy: _likeBusy,
                        saveBusy: _saveBusy,
                        likeCount: _likeCount,
                        saveCount: _saveCount,
                        commentCount: _commentCount,
                        onLike: _toggleLike,
                        onSave: _toggleSave,
                        onComment: _focusCommentComposer,
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _ImageGallery extends StatefulWidget {
  final AppCommunityPost post;
  final bool edgeToEdge;

  const _ImageGallery({
    required this.post,
    this.edgeToEdge = false,
  });

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.post.imageUrls;
    if (images.isEmpty) {
      final encoded = Uri.encodeComponent(widget.post.id);
      final image = Image.network(
        'https://picsum.photos/seed/artsee_detail_$encoded/900/900',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _DetailImageFallback(post: widget.post),
      );
      return widget.edgeToEdge
          ? AspectRatio(aspectRatio: 1, child: image)
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kRadiusLarge),
                child: AspectRatio(aspectRatio: 1, child: image),
              ),
            );
    }

    final gallery = AspectRatio(
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
              errorBuilder: (_, __, ___) => _DetailImageFallback(
                post: widget.post,
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
                  color: Colors.black.withValues(alpha: 0.58),
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
    );

    if (widget.edgeToEdge) return gallery;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadiusLarge),
        child: gallery,
      ),
    );
  }
}

class _DetailAuthorTitle extends StatelessWidget {
  final AppCommunityPost post;
  final bool isQa;
  final VoidCallback onTap;

  const _DetailAuthorTitle({
    required this.post,
    required this.isQa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final anonymous = isQa && post.metadata['anonymous'] == true;
    final name = anonymous ? '匿名用户' : post.authorNickname ?? 'Artsee 用户';
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: anonymous ? null : onTap,
      child: Row(
        children: [
          _Avatar(post: post, radius: 17, anonymous: anonymous),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailImageFallback extends StatelessWidget {
  final AppCommunityPost post;

  const _DetailImageFallback({required this.post});

  @override
  Widget build(BuildContext context) {
    final title = post.title.trim().isNotEmpty ? post.title.trim() : '作品动态';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE7EEF8), Color(0xFFF4E8EA)],
        ),
      ),
      alignment: Alignment.bottomLeft,
      child: Text(
        title,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF14213D),
          fontSize: 24,
          height: 1.16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PostBody extends StatelessWidget {
  final AppCommunityPost post;
  final bool isQa;

  const _PostBody({
    required this.post,
    required this.isQa,
  });

  @override
  Widget build(BuildContext context) {
    final body = post.body?.trim() ?? '';
    final category = post.metadata['category']?.toString();
    final school = post.metadata['school']?.toString();
    final program = post.metadata['program']?.toString();
    final meta = [
      _detailDateLabel(post.createdAt),
      _detailLocationLabel(post),
    ].where((item) => item.isNotEmpty).join(' ');
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isQa ? 18 : 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isQa) ...[
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _DetailBadge(label: category ?? '问答', dark: true),
                if (school != null && school.isNotEmpty)
                  _DetailBadge(label: school, dark: false),
                if (program != null && program.isNotEmpty)
                  _DetailBadge(label: program, dark: false),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Text(
            post.title.isNotEmpty
                ? post.title
                : isQa
                    ? '未命名问题'
                    : '作品分享',
            style: TextStyle(
              fontSize: isQa ? 24 : 20,
              fontWeight: FontWeight.w900,
              height: 1.24,
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
                height: 1.62,
                color: context.artC.ink.withOpacity(0.78),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (meta.isNotEmpty)
                Expanded(
                  child: Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.artC.ink.withValues(alpha: 0.42),
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 12),
              Icon(
                Icons.visibility_outlined,
                size: 16,
                color: context.artC.ink.withValues(alpha: 0.36),
              ),
              const SizedBox(width: 4),
              Text(
                '${_compactCount(post.viewCount)} 浏览',
                style: TextStyle(
                  fontSize: 12,
                  color: context.artC.ink.withValues(alpha: 0.42),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(
              height: 1, color: context.artC.silver.withValues(alpha: 0.35)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final AppCommunityPost post;
  final double radius;
  final bool anonymous;

  const _Avatar({
    required this.post,
    required this.radius,
    this.anonymous = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = post.authorAvatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: kCobalt.withOpacity(0.09),
      child: ClipOval(
        child: !anonymous && avatar != null && avatar.isNotEmpty
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

class _DetailBadge extends StatelessWidget {
  final String label;
  final bool dark;

  const _DetailBadge({required this.label, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? kCobalt.withOpacity(0.08) : context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dark
              ? kCobalt.withOpacity(0.28)
              : context.artC.silver.withOpacity(0.55),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dark ? kCobalt : context.artC.ink.withOpacity(0.58),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  final List<AppCommunityComment> comments;
  final bool loading;
  final bool isQa;
  final int commentCount;
  final int engagementCount;
  final Widget composer;
  final ValueChanged<AppCommunityComment> onAuthorTap;

  const _CommentsSection({
    required this.comments,
    required this.loading,
    required this.isQa,
    required this.commentCount,
    required this.engagementCount,
    required this.composer,
    required this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final certified =
        comments.where((comment) => comment.likeCount > 0).toList();
    final ordinary =
        comments.where((comment) => comment.likeCount <= 0).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isQa ? '回答 $commentCount' : '评论 $commentCount',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: context.artC.ink,
                ),
              ),
              const SizedBox(width: 26),
              Text(
                '赞和收藏 $engagementCount',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.artC.ink.withValues(alpha: 0.42),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          composer,
          const SizedBox(height: 18),
          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
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
            SizedBox(
              width: double.infinity,
              child: ArtseeSurface(
                padding: const EdgeInsets.all(18),
                radius: 16,
                child: Text(
                  isQa ? '还没有回答，分享你的经验或建议。' : '还没有评论，来写下第一句反馈。',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.artC.ink.withOpacity(0.42),
                  ),
                ),
              ),
            )
          else if (isQa) ...[
            if (certified.isNotEmpty) ...[
              _AnswerGroupTitle(label: '认证回答'),
              ...certified.map((comment) => _CommentTile(
                    comment: comment,
                    isQa: isQa,
                    onAuthorTap: () => onAuthorTap(comment),
                  )),
              const SizedBox(height: 8),
            ] else
              _InviteAnswerCard(),
            if (ordinary.isNotEmpty) ...[
              _AnswerGroupTitle(label: '其他回答'),
              ...ordinary.map((comment) => _CommentTile(
                    comment: comment,
                    isQa: isQa,
                    onAuthorTap: () => onAuthorTap(comment),
                  )),
            ],
          ] else
            ...comments.map((comment) => _CommentTile(
                  comment: comment,
                  isQa: isQa,
                  onAuthorTap: () => onAuthorTap(comment),
                )),
        ],
      ),
    );
  }
}

class _AnswerGroupTitle extends StatelessWidget {
  final String label;

  const _AnswerGroupTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          color: context.artC.ink.withOpacity(0.48),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _InviteAnswerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: double.infinity,
        child: ArtseeSurface(
          padding: const EdgeInsets.all(14),
          radius: 16,
          child: Row(
            children: [
              const Icon(Icons.verified_outlined, color: kCobalt, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '暂无认证回答，可以邀请校友、导师或顾问来回答。',
                  style: TextStyle(
                    color: context.artC.ink.withOpacity(0.52),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '邀请',
                style: TextStyle(
                  color: kCobalt,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final AppCommunityComment comment;
  final bool isQa;
  final VoidCallback onAuthorTap;

  const _CommentTile({
    required this.comment,
    required this.isQa,
    required this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = comment.authorNickname ?? 'Artsee 用户';
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onAuthorTap,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: kCobalt.withValues(alpha: 0.08),
              child: ClipOval(
                child: comment.authorAvatarUrl != null &&
                        comment.authorAvatarUrl!.isNotEmpty
                    ? Image.network(
                        comment.authorAvatarUrl!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _CommentInitial(name: name),
                      )
                    : _CommentInitial(name: name),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: onAuthorTap,
                        child: Text(
                          isQa && comment.likeCount > 0 ? '$name · 已认证' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: context.artC.ink.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.artC.ink.withValues(alpha: 0.32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  comment.body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: context.artC.ink.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '回复',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.artC.ink.withValues(alpha: 0.42),
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

String _publicHandleFromName(String name) {
  final cleaned = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (cleaned.isNotEmpty) return '@$cleaned';
  return '@artsee_${(name.hashCode.abs() % 99999).toString().padLeft(5, '0')}';
}

String _detailDateLabel(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return timeAgo(raw);
  final local = parsed.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _detailLocationLabel(AppCommunityPost post) {
  const keys = ['location', 'city', 'country', 'ip_location', 'region'];
  for (final key in keys) {
    final value = post.metadata[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return '';
}

String _compactCount(int value) {
  if (value < 10000) return '$value';
  final wan = value / 10000;
  final text = wan >= 10 ? wan.toStringAsFixed(0) : wan.toStringAsFixed(1);
  return '${text.replaceAll('.0', '')}万';
}

class _CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final bool isQa;
  final VoidCallback onSend;

  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.isQa,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: kCobalt.withValues(alpha: 0.08),
          child: Icon(
            Icons.person_outline,
            size: 18,
            color: kCobalt.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              color: context.artC.silver.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: isQa ? '有经验要说，快来回答' : '有话要说，快来评论',
                  border: InputBorder.none,
                  isDense: true,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: context.artC.ink.withValues(alpha: 0.32),
                  ),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: context.artC.ink,
                ),
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
            decoration: BoxDecoration(
              color: sending ? kCobalt.withValues(alpha: 0.55) : kCobalt,
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
                : const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }
}

class _DetailBottomActions extends StatelessWidget {
  final bool isQa;
  final bool liked;
  final bool saved;
  final bool likeBusy;
  final bool saveBusy;
  final int likeCount;
  final int saveCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;

  const _DetailBottomActions({
    required this.isQa,
    required this.liked,
    required this.saved,
    required this.likeBusy,
    required this.saveBusy,
    required this.likeCount,
    required this.saveCount,
    required this.commentCount,
    required this.onLike,
    required this.onSave,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        border: Border(
          top: BorderSide(color: context.artC.silver.withValues(alpha: 0.36)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 21,
                    color: context.artC.ink.withValues(alpha: 0.68),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '公开可见',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.artC.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '内容权限由作者设置',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.artC.ink.withValues(alpha: 0.42),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _BottomActionButton(
              icon: liked ? Icons.favorite : Icons.favorite_border_rounded,
              label: _compactCount(likeCount),
              active: liked,
              busy: likeBusy,
              onTap: onLike,
            ),
            const SizedBox(width: 16),
            _BottomActionButton(
              icon: saved ? Icons.star_rounded : Icons.star_border_rounded,
              label: '收藏',
              active: saved,
              busy: saveBusy,
              onTap: onSave,
            ),
            const SizedBox(width: 16),
            _BottomActionButton(
              icon: isQa
                  ? Icons.question_answer_outlined
                  : Icons.chat_bubble_outline_rounded,
              label: _compactCount(commentCount),
              onTap: onComment,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? kCobalt : context.artC.ink.withValues(alpha: 0.86);
    return GestureDetector(
      onTap: busy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kCobalt,
                ),
              )
            else
              Icon(icon, size: 28, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color:
                    active ? kCobalt : context.artC.ink.withValues(alpha: 0.72),
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
              color: context.artC.ink.withOpacity(0.25),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.artC.ink.withOpacity(0.58),
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
