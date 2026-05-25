import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import 'supabase_service.dart';

/// 基于 Next.js 后端 `/api/v1/upload` 的对象存储封装。
/// 所有用户图片（头像、社区 UGC 等）经此后端接口上传，由服务端写入 Supabase Storage。
class StorageService {
  StorageService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Uri _uploadUrl() => Uri.parse('${ApiConfig.baseUrl}/api/v1/upload');

  static Future<Map<String, String>> _authHeaders() async {
    final t = _client.auth.currentSession?.accessToken;
    if (t == null) throw StateError('未登录');
    return {'Authorization': 'Bearer $t'};
  }

  /// 上传任意用户文件到指定文件夹，如 `posts/cover_1.jpg`
  static Future<String> uploadUserObject({
    required String relativePath,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) throw StateError('未登录');

    final folder = relativePath.contains('/')
        ? relativePath.substring(0, relativePath.lastIndexOf('/'))
        : 'avatars';
    final fileName = relativePath.contains('/')
        ? relativePath.substring(relativePath.lastIndexOf('/') + 1)
        : relativePath;

    final req = http.MultipartRequest('POST', _uploadUrl())
      ..headers.addAll(await _authHeaders())
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType:
              _parseMediaType(contentType ?? 'application/octet-stream'),
        ),
      );

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    final body = _decodeJson(resp.body);

    if (resp.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? '上传失败 ${resp.statusCode}');
    }
    return body['url'] as String;
  }

  /// 头像：固定路径 `{uid}/avatar.{ext}`，便于覆盖与缓存刷新
  static Future<String> uploadAvatarFile(XFile file) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) throw StateError('未登录');

    final name = file.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    final safeExt =
        ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext) ? ext : 'jpg';
    // 头像固定路径格式：{uid}/avatar.{ext}
    final mime = _mimeForExt(safeExt);
    final bytes = await file.readAsBytes();

    final req = http.MultipartRequest('POST', _uploadUrl())
      ..headers.addAll(await _authHeaders())
      ..fields['folder'] = 'avatars'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'avatar.$safeExt',
          contentType: _parseMediaType(mime),
        ),
      );

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    final body = _decodeJson(resp.body);

    if (resp.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? '上传失败 ${resp.statusCode}');
    }
    return body['url'] as String;
  }

  static String _mimeForExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  static MediaType _parseMediaType(String type) {
    final parts = type.split('/');
    if (parts.length == 2) {
      return MediaType(parts[0], parts[1]);
    }
    return MediaType('application', 'octet-stream');
  }

  static Map<String, dynamic> _decodeJson(String raw) {
    try {
      return raw.isEmpty ? {} : (jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return {};
    }
  }
}
