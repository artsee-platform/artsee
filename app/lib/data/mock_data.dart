// 统一 Mock 数据 - Flutter 版本
// 与 Web 端 mock_data/index.ts 保持同步

// ==================== 模型类 ====================

class User {
  final String id;
  final String nickname;
  final String avatar;
  final String role;
  final String country;
  final List<String> targetSchools;
  final int portfolioCount;
  final int followers;
  final int following;

  User({
    required this.id,
    required this.nickname,
    required this.avatar,
    required this.role,
    required this.country,
    required this.targetSchools,
    required this.portfolioCount,
    required this.followers,
    required this.following,
  });
}

class School {
  final String id;
  final String name;
  final String nameEn;
  final String country;
  final String city;
  final String logo;
  final String coverImage;
  final int qsRank;
  final int artRank;
  final String description;
  final String website;
  final List<Program> programs;
  final List<String> facilities;

  School({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.country,
    required this.city,
    required this.logo,
    required this.coverImage,
    required this.qsRank,
    required this.artRank,
    required this.description,
    required this.website,
    required this.programs,
    required this.facilities,
  });
}

class Program {
  final String id;
  final String name;
  final String nameEn;
  final String degree;
  final String duration;
  final String language;
  final int tuition;
  final String description;
  final List<String> requirements;
  final List<String> portfolioRequirements;

  Program({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.degree,
    required this.duration,
    required this.language,
    required this.tuition,
    required this.description,
    required this.requirements,
    required this.portfolioRequirements,
  });
}

class Post {
  final String id;
  final String type;
  final User author;
  final String title;
  final String content;
  final List<String> images;
  final List<String> tags;
  final int likes;
  final int comments;
  final int collections;
  final String createdAt;
  bool isLiked;
  bool isCollected;

  Post({
    required this.id,
    required this.type,
    required this.author,
    required this.title,
    required this.content,
    required this.images,
    required this.tags,
    required this.likes,
    required this.comments,
    required this.collections,
    required this.createdAt,
    this.isLiked = false,
    this.isCollected = false,
  });
}

class Mentor {
  final String id;
  final String name;
  final String avatar;
  final String title;
  final String school;
  final List<String> specialties;
  final double rating;
  final int reviewCount;
  final int price;
  final String bio;

  Mentor({
    required this.id,
    required this.name,
    required this.avatar,
    required this.title,
    required this.school,
    required this.specialties,
    required this.rating,
    required this.reviewCount,
    required this.price,
    required this.bio,
  });
}

class ApplicationProgress {
  final String id;
  final String schoolName;
  final String programName;
  final String status;
  final int progress;
  final List<ApplicationTask> tasks;

  ApplicationProgress({
    required this.id,
    required this.schoolName,
    required this.programName,
    required this.status,
    required this.progress,
    required this.tasks,
  });
}

class ApplicationTask {
  final String id;
  final String title;
  final String deadline;
  final String status;
  final String priority;

  ApplicationTask({
    required this.id,
    required this.title,
    required this.deadline,
    required this.status,
    required this.priority,
  });
}

class ArtResource {
  final String id;
  final String type;
  final String title;
  final String coverImage;
  final String location;
  final String duration;
  final int price;
  final String description;
  final List<String> highlights;

  ArtResource({
    required this.id,
    required this.type,
    required this.title,
    required this.coverImage,
    required this.location,
    required this.duration,
    required this.price,
    required this.description,
    required this.highlights,
  });
}

class Artwork {
  final String id;
  final String title;
  final User artist;
  final List<String> images;
  final String category;
  final int price;
  final String description;
  final int likes;

  Artwork({
    required this.id,
    required this.title,
    required this.artist,
    required this.images,
    required this.category,
    required this.price,
    required this.description,
    required this.likes,
  });
}

class News {
  final String id;
  final String title;
  final String summary;
  final String coverImage;
  final String category;
  final int views;
  final String publishedAt;

  News({
    required this.id,
    required this.title,
    required this.summary,
    required this.coverImage,
    required this.category,
    required this.views,
    required this.publishedAt,
  });
}

// ==================== Mock 数据 ====================

class MockData {
  // 当前用户
  static final User currentUser = User(
    id: 'user_001',
    nickname: '艺术追梦人',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=artseeker',
    role: 'student',
    country: '中国',
    targetSchools: ['皇家艺术学院', '罗德岛设计学院'],
    portfolioCount: 12,
    followers: 256,
    following: 89,
  );

