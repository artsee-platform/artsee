import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DataService {
  static const String apiBaseUrl = 'http://10.0.2.2:3000/api/v1'; // Android模拟器

  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  // 获取学校列表
  Future<List<dynamic>> getSchools({int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/schools?limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('获取学校失败: $e');
      return [];
    }
  }

  // 获取项目列表
  Future<List<dynamic>> getPrograms({int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/programs?limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('获取项目失败: $e');
      return [];
    }
  }

  // 获取项目详情
  Future<Map<String, dynamic>?> getProgramDetail(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/programs/$id'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('获取项目详情失败: $e');
      return null;
    }
  }

  // 收藏项目
  Future<bool> favoriteProgram(String programId) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/user/favorites'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'program_id': programId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('收藏失败: $e');
      return false;
    }
  }
}
