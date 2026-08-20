import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'backend_api_service.dart';
import 'supabase_service.dart';

/// 基于 Next.js 后端上传接口的对象存储封装。
/// 优先使用腾讯云 COS 直传；服务不可用或私有资料需受保护存储时回退 `/api/v1/upload`。
class StorageService {
  StorageService._();

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

    final result = await BackendApiService.uploadFile(
      bytes: bytes,
      filename: fileName,
      contentType: contentType ?? 'application/octet-stream',
      folder: folder,
    );
    final url = result['url']?.toString() ?? '';
    if (url.isEmpty) throw Exception('上传结果缺少文件链接');
    return url;
  }

  /// 头像：固定路径 `{uid}/avatar.{ext}`，便于覆盖与缓存刷新
  static Future<String> uploadAvatarFile(XFile file) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) throw StateError('未登录');

    final name = file.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    final safeExt =
        ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext) ? ext : 'jpg';
    final mime = _mimeForExt(safeExt);
    final bytes = await file.readAsBytes();

    final result = await BackendApiService.uploadFile(
      bytes: bytes,
      filename: 'avatar.$safeExt',
      contentType: mime,
      folder: 'avatars',
    );
    final url = result['url']?.toString() ?? '';
    if (url.isEmpty) throw Exception('上传结果缺少文件链接');
    return url;
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
}