  // 院校列表
  static final List<School> schools = [
    School(
      id: 'school_001',
      name: '皇家艺术学院',
      nameEn: 'Royal College of Art',
      country: '英国',
      city: '伦敦',
      logo: 'https://via.placeholder.com/100x100/4074b1/FFFFFF?text=RCA',
      coverImage: 'https://via.placeholder.com/800x400/183b90/FFFFFF?text=RCA',
      qsRank: 1,
      artRank: 1,
      description: '全球顶尖艺术与设计学院，提供硕士和博士课程，以研究型教学闻名。',
      website: 'https://www.rca.ac.uk',
      programs: [
        Program(
          id: 'prog_001',
          name: '视觉传达设计',
          nameEn: 'Visual Communication',
          degree: '硕士',
          duration: '2年',
          language: '英语',
          tuition: 32000,
          description: '探索视觉传达的边界，培养创新思维和跨学科能力。',
          requirements: ['本科学位', '作品集', '雅思6.5'],
          portfolioRequirements: ['展示创意思维', '包含实验性作品', '体现技术能力'],
        ),
        Program(
          id: 'prog_002',
          name: '室内设计',
          nameEn: 'Interior Design',
          degree: '硕士',
          duration: '2年',
          language: '英语',
          tuition: 35000,
          description: '培养具有批判性思维和创新能力的室内设计师。',
          requirements: ['本科学位', '作品集', '雅思6.5'],
          portfolioRequirements: ['空间设计作品', '材料研究', '概念发展'],
        ),
      ],
      facilities: ['专业工作室', '3D打印实验室', '材料图书馆', '展览空间'],
    ),
    School(
      id: 'school_002',
      name: '罗德岛设计学院',
      nameEn: 'Rhode Island School of Design',
      country: '美国',
      city: '普罗维登斯',
      logo: 'https://via.placeholder.com/100x100/425691/FFFFFF?text=RISD',
      coverImage: 'https://via.placeholder.com/800x400/4074b1/FFFFFF?text=RISD',
      qsRank: 3,
      artRank: 2,
      description: '美国最古老的艺术设计学院之一，以严谨的学术和创造性教育著称。',
      website: 'https://www.risd.edu',
      programs: [],
      facilities: [],
    ),
    School(
      id: 'school_003',
      name: '中央圣马丁',
      nameEn: 'Central Saint Martins',
      country: '英国',
      city: '伦敦',
      logo: 'https://via.placeholder.com/100x100/5A8FC9/FFFFFF?text=CSM',
      coverImage: 'https://via.placeholder.com/800x400/425691/FFFFFF?text=CSM',
      qsRank: 2,
      artRank: 3,
      description: '伦敦艺术大学下属学院，以时装设计和纯艺术闻名。',
      website: 'https://www.arts.ac.uk',
      programs: [],
      facilities: [],
    ),
    School(
      id: 'school_004',
      name: '帕森斯设计学院',
      nameEn: 'Parsons School of Design',
      country: '美国',
      city: '纽约',
      logo: 'https://via.placeholder.com/100x100/A8C4E0/FFFFFF?text=Parsons',
      coverImage:
          'https://via.placeholder.com/800x400/5A8FC9/FFFFFF?text=Parsons',
      qsRank: 4,
      artRank: 4,
      description: '纽约著名设计学院，时装设计专业全球领先。',
      website: 'https://www.newschool.edu/parsons',
      programs: [],
      facilities: [],
    ),
  ];

