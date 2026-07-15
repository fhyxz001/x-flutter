/// 媒体项数据模型
///
/// 对应 Android 端 `MediaItem`（注意：Kotlin 中此模型未标注 @Serializable，
/// 仅用于 UI 层；Flutter 端同样仅用于 UI）。
class MediaItem {
  final String id;
  final String url;
  final String thumbnail;
  final String title;
  final int duration;
  final int favorite;
  final int pv;
  int fileSize; // -1 表示未知
  final String tweetUrl;
  final String tweetAccount;

  MediaItem({
    required this.id,
    required this.url,
    required this.thumbnail,
    this.title = '',
    this.duration = 0,
    this.favorite = 0,
    this.pv = 0,
    this.fileSize = -1,
    this.tweetUrl = '',
    this.tweetAccount = '',
  });

  MediaItem copyWith({
    String? id,
    String? url,
    String? thumbnail,
    String? title,
    int? duration,
    int? favorite,
    int? pv,
    int? fileSize,
    String? tweetUrl,
    String? tweetAccount,
  }) {
    return MediaItem(
      id: id ?? this.id,
      url: url ?? this.url,
      thumbnail: thumbnail ?? this.thumbnail,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      favorite: favorite ?? this.favorite,
      pv: pv ?? this.pv,
      fileSize: fileSize ?? this.fileSize,
      tweetUrl: tweetUrl ?? this.tweetUrl,
      tweetAccount: tweetAccount ?? this.tweetAccount,
    );
  }
}
