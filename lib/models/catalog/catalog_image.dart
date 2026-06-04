/// Image reference for catalog products and variants.
class CatalogImage {
  const CatalogImage({
    this.url,
    this.thumbUrl,
    this.localPath,
    this.sha256,
    this.sizeBytes,
  });

  final String? url;
  final String? thumbUrl;
  final String? localPath;
  final String? sha256;
  final int? sizeBytes;

  bool get hasRemoteUrl => url != null && url!.isNotEmpty;

  bool get hasLocalPath => localPath != null && localPath!.isNotEmpty;

  factory CatalogImage.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const CatalogImage();
    return CatalogImage(
      url: map['url'] as String?,
      thumbUrl: map['thumbUrl'] as String?,
      localPath: map['localPath'] as String?,
      sha256: map['sha256'] as String?,
      sizeBytes: map['sizeBytes'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
        if (url != null) 'url': url,
        if (thumbUrl != null) 'thumbUrl': thumbUrl,
        if (localPath != null) 'localPath': localPath,
        if (sha256 != null) 'sha256': sha256,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
      };
}
