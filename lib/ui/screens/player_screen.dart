import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../data/models/models.dart';
import '../theme/app_colors.dart';

/// 播放器屏幕
///
/// 对应 Android 端 `PlayerScreen.kt`，使用 `chewie` + `video_player`
/// 替代 ExoPlayer + PlayerView。
class PlayerScreen extends StatefulWidget {
  final List<VideoEntry> videos;
  final int initialIndex;
  final VoidCallback onBack;
  final void Function(VideoEntry entry) onDownload;
  final Set<String> downloadingIds;
  final Map<String, int> downloadProgressMap;
  final Set<String> downloadedIds;

  const PlayerScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
    required this.onBack,
    required this.onDownload,
    this.downloadingIds = const {},
    this.downloadProgressMap = const {},
    this.downloadedIds = const {},
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late int _currentIndex;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.videos.length - 1);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (widget.videos.isEmpty) return;
    final entry = widget.videos[_currentIndex];

    _videoController = VideoPlayerController.networkUrl(Uri.parse(entry.src));
    await _videoController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.accent,
        handleColor: AppColors.accent,
        bufferedColor: AppColors.accent.withValues(alpha: 0.3),
        backgroundColor: AppColors.surfaceVariant,
      ),
    );

    if (mounted) setState(() {});
  }

  void _switchVideo(int index) {
    if (index < 0 || index >= widget.videos.length) return;
    setState(() => _currentIndex = index);
    _chewieController?.dispose();
    _videoController?.dispose();
    _initPlayer();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
      if (_isLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentEntry = _currentIndex < widget.videos.length
        ? widget.videos[_currentIndex]
        : null;
    final isDownloading = currentEntry != null && widget.downloadingIds.contains(currentEntry.id);
    final isDownloaded = currentEntry != null && widget.downloadedIds.contains(currentEntry.id);
    final progress = currentEntry != null ? widget.downloadProgressMap[currentEntry.id] : null;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // 视频播放器
              if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: Chewie(controller: _chewieController!),
                  ),
                )
              else
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  ),
                ),

              // 下载进度条
              if (isDownloading && progress != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: Colors.black.withValues(alpha: 0.7),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '下载中...',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              '$progress%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress / 100.0,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 返回按钮
              Positioned(
                top: 6,
                left: 12,
                child: GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // 右侧控制按钮
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ControlButton(
                      icon: Icons.keyboard_arrow_up,
                      iconSize: 32,
                      enabled: _currentIndex > 0,
                      onTap: () => _switchVideo(_currentIndex - 1),
                    ),
                    const SizedBox(height: 16),
                    _ControlButton(
                      icon: Icons.keyboard_arrow_down,
                      iconSize: 32,
                      enabled: _currentIndex < widget.videos.length - 1,
                      onTap: () => _switchVideo(_currentIndex + 1),
                    ),
                    const SizedBox(height: 16),
                    _ControlButton(
                      icon: Icons.screen_rotation,
                      iconSize: 24,
                      enabled: true,
                      onTap: _toggleOrientation,
                    ),
                    const SizedBox(height: 16),
                    _ControlButton(
                      icon: isDownloaded ? Icons.check_circle : Icons.download,
                      iconSize: 24,
                      enabled: currentEntry != null &&
                          currentEntry.src.isNotEmpty &&
                          !isDownloading &&
                          !isDownloaded,
                      onTap: () {
                        if (currentEntry != null) widget.onDownload(currentEntry);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final bool enabled;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.iconSize,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: enabled ? 0.4 : 0.2),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: AppColors.accent.withValues(alpha: enabled ? 1.0 : 0.5),
          size: iconSize,
        ),
      ),
    );
  }
}
