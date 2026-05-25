import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String apiBaseUrl = 'http://10.0.2.2:3000/api/v1'; // Android模拟器
  // static const String apiBaseUrl = 'http://localhost:3000/api/v1'; // iOS模拟器

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // 发送短信验证码
  Future<Map<String, dynamic>> sendSmsCode(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/send-sms'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'country_code': '+86',
          'purpose': 'login',
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 验证短信验证码并登录
  Future<Map<String, dynamic>> verifySmsCode(String phone, String code) async {
    try {
      // 开发模式：验证码固定为 123456
      if (code != '123456') {
        return {'success': false, 'error': '验证码错误'};
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/verify-sms'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'code': code,
          'country_code': '+86',
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['user'] != null) {
        // 添加 role 到用户数据
        final userData = Map<String, dynamic>.from(data['user']);
        userData['role'] = userData['role'] ?? 'user';
        await _saveUserData(userData);

        // 更新返回数据
        data['user'] = userData;
      }

      return data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 保存用户数据
  Future<void> _saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user));
  }

  // 获取当前用户
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  // 检查登录状态
  Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();
    return user != null;
  }

  // 获取用户角色
  Future<String?> getUserRole() async {
    final user = await getCurrentUser();
    return user?['role'] as String?;
  }

  // 检查是否是管理员
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
  }

  // 退出登录
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
  }

  // 开发者一键登录
  Future<Map<String, dynamic>> devLogin() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/dev-login'),
        headers: {
          'Content-Type': 'application/json',
          'x-dev-secret': 'artsee_dev_2024',
        },
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['user'] != null) {
        final userData = Map<String, dynamic>.from(data['user']);
        userData['role'] = userData['role'] ?? 'admin';
        await _saveUserData(userData);
        data['user'] = userData;
      }

      return data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 更新用户画像
  Future<Map<String, dynamic>> updateUserProfile({
    String? nickname,
    List<String>? interestedCategories,
  }) async {
    try {
      final user = await getCurrentUser();
      if (user == null) {
        return {'success': false, 'error': '用户未登录'};
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/update-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': user['id'],
          'nickname': nickname,
          'interestedCategories': interestedCategories,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['profile'] != null) {
        // 更新本地存储的用户数据
        final updatedUser = Map<String, dynamic>.from(user);
        updatedUser['profile'] = data['profile'];
        await _saveUserData(updatedUser);
      }

      return data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 检查是否为新用户（未完成引导）
  Future<bool> isNewUser() async {
    final user = await getCurrentUser();
    if (user == null) return false;

    final profile = user['profile'] as Map<String, dynamic>?;
    if (profile == null) return true;

    return profile['has_completed_onboarding'] != true;
  }
}
