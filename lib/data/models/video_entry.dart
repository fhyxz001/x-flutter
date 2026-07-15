/// 视频播放入口数据
///
/// 对应 Android 端 `VideoEntry`，用于播放器页面传递视频列表。
class VideoEntry {
  final String id;
  final String src;
  final String poster;
  final String description;

  VideoEntry({
    this.id = '',
    required this.src,
    this.poster = '',
    this.description = '',
  });
}
