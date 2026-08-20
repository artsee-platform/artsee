import 'package:flutter/foundation.dart';

enum ImmersiveAssetType {
  gaussian,
  spin360,
  glb,
  unknown,
}

enum ImmersiveAssetStatus {
  processing,
  review,
  published,
  failed,
  unknown,
}

/// A curated interactive media asset attached to an artwork or marketplace item.
///
/// The first production renderer supports Gaussian splats. The shared contract
/// intentionally leaves room for image spins and GLB assets without changing
/// the marketplace post schema.
@immutable
class ImmersiveAsset {
  final String id;
  final ImmersiveAssetType type;
  final ImmersiveAssetStatus status;
  final String assetUrl;
  final String? viewerUrl;
  final String? posterUrl;
  final String? title;
  final String? credits;
  final String? sourceUrl;
  final String? licenseName;
  final String? licenseUrl;
  final List<double> cameraPosition;
  final List<double> modelPosition;
  final List<double> modelRotation;

  const ImmersiveAsset({
    required this.id,
    required this.type,
    required this.status,
    required this.assetUrl,
    this.viewerUrl,
    this.posterUrl,
    this.title,
    this.credits,
    this.sourceUrl,
    this.licenseName,
    this.licenseUrl,
    this.cameraPosition = const [0, 0, 2.5],
    this.modelPosition = const [0, 0, 0],
    this.modelRotation = const [0, 0, 0],
  });

  bool get isPublished => status == ImmersiveAssetStatus.published;

  bool get isViewable =>
      isPublished &&
      type == ImmersiveAssetType.gaussian &&
      _isSupportedAssetUrl(assetUrl);

  static ImmersiveAsset? fromMetadata(Map<String, dynamic> metadata) {
    final raw = metadata['immersive_asset'] ?? metadata['immersiveAsset'];
    if (raw is! Map) return null;
    return fromJson(Map<String, dynamic>.from(raw));
  }

  static ImmersiveAsset? fromJson(Map<String, dynamic> json) {
    final assetUrl = _text(
      json['asset_url'] ?? json['assetUrl'] ?? json['content_url'],
    );
    final id = _text(json['id']);
    final type = _assetType(json['type'] ?? json['asset_type']);
    final status = _assetStatus(json['status']);
    if (assetUrl == null || type == ImmersiveAssetType.unknown) return null;

    return ImmersiveAsset(
      id: id ?? assetUrl,
      type: type,
      status: status,
      assetUrl: assetUrl,
      viewerUrl: _text(json['viewer_url'] ?? json['viewerUrl']),
      posterUrl: _text(
        json['poster_url'] ?? json['posterUrl'] ?? json['cover_url'],
      ),
      title: _text(json['title']),
      credits: _text(json['credits'] ?? json['credit']),
      sourceUrl: _text(json['source_url'] ?? json['sourceUrl']),
      licenseName: _text(json['license_name'] ?? json['licenseName']),
      licenseUrl: _text(json['license_url'] ?? json['licenseUrl']),
      cameraPosition: _vector3(
        json['camera_position'] ?? json['cameraPosition'],
        const [0, 0, 2.5],
      ),
      modelPosition: _vector3(
        json['model_position'] ?? json['modelPosition'],
        const [0, 0, 0],
      ),
      modelRotation: _vector3(
        json['model_rotation'] ?? json['modelRotation'],
        const [0, 0, 0],
      ),
    );
  }

  Uri buildViewerUri({
    required Uri viewerBaseUri,
    String? fallbackTitle,
    String? fallbackPosterUrl,
  }) {
    final customViewerUrl = viewerUrl;
    if (customViewerUrl != null) {
      final customUri = Uri.tryParse(customViewerUrl);
      if (customUri != null &&
          (customUri.scheme == 'https' || customUri.scheme == 'http')) {
        return customUri;
      }
    }

    return viewerBaseUri.replace(
      queryParameters: {
        ...viewerBaseUri.queryParameters,
        'asset': assetUrl,
        if ((title ?? fallbackTitle)?.trim().isNotEmpty == true)
          'title': (title ?? fallbackTitle)!.trim(),
        if ((posterUrl ?? fallbackPosterUrl)?.trim().isNotEmpty == true)
          'poster': (posterUrl ?? fallbackPosterUrl)!.trim(),
        'camera': _formatVector(cameraPosition),
        'position': _formatVector(modelPosition),
        'rotation': _formatVector(modelRotation),
      },
    );
  }

  static String? _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static ImmersiveAssetType _assetType(dynamic value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'gaussian' ||
      'gaussian_splat' ||
      '3dgs' ||
      'sog' =>
        ImmersiveAssetType.gaussian,
      'spin360' || 'spin_360' || '360' => ImmersiveAssetType.spin360,
      'glb' || 'gltf' || 'mesh' => ImmersiveAssetType.glb,
      _ => ImmersiveAssetType.unknown,
    };
  }

  static ImmersiveAssetStatus _assetStatus(dynamic value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'published' || 'ready' => ImmersiveAssetStatus.published,
      'processing' || 'queued' => ImmersiveAssetStatus.processing,
      'review' || 'reviewing' => ImmersiveAssetStatus.review,
      'failed' || 'rejected' => ImmersiveAssetStatus.failed,
      _ => ImmersiveAssetStatus.unknown,
    };
  }

  static List<double> _vector3(dynamic value, List<double> fallback) {
    final values = value is List
        ? value
        : value
            ?.toString()
            .trim()
            .split(RegExp(r'[\s,]+'))
            .where((part) => part.isNotEmpty)
            .toList();
    if (values is! List || values.length != 3) return fallback;
    final parsed = values
        .map((item) => double.tryParse(item.toString()))
        .toList(growable: false);
    if (parsed.any((item) => item == null || !item.isFinite)) return fallback;
    return List<double>.unmodifiable(parsed.cast<double>());
  }

  static bool _isSupportedAssetUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    if (!uri.hasScheme) return value.startsWith('/');
    return uri.scheme == 'https' || uri.scheme == 'http';
  }

  static String _formatVector(List<double> values) => values
      .map((value) => value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString())
      .join(' ');
}
