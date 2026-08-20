import 'package:flutter_test/flutter_test.dart';

import 'package:artsee_app/models/models.dart';

void main() {
  test('AppCommunityPost.fromJson 解析 user_profiles 与 image_urls', () {
    final p = AppCommunityPost.fromJson({
      'id': 'a1',
      'title': '测试',
      'body': '正文',
      'image_urls': ['https://x.com/1.jpg'],
      'status': 'reviewing',
      'audit_status': 'reviewing',
      'audit_reason': 'Ad/Suspected',
      'like_count': 2,
      'comment_count': 1,
      'view_count': 10,
      'liked_by_me': true,
      'created_at': '2026-01-01T00:00:00Z',
      'author_id': 'user-1',
      'user_profiles': {'nickname': '小明', 'avatar_url': null},
    });
    expect(p.id, 'a1');
    expect(p.imageUrls.length, 1);
    expect(p.authorNickname, '小明');
    expect(p.authorId, 'user-1');
    expect(p.authorAvatarUrl, null);
    expect(p.likedByMe, true);
    expect(p.status, 'reviewing');
    expect(p.auditStatus, 'reviewing');
    expect(p.auditReason, 'Ad/Suspected');
  });

  test('AppCommunityPost.fromJson 兼容旧作品图片字段', () {
    final p = AppCommunityPost.fromJson({
      'id': 'a2',
      'title': '旧作品动态',
      'body': null,
      'images': ['https://x.com/work.jpg'],
      'like_count': 0,
      'comment_count': 0,
      'view_count': 0,
      'created_at': '2026-01-01T00:00:00Z',
    });

    expect(p.imageUrls, ['https://x.com/work.jpg']);
  });

  test('AppCommunityPost.fromJson 解析已发布 Gaussian 沉浸资产', () {
    final p = AppCommunityPost.fromJson({
      'id': 'immersive-1',
      'title': '数字典藏作品',
      'image_urls': ['https://x.com/poster.jpg'],
      'metadata': {
        'immersive_asset': {
          'id': 'asset-1',
          'type': 'gaussian',
          'status': 'ready',
          'asset_url': 'https://x.com/work.sog',
          'source_url': 'https://x.com/artwork',
          'license_name': 'CC BY 4.0',
          'license_url': 'https://creativecommons.org/licenses/by/4.0/',
          'camera_position': [0, 1, 3],
          'model_rotation': '0 0 180',
        },
      },
      'like_count': 0,
      'comment_count': 0,
      'view_count': 0,
      'created_at': '2026-01-01T00:00:00Z',
    });

    expect(p.immersiveAsset, isNotNull);
    expect(p.immersiveAsset!.isViewable, true);
    expect(p.immersiveAsset!.type, ImmersiveAssetType.gaussian);
    expect(p.immersiveAsset!.cameraPosition, [0, 1, 3]);
    expect(p.immersiveAsset!.modelRotation, [0, 0, 180]);
    expect(p.immersiveAsset!.sourceUrl, 'https://x.com/artwork');
    expect(p.immersiveAsset!.licenseName, 'CC BY 4.0');
  });

  test('沉浸资产查看地址包含白名单配置，审核中资产不可展示', () {
    final asset = ImmersiveAsset.fromJson({
      'id': 'asset-review',
      'type': '3dgs',
      'status': 'reviewing',
      'asset_url': 'https://x.com/work.sog',
      'poster_url': 'https://x.com/poster.jpg',
      'model_position': [0, -0.5, 0],
    });

    expect(asset, isNotNull);
    expect(asset!.isViewable, false);
    final uri = asset.buildViewerUri(
      viewerBaseUri: Uri.parse('https://artiqore.com/immersive/index.html'),
      fallbackTitle: '作品标题',
    );
    expect(uri.queryParameters['asset'], 'https://x.com/work.sog');
    expect(uri.queryParameters['poster'], 'https://x.com/poster.jpg');
    expect(uri.queryParameters['position'], '0 -0.5 0');
  });

  test('沉浸资产忽略非 HTTP 自定义查看地址', () {
    const asset = ImmersiveAsset(
      id: 'asset-safe-viewer',
      type: ImmersiveAssetType.gaussian,
      status: ImmersiveAssetStatus.published,
      assetUrl: 'https://x.com/work.sog',
      viewerUrl: 'javascript:alert(1)',
    );

    final uri = asset.buildViewerUri(
      viewerBaseUri: Uri.parse('https://artiqore.com/immersive/index.html'),
    );
    expect(uri.scheme, 'https');
    expect(uri.host, 'artiqore.com');
    expect(uri.queryParameters['asset'], 'https://x.com/work.sog');
  });

  test('AppCommunityComment.fromJson 解析评论作者资料', () {
    final c = AppCommunityComment.fromJson({
      'id': 'c1',
      'body': '很有启发',
      'like_count': 3,
      'created_at': '2026-01-01T01:00:00Z',
      'author_id': 'user-2',
      'user_profiles': {'nickname': '小红', 'avatar_url': 'https://x/avatar.png'},
    });
    expect(c.id, 'c1');
    expect(c.body, '很有启发');
    expect(c.likeCount, 3);
    expect(c.authorId, 'user-2');
    expect(c.authorNickname, '小红');
    expect(c.authorAvatarUrl, 'https://x/avatar.png');
  });

  test('AppCommunityHotTopic.fromJson 解析热议话题与观点作者', () {
    final topic = AppCommunityHotTopic.fromJson({
      'id': 'topic-1',
      'slug': 'ai-art-award-progress-or-cheating',
      'tag': '🔥 争议',
      'title': 'AI绘画拿大奖，这是艺术的进步还是作弊？',
      'category': '行业就业',
      'participant_count': 156,
      'sort_order': 1,
      'is_pinned': true,
      'answers': [
        {
          'stance': '正方·进步论',
          'content': 'AI是新的画笔。',
          'author': {
            'id': 'artist-1',
            'name': '沈予白',
            'handle': 'shen-yubai',
            'avatar_url': 'https://x/avatar.png',
            'role': '认证艺术家',
          },
          'like_count': 18,
          'comment_count': 3,
          'share_count': 2,
        },
        {'stance': '反方·作弊论', 'content': '这对人类创作者不公平。'},
      ],
      'metadata': {'theme': 'AI科技'},
      'created_at': '2026-06-10T00:00:00Z',
    });
    expect(topic.slug, 'ai-art-award-progress-or-cheating');
    expect(topic.participantCount, 156);
    expect(topic.isPinned, true);
    expect(topic.answers.length, 2);
    expect(topic.answers.first.stance, '正方·进步论');
    expect(topic.answers.first.authorName, '沈予白');
    expect(topic.answers.first.authorId, 'artist-1');
    expect(topic.answers.first.authorHandle, 'shen-yubai');
    expect(topic.answers.first.authorAvatarUrl, 'https://x/avatar.png');
    expect(topic.answers.first.authorRole, '认证艺术家');
    expect(topic.answers.first.likeCount, 18);
    expect(topic.answers.first.commentCount, 3);
    expect(topic.answers.first.shareCount, 2);
    expect(topic.metadata['theme'], 'AI科技');
  });

  test('AppProgram.fromJson 接受 Next / Supabase 嵌套 schools 与 admissions 数组', () {
    final json = {
      'id': '001f9862-a2c5-4d37-9b7a-720ceeef163e',
      'program_name': 'MA Fine Art',
      'degree_type': 'MA',
      'requires_portfolio': true,
      'requires_interview': false,
      'schools': {'name_zh': '某大学', 'qs_art_rank': 3},
      'program_admissions': [
        {'ielts_overall': 6.5, 'regular_deadline': '2026-01-15'},
      ],
      'program_fees': [
        {'international_tuition_fee': 25000, 'currency_code': 'GBP'},
      ],
    };
    final prog = AppProgram.fromJson(json);
    expect(prog.id, '001f9862-a2c5-4d37-9b7a-720ceeef163e');
    expect(prog.schoolNameZh, '某大学');
    expect(prog.ieltsOverall, 6.5);
    expect(prog.internationalTuitionFee, 25000);
  });

  test('HomeContent.fromJson 解析 /api/v1/home-contents 返回字段', () {
    final json = {
      'id': 'f8ab9832-ca22-4c94-9ad4-e73e36a48e7c',
      'section_type': 'hero_banner',
      'title': '灵感碎片的万合\n青花新境',
      'subtitle': 'SPECIAL / 陶瓷重构专场',
      'image_url':
          'https://images.unsplash.com/photo-1549490349-8643362247b5?auto=format&fit=crop&q=80&w=2000',
      'link_url': null,
      'link_text': '立即观展 (Virtual Access)',
      'badge': null,
      'display_order': 0,
      'is_active': true,
      'created_at': '2026-04-22T22:11:15.025063+00:00',
      'updated_at': '2026-04-22T22:11:15.025063+00:00',
    };
    final c = HomeContent.fromJson(json);
    expect(c.id, 'f8ab9832-ca22-4c94-9ad4-e73e36a48e7c');
    expect(c.sectionType, 'hero_banner');
    expect(c.title, '灵感碎片的万合\n青花新境');
    expect(c.subtitle, 'SPECIAL / 陶瓷重构专场');
    expect(c.imageUrl,
        'https://images.unsplash.com/photo-1549490349-8643362247b5?auto=format&fit=crop&q=80&w=2000');
    expect(c.linkText, '立即观展 (Virtual Access)');
    expect(c.badge, null);
    expect(c.displayOrder, 0);
    expect(c.isActive, true);
  });
}
