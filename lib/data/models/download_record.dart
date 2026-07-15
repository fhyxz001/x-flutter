/// 下载记录数据模型
///
/// 对应 Android 端 `DownloadRecord`，使用 `toJson` / `fromJson` 替代
/// kotlinx.serialization。
class DownloadRecord {
  final String id;
  final String title;
  final String thumbnail;
  final String url;
  final String filePath;
  final int downloadedAt;

  DownloadRecord({
    required this.id,
    required this.title,
    this.thumbnail = '',
    required this.url,
    this.filePath = '',
    this.downloadedAt = 0,
  });

  factory DownloadRecord.fromJson(Map<String, dynamic> json) {
    return DownloadRecord(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
      url: json['url'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      downloadedAt: json['downloadedAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'thumbnail': thumbnail,
        'url': url,
        'filePath': filePath,
        'downloadedAt': downloadedAt,
      };
}
