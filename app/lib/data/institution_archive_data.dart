/// 对齐 design-reference `src/data/institutions.ts`（稿件院校档案）
class InstitutionArchive {
  final String id;
  final String name;
  final String? originalName;
  final String location;
  final String description;
  final String image;

  const InstitutionArchive({
    required this.id,
    required this.name,
    this.originalName,
    required this.location,
    required this.description,
    required this.image,
  });
}

/// 与稿件一致的地区键名；展示总量用于「70+」类文案
const int kInstitutionArchiveTotalCount = 70;

const Map<String, List<InstitutionArchive>> kInstitutionArchiveByRegion = {
  '中国香港': [
    InstitutionArchive(
      id: 'hk-1',
      name: '香港理工大学设计学院',
      originalName: 'PolyU Design',
      location: '九龙红磡',
      image: 'https://picsum.photos/seed/polyu-hk/800/600',
      description: '亚洲顶尖设计学院，以创新与实践见长。',
    ),
    InstitutionArchive(
      id: 'hk-2',
      name: '香港艺术学院',
      originalName: 'Hong Kong Art School',
      location: '湾仔',
      image: 'https://picsum.photos/seed/hkas-art/800/600',
      description: '专注于当代艺术实践，与澳洲皇家墨尔本理工大学合办课程。',
    ),
    InstitutionArchive(
      id: 'hk-3',
      name: '香港中文大学艺术系',
      originalName: 'CUHK Fine Arts',
      location: '沙田',
      image: 'https://picsum.photos/seed/cuhk-hk/800/600',
      description: '深耕中国艺术史与创作，融合东西文化。',
    ),
  ],
  '美国': [
    InstitutionArchive(
      id: 'us-1',
      name: '罗德岛设计学院',
      originalName: 'RISD',
      location: '普罗维登斯',
      image: 'https://picsum.photos/seed/us-risd/800/600',
      description: '常年位居全美艺术设计类榜首，被誉为「艺术界的哈佛」。',
    ),
    InstitutionArchive(
      id: 'us-2',
      name: '耶鲁大学艺术学院',
      originalName: 'Yale School of Art',
      location: '纽黑文',
      image: 'https://picsum.photos/seed/us-yale/800/600',
      description: '顶级综合性大学中的皇冠，平面设计与绘画闻名遐迩。',
    ),
    InstitutionArchive(
      id: 'us-3',
      name: '芝加哥艺术学院',
      originalName: 'SAIC',
      location: '芝加哥',
      image: 'https://picsum.photos/seed/us-saic/800/600',
      description: '强调跨学科创作与批判思维，与芝加哥艺术博物馆紧密关联。',
    ),
  ],
  '欧洲': [
    InstitutionArchive(
      id: 'eu-1',
      name: '皇家艺术学院',
      originalName: 'Royal College of Art (RCA)',
      location: '伦敦, 英国',
      image: 'https://picsum.photos/seed/eu-rca/800/600',
      description: '全球唯一的全研究制艺术研究生院校，QS 艺术与设计排名长期领先。',
    ),
    InstitutionArchive(
      id: 'eu-2',
      name: '中央圣马丁学院',
      originalName: 'Central Saint Martins',
      location: '伦敦, 英国',
      image: 'https://picsum.photos/seed/eu-csm/800/600',
      description: '跨界创意的代名词，时尚与当代艺术的实验田。',
    ),
    InstitutionArchive(
      id: 'eu-3',
      name: '埃因霍温设计学院',
      originalName: 'Design Academy Eindhoven',
      location: '埃因霍温, 荷兰',
      image: 'https://picsum.photos/seed/eu-dae/800/600',
      description: '概念设计的麦加，以概念性与社会性反思著称。',
    ),
  ],
  '日本': [
    InstitutionArchive(
      id: 'jp-1',
      name: '东京艺术大学',
      originalName: 'Tokyo Geidai',
      location: '东京',
      image: 'https://picsum.photos/seed/jp-geidai/800/600',
      description: '日本唯一的国立艺术大学，艺术界的最高学术殿堂。',
    ),
    InstitutionArchive(
      id: 'jp-2',
      name: '多摩美术大学',
      originalName: 'Tama Art University',
      location: '东京',
      image: 'https://picsum.photos/seed/jp-tama/800/600',
      description: '御三家之一，深泽直人曾任教，平面与工业设计极强。',
    ),
    InstitutionArchive(
      id: 'jp-3',
      name: '武藏野美术大学',
      originalName: 'Musabi',
      location: '东京',
      image: 'https://picsum.photos/seed/jp-musabi/800/600',
      description: '原研哉任教，强调艺术与设计的感性平衡。',
    ),
  ],
  '韩国': [
    InstitutionArchive(
      id: 'kr-1',
      name: '首尔大学美术学院',
      originalName: 'SNU College of Fine Arts',
      location: '首尔',
      image: 'https://picsum.photos/seed/kr-snu/800/600',
      description: '韩国学府之首，综合研究实力与艺术造诣兼具。',
    ),
    InstitutionArchive(
      id: 'kr-2',
      name: '弘益大学美术学院',
      originalName: 'Hongik Art',
      location: '首尔',
      image: 'https://picsum.photos/seed/kr-hongik/800/600',
      description: '韩国设计界的代名词，拥有庞大的校友网络与产业影响力。',
    ),
    InstitutionArchive(
      id: 'kr-3',
      name: '韩国艺术综合大学',
      originalName: 'K-ARTS',
      location: '首尔',
      image: 'https://picsum.photos/seed/kr-karts/800/600',
      description: '由文化体育观光部设立，专注于专业艺术家培养。',
    ),
  ],
  '加拿大': [
    InstitutionArchive(
      id: 'ca-1',
      name: '安大略艺术设计大学',
      originalName: 'OCAD University',
      location: '多伦多',
      image: 'https://picsum.photos/seed/ca-ocad/800/600',
      description: '加拿大规模最大、历史最悠久的艺术院校，城市艺术地标。',
    ),
    InstitutionArchive(
      id: 'ca-2',
      name: '艾米丽卡尔艺术与设计大学',
      originalName: 'Emily Carr (ECUAD)',
      location: '温哥华',
      image: 'https://picsum.photos/seed/ca-ecuad/800/600',
      description: '位列全球前列的极客型艺术大学，媒体艺术领先。',
    ),
    InstitutionArchive(
      id: 'ca-3',
      name: '谢尔丹学院设计学部',
      originalName: 'Sheridan College',
      location: '奥克维尔',
      image: 'https://picsum.photos/seed/ca-sheridan/800/600',
      description: '「动画界的哈佛」，毕业生遍布好莱坞各大制片公司。',
    ),
  ],
  '亚洲其他国家': [
    InstitutionArchive(
      id: 'as-3',
      name: '中国美术学院',
      originalName: 'China Academy of Art',
      location: '杭州',
      image: 'https://picsum.photos/seed/as-caa/800/600',
      description: '中国传统与当代艺术融合的枢纽。',
    ),
    InstitutionArchive(
      id: 'as-4',
      name: '中央美术学院',
      originalName: 'CAFA',
      location: '北京',
      image: 'https://picsum.photos/seed/as-cafa/800/600',
      description: '中国艺术教育的最高学府，大师辈出。',
    ),
    InstitutionArchive(
      id: 'as-1',
      name: '新加坡国立大学设计学院',
      originalName: 'NUS Design',
      location: '新加坡',
      image: 'https://picsum.photos/seed/as-nus/800/600',
      description: '亚洲顶尖，注重城市设计与交互创新。',
    ),
  ],
};