  // 帖子列表
  static final List<Post> posts = [
    Post(
      id: 'post_001',
      type: 'offer',
      author: User(
        id: 'user_002',
        nickname: '设计新星',
        avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=designer',
        role: 'student',
        country: '中国',
        targetSchools: ['RCA'],
        portfolioCount: 8,
        followers: 1200,
        following: 45,
      ),
      title: 'RCA视觉传达Offer到手！分享我的申请经验',
      content: '经过一年的准备，终于拿到了梦校的offer！分享一些作品集准备和面试的经验...',
      images: ['https://via.placeholder.com/400x300/4074b1/FFFFFF?text=Offer'],
      tags: ['RCA', '视觉传达', '申请经验', 'Offer'],
      likes: 256,
      comments: 48,
      collections: 132,
      createdAt: '2024-03-20T10:00:00Z',
    ),
    Post(
      id: 'post_002',
      type: 'portfolio',
      author: User(
        id: 'user_003',
        nickname: '插画师小林',
        avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=illustrator',
        role: 'artist',
        country: '中国',
        targetSchools: ['RISD'],
        portfolioCount: 15,
        followers: 3400,
        following: 120,
      ),
      title: '我的RISD插画作品集分享',
      content: '整理了申请RISD时的作品集，包含观察绘画和创意项目...',
      images: [
        'https://via.placeholder.com/400x500/183b90/FFFFFF?text=Work1',
        'https://via.placeholder.com/400x500/4074b1/FFFFFF?text=Work2',
      ],
      tags: ['RISD', '插画', '作品集', '观察绘画'],
      likes: 892,
      comments: 156,
      collections: 567,
      createdAt: '2024-03-18T14:30:00Z',
    ),
    Post(
      id: 'post_003',
      type: 'question',
      author: User(
        id: 'user_004',
        nickname: '留学小白',
        avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=newbie',
        role: 'student',
        country: '中国',
        targetSchools: [],
        portfolioCount: 0,
        followers: 5,
        following: 23,
      ),
      title: '申请RCA的作品集需要准备多久？',
      content: '我现在大二，想申请RCA的硕士，请问大家作品集都准备了多长时间？',
      images: [],
      tags: ['RCA', '作品集', '申请规划'],
      likes: 12,
      comments: 28,
      collections: 3,
      createdAt: '2024-03-22T09:15:00Z',
    ),
  ];

  // 导师列表
  static final List<Mentor> mentors = [
    Mentor(
      id: 'mentor_001',
      name: '张教授',
      avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=professor',
      title: 'RCA视觉传达导师',
      school: '皇家艺术学院',
      specialties: ['视觉传达', '品牌设计', '数字媒体'],
      rating: 4.9,
      reviewCount: 128,
      price: 800,
      bio: '专注于视觉传达设计与品牌策略研究，帮助数百名学生进入梦校。',
    ),
    Mentor(
      id: 'mentor_002',
      name: '李老师',
      avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=teacher',
      title: 'RISD插画导师',
      school: '罗德岛设计学院',
      specialties: ['插画', '绘本', '概念艺术'],
      rating: 4.8,
      reviewCount: 96,
      price: 600,
      bio: '资深插画家，作品曾入选博洛尼亚童书展，擅长指导学生发展个人风格。',
    ),
    Mentor(
      id: 'mentor_003',
      name: '王建筑师',
      avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=wang',
      title: 'AA建筑联盟导师',
      school: 'AA建筑联盟',
      specialties: ['建筑设计', '参数化设计', '城市设计'],
      rating: 4.9,
      reviewCount: 156,
      price: 1000,
      bio: '专注于参数化设计与可持续建筑，帮助学生建立独特的设计思维。',
    ),
  ];

  // 申请进度
  static final List<ApplicationProgress> applicationProgress = [
    ApplicationProgress(
      id: 'app_001',
      schoolName: '皇家艺术学院',
      programName: '视觉传达设计',
      status: 'submitted',
      progress: 40,
      tasks: [
        ApplicationTask(
            id: 'task_001',
            title: '准备作品集',
            deadline: '2024-01-15',
            status: 'completed',
            priority: 'high'),
        ApplicationTask(
            id: 'task_002',
            title: '撰写个人陈述',
            deadline: '2024-01-20',
            status: 'completed',
            priority: 'high'),
        ApplicationTask(
            id: 'task_003',
            title: '提交申请',
            deadline: '2024-02-01',
            status: 'completed',
            priority: 'high'),
        ApplicationTask(
            id: 'task_004',
            title: '准备面试',
            deadline: '2024-03-15',
            status: 'in_progress',
            priority: 'high'),
      ],
    ),
    ApplicationProgress(
      id: 'app_002',
      schoolName: '罗德岛设计学院',
      programName: '插画',
      status: 'offer',
      progress: 100,
      tasks: [
        ApplicationTask(
            id: 'task_005',
            title: '准备作品集',
            deadline: '2024-01-10',
            status: 'completed',
            priority: 'high'),
        ApplicationTask(
            id: 'task_006',
            title: '提交申请',
            deadline: '2024-01-15',
            status: 'completed',
            priority: 'high'),
        ApplicationTask(
            id: 'task_007',
            title: '面试',
            deadline: '2024-02-20',
            status: 'completed',
            priority: 'high'),
        ApplicationTask(
            id: 'task_008',
            title: '收到Offer',
            deadline: '2024-03-01',
            status: 'completed',
            priority: 'high'),
      ],
    ),
  ];

