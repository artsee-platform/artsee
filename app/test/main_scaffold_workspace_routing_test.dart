import 'package:flutter_test/flutter_test.dart';

import 'package:artsee_app/screens/main_scaffold.dart';

void main() {
  group('MainScaffold workspace routing', () {
    test('个人学生用户继续看到院校频道', () {
      final profile = {
        'user_type': 'personal',
        'user_role': 'student',
      };

      expect(usesWorkspaceTabForProfile(profile), isFalse);
      expect(workspaceSurfaceForProfile(profile), 'school');
    });

    test('只有 business 类型的用户进入通用工作台', () {
      final profile = {
        'user_type': 'business',
      };

      expect(usesWorkspaceTabForProfile(profile), isTrue);
      expect(workspaceRoleForProfile(profile), 'business');
      expect(workspaceSurfaceForProfile(profile), 'general_business_workspace');
    });

    test('艺术留学机构进入机构工作台', () {
      final profile = {
        'user_type': 'business',
        'user_role': 'study_abroad_agency',
      };

      expect(usesWorkspaceTabForProfile(profile), isTrue);
      expect(workspaceRoleForProfile(profile), 'study_abroad_agency');
      expect(workspaceSurfaceForProfile(profile), 'institution_workspace');
      expect(
        mainNavigationLabelsForProfile(profile),
        ['工作台', '发现', '消息', '我的'],
      );
    });

    test('画廊展览机构进入画廊工作台', () {
      final profile = {
        'user_type': 'business',
        'user_role': 'gallery_exhibition',
      };

      expect(usesWorkspaceTabForProfile(profile), isTrue);
      expect(workspaceSurfaceForProfile(profile), 'gallery_workspace');
    });

    test('只要有机构成员关系，也切到工作台', () {
      final profile = {
        'user_type': 'personal',
        'user_role': 'student',
      };

      expect(
        usesWorkspaceTabForProfile(
          profile,
          hasOrganizationMembership: true,
        ),
        isTrue,
      );
      expect(
        workspaceSurfaceForProfile(
          profile,
          hasOrganizationMembership: true,
        ),
        'general_business_workspace',
      );
    });
  });
}