  // 艺术资源
  static final List<ArtResource> artResources = [
    ArtResource(
      id: 'resource_001',
      type: 'tour',
      title: '伦敦艺术深度游',
      coverImage:
          'https://via.placeholder.com/600x400/183b90/FFFFFF?text=London',
      location: '英国伦敦',
      duration: '7天6晚',
      price: 25800,
      description: '深度探访伦敦顶级博物馆、画廊，参访RCA、CSM等名校。',
      highlights: ['大英博物馆导览', '泰特现代美术馆', 'RCA校园参访', '艺术家工作室探访'],
    ),
    ArtResource(
      id: 'resource_002',
      type: 'camp',
      title: '托斯卡纳写生营',
      coverImage:
          'https://via.placeholder.com/600x400/425691/FFFFFF?text=Tuscany',
      location: '意大利托斯卡纳',
      duration: '10天9晚',
      price: 19800,
      description: '在意大利文艺复兴发源地，跟随名师进行写生创作。',
      highlights: ['风景写生', '油画创作', '艺术史讲座', '酒庄品鉴'],
    ),
    ArtResource(
      id: 'resource_003',
      type: 'course',
      title: '帕森斯暑期课程',
      coverImage:
          'https://via.placeholder.com/600x400/4074b1/FFFFFF?text=Parsons',
      location: '美国纽约',
      duration: '4周',
      price: 45000,
      description: '体验帕森斯设计学院夏校，获得官方学分和证书。',
      highlights: ['时装设计', '平面设计', '纽约艺术探索', '作品集指导'],
    ),
  ];

  // 艺术品列表
  static final List<Artwork> artworks = [
    Artwork(
      id: 'artwork_001',
      title: '城市印象 No.1',
      artist: User(
        id: 'user_007',
        nickname: '青年艺术家A',
        avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=artist1',
        role: 'artist',
        country: '中国',
        targetSchools: [],
        portfolioCount: 8,
        followers: 456,
        following: 34,
      ),
      images: [
        'https://via.placeholder.com/600x800/183b90/FFFFFF?text=Artwork1'
      ],
      category: '油画',
      price: 12000,
      description: '探索城市变迁中的情感记忆，用色彩表达都市生活的节奏。',
      likes: 234,
    ),
    Artwork(
      id: 'artwork_002',
      title: '自然韵律',
      artist: User(
        id: 'user_008',
        nickname: '青年艺术家B',
        avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=artist2',
        role: 'artist',
        country: '中国',
        targetSchools: [],
        portfolioCount: 12,
        followers: 678,
        following: 56,
      ),
      images: [
        'https://via.placeholder.com/600x800/4074b1/FFFFFF?text=Artwork2'
      ],
      category: '水彩',
      price: 5800,
      description: '捕捉自然界的微妙变化，展现生命的律动。',
      likes: 189,
    ),
  ];

  // 资讯列表
  static final List<News> newsList = [
    News(
      id: 'news_001',
      title: 'RCA 2024申请截止日期延期通知',
      summary: '由于申请人数过多，RCA决定延长部分专业的申请截止日期。',
      coverImage:
          'https://via.placeholder.com/800x400/4074b1/FFFFFF?text=RCA+News',
      category: '院校动态',
      views: 5678,
      publishedAt: '2024-03-22T10:00:00Z',
    ),
    News(
      id: 'news_002',
      title: '2024年全球艺术院校排名发布',
      summary: 'QS最新发布2024年艺术与设计院校排名，RCA连续第10年蝉联榜首。',
      coverImage:
          'https://via.placeholder.com/800x400/425691/FFFFFF?text=Ranking',
      category: '行业资讯',
      views: 8901,
      publishedAt: '2024-03-20T16:00:00Z',
    ),
  ];

  // ==================== 数据获取方法 ====================

  static User getCurrentUser() => currentUser;

  static List<School> getSchools() => schools;

  static School? getSchoolById(String id) {
    for (final school in schools) {
      if (school.id == id) return school;
    }
    return null;
  }

  static List<Post> getPosts({String? type}) {
    if (type == null) return posts;
    return posts.where((p) => p.type == type).toList();
  }

  static List<Mentor> getMentors() => mentors;

  static List<ApplicationProgress> getApplicationProgress() =>
      applicationProgress;

  static List<ArtResource> getArtResources({String? type}) {
    if (type == null) return artResources;
    return artResources.where((r) => r.type == type).toList();
  }

  static List<Artwork> getArtworks() => artworks;

  static List<News> getNews() => newsList;
}
