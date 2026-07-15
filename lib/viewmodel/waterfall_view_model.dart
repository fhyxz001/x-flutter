import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/models/models.dart';
import '../data/repository/media_repository.dart';
import '../services/notification_service.dart';

/// 主视图模型
///
/// 对应 Android 端 `WaterfallViewModel`，使用 `ChangeNotifier` 替代
/// `AndroidViewModel` + Compose State。
///
/// 负责管理：
/// - 媒体列表加载与状态
/// - 选择模式与批量下载
/// - 单个下载与进度
/// - 文件大小预加载
/// - 缩略图代理预加载
/// - GitHub 更新检查
class WaterfallViewModel extends ChangeNotifier {
  final MediaRepository repo = MediaRepository();
  final NotificationService _notif = NotificationService();

  // ---------------------------------------------------------------------------
  // 状态
  // ---------------------------------------------------------------------------

  List<MediaItem> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  String _loadError = '';
  bool _hasNext = false;
  bool _selectMode = false;
  Set<String> _selectedIds = {};
  Set<String> _downloadedIds = {};
  bool _downloading = false;
  Set<String> _downloadingIds = {};
  Map<String, int> _downloadProgressMap = {};
  bool _showSettings = false;
  String _currentRange = '';

  // 更新检查状态
  bool _checkingUpdate = false;
  String _updateError = '';
  bool _updateDownloading = false;
  int _updateProgress = 0;
  bool _showUpdateDialog = false;
  String _latestVersion = '';
  String _latestApkUrl = '';

  // 内部
  final Map<String, int> _fileSizeCache = {};
  CancelToken? _fileSizeCancelToken;
  CancelToken? _preloadCancelToken;
  CancelToken? _downloadCancelToken;

  WaterfallViewModel() {
    _init();
  }

  Future<void> _init() async {
    await _notif.init();
    // 确保 SharedPreferences 已初始化，然后刷新代理配置
    _downloadedIds = await repo.getDownloadedIds();
    repo.refreshApi();
    notifyListeners();
    loadData();
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  List<MediaItem> get items => _items;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String get loadError => _loadError;
  bool get hasNext => _hasNext;
  bool get selectMode => _selectMode;
  Set<String> get selectedIds => _selectedIds;
  Set<String> get downloadedIds => _downloadedIds;
  bool get downloading => _downloading;
  Set<String> get downloadingIds => _downloadingIds;
  Map<String, int> get downloadProgressMap => _downloadProgressMap;
  bool get showSettings => _showSettings;
  String get currentRange => _currentRange;

  bool get checkingUpdate => _checkingUpdate;
  String get updateError => _updateError;
  bool get updateDownloading => _updateDownloading;
  int get updateProgress => _updateProgress;
  bool get showUpdateDialog => _showUpdateDialog;
  String get latestVersion => _latestVersion;
  String get latestApkUrl => _latestApkUrl;

  // ---------------------------------------------------------------------------
  // 设置面板
  // ---------------------------------------------------------------------------

  void updateShowSettings(bool show) {
    _showSettings = show;
    notifyListeners();
  }

  void refreshProxy() {
    repo.refreshApi();
  }

  // ---------------------------------------------------------------------------
  // 选择模式
  // ---------------------------------------------------------------------------

  void toggleSelectMode() {
    _selectMode = !_selectMode;
    if (!_selectMode) _selectedIds = {};
    notifyListeners();
  }

  void toggleSelect(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds = _selectedIds.where((e) => e != id).toSet();
    } else {
      _selectedIds = {..._selectedIds, id};
    }
    notifyListeners();
  }

  void toggleSelectAll() {
    final allIds = _items.map((e) => e.id).toSet();
    _selectedIds = _selectedIds.containsAll(allIds) ? {} : allIds;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 数据加载
  // ---------------------------------------------------------------------------

  void changeRange(String range) {
    if (range == _currentRange) return;
    _currentRange = range;
    loadData();
  }

  Future<void> loadData() async {
    if (_loading) return;
    _loading = true;
    _loadError = '';
    _selectedIds = {};
    notifyListeners();

    try {
      final result = await repo.fetchMedia(_currentRange);
      _items = result;
      _hasNext = false;
      _preloadThumbnails(result);
      _fetchFileSizes(result);
    } catch (e) {
      _items = [];
      _loadError = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void loadMore() {
    // 单页响应，无需分页
  }

  // ---------------------------------------------------------------------------
  // 文件大小预加载
  // ---------------------------------------------------------------------------

  Future<void> _fetchFileSizes(List<MediaItem> newItems) async {
    _fileSizeCancelToken?.cancel();
    _fileSizeCancelToken = CancelToken();
    final token = _fileSizeCancelToken!;

    final client = repo.buildProxyClient();
    for (final item in newItems) {
      if (token.isCancelled) return;
      if (_fileSizeCache.containsKey(item.id)) {
        _updateItemFileSize(item.id, _fileSizeCache[item.id]!);
        continue;
      }
      try {
        final response = await client.head<void>(
          item.url,
          options: Options(validateStatus: (s) => true),
        );
        final contentLength = response.headers.value('content-length');
        if (contentLength != null) {
          final size = int.tryParse(contentLength) ?? -1;
          if (size > 0) {
            _fileSizeCache[item.id] = size;
            _updateItemFileSize(item.id, size);
          }
        }
      } catch (_) {}
    }
  }

  void _updateItemFileSize(String id, int size) {
    final index = _items.indexWhere((e) => e.id == id);
    if (index != -1) {
      _items[index] = _items[index].copyWith(fileSize: size);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 缩略图代理预加载
  // ---------------------------------------------------------------------------

  Future<void> _preloadThumbnails(List<MediaItem> newItems) async {
    _preloadCancelToken?.cancel();
    _preloadCancelToken = CancelToken();
    final token = _preloadCancelToken!;

    final client = repo.buildProxyClient();
    final cacheDir = Directory('${(await getTemporaryDirectory()).path}/thumbnails');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    for (final item in newItems) {
      if (token.isCancelled) return;
      if (item.thumbnail.isEmpty || !item.thumbnail.startsWith('http')) continue;

      final cacheFile = File('${cacheDir.path}/${item.id}.jpg');
      if (cacheFile.existsSync()) {
        _updateItemThumbnail(item.id, cacheFile.path);
        continue;
      }

      try {
        final response = await client.get<List<int>>(
          item.thumbnail,
          options: Options(responseType: ResponseType.bytes),
        );
        cacheFile.writeAsBytesSync(response.data!);
        _updateItemThumbnail(item.id, cacheFile.path);
      } catch (_) {
        // 保留原始远程 URL
      }
    }
  }

  void _updateItemThumbnail(String id, String localPath) {
    final index = _items.indexWhere((e) => e.id == id);
    if (index != -1) {
      _items[index] = _items[index].copyWith(thumbnail: localPath);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 下载逻辑
  // ---------------------------------------------------------------------------

  /// 执行单个文件下载
  Future<bool> _performDownload({
    required Dio client,
    required String id,
    required String url,
    required String title,
    required String thumbnail,
    required void Function(int percent) onProgress,
  }) async {
    try {
      // 获取保存目录
      final dir = await _getSaveDirectory();
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // 解析文件扩展名
      final path = url.split('?').first.split('#').first;
      final ext = path.contains('.') ? path.split('.').last : 'mp4';
      final safeExt = ext.length > 4 ? 'mp4' : ext;
      final fileName = '$id.$safeExt';
      final savePath = '${dir.path}/$fileName';

      // 下载
      await client.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(((received * 100) / total).toInt());
          }
        },
      );

      // 保存下载记录
      await repo.saveDownloadRecord(DownloadRecord(
        id: id,
        title: title,
        thumbnail: thumbnail,
        url: url,
        filePath: savePath,
        downloadedAt: DateTime.now().millisecondsSinceEpoch,
      ));

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Directory> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      // 尝试获取 Movies 目录，回退到应用文档目录
      try {
        final dirs = await getExternalStorageDirectories(type: StorageDirectory.movies);
        if (dirs != null && dirs.isNotEmpty) {
          return Directory('${dirs.first.path}/TwDownloader');
        }
      } catch (_) {}
    }
    // 回退：应用文档目录
    final docDir = await getApplicationDocumentsDirectory();
    return Directory('${docDir.path}/TwDownloader');
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 13+ 不需要存储权限即可写入应用专用目录
      // Android 12 及以下需要 WRITE_EXTERNAL_STORAGE
      final sdkInt = await _getAndroidSdkInt();
      if (sdkInt >= 30) return true;
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }

  Future<int> _getAndroidSdkInt() async {
    // 简化处理：假设 Android 11+
    return 30;
  }

  /// 批量下载选中项
  Future<void> downloadSelected() async {
    if (_downloading) {
      // 停止下载
      _downloadCancelToken?.cancel();
      _downloading = false;
      _downloadingIds = {};
      _notif.cancel(_notif.batchNotifId);
      notifyListeners();
      return;
    }

    final selected = _items.where((e) => _selectedIds.contains(e.id)).toList();
    if (selected.isEmpty) return;

    await _requestStoragePermission();

    _downloading = true;
    final total = selected.length;
    _downloadingIds = {..._downloadingIds, ...selected.map((e) => e.id)};
    _downloadCancelToken = CancelToken();
    notifyListeners();

    final client = repo.buildProxyClient();
    var completed = 0;
    var failed = 0;

    for (var i = 0; i < selected.length; i++) {
      if (_downloadCancelToken?.isCancelled ?? false) break;
      final item = selected[i];
      final fileIndex = i + 1;
      _notif.showBatchProgress(fileIndex, total, 0);

      final success = await _performDownload(
        client: client,
        id: item.id,
        url: item.url,
        title: item.title,
        thumbnail: item.thumbnail,
        onProgress: (percent) {
          _notif.showBatchProgress(fileIndex, total, percent);
        },
      );

      if (success) {
        completed++;
        _downloadedIds = {..._downloadedIds, item.id};
      } else {
        failed++;
      }
      _downloadingIds = _downloadingIds.where((e) => e != item.id).toSet();
      notifyListeners();
    }

    _downloading = false;
    _selectedIds = {};
    notifyListeners();

    _notif.showCompletion(
      _notif.batchNotifId,
      failed == 0 ? '下载完成 ($completed 个文件)' : '下载完成 ($completed 成功, $failed 失败)',
    );
  }

  /// 下载单个视频
  Future<void> downloadSingle(VideoEntry entry) async {
    if (entry.id.isEmpty || entry.src.isEmpty) return;
    if (_downloadingIds.contains(entry.id) || _downloadedIds.contains(entry.id)) return;

    await _requestStoragePermission();

    _downloadingIds = {..._downloadingIds, entry.id};
    _downloadProgressMap = {..._downloadProgressMap, entry.id: 0};
    notifyListeners();

    final client = repo.buildProxyClient();
    final notifId = _notif.singleNotifId(entry.id);

    _notif.showSingleProgress(notifId, entry.description, 0);

    final success = await _performDownload(
      client: client,
      id: entry.id,
      url: entry.src,
      title: entry.description,
      thumbnail: entry.poster,
      onProgress: (percent) {
        _notif.showSingleProgress(notifId, entry.description, percent);
        _downloadProgressMap = {..._downloadProgressMap, entry.id: percent};
        notifyListeners();
      },
    );

    if (success) {
      _downloadedIds = {..._downloadedIds, entry.id};
      _notif.showCompletion(notifId, '下载完成: ${entry.description.length > 30 ? entry.description.substring(0, 30) : entry.description}');
    } else {
      _notif.showCompletion(notifId, '下载失败: ${entry.description.length > 30 ? entry.description.substring(0, 30) : entry.description}');
    }

    _downloadingIds = _downloadingIds.where((e) => e != entry.id).toSet();
    _downloadProgressMap = Map.fromEntries(
      _downloadProgressMap.entries.where((e) => e.key != entry.id),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 更新检查
  // ---------------------------------------------------------------------------

  void dismissUpdateDialog() {
    _showUpdateDialog = false;
    _updateError = '';
    notifyListeners();
  }

  Future<void> checkUpdate() async {
    if (_checkingUpdate || _updateDownloading) return;
    _checkingUpdate = true;
    _updateError = '';
    notifyListeners();

    try {
      final client = repo.buildProxyClient();
      final response = await client.get<String>(
        'https://api.github.com/repos/fhyxz001/twAndroid/releases/latest',
        options: Options(headers: {'Accept': 'application/json'}),
      );

      final release = jsonDecode(response.data!) as Map<String, dynamic>;
      final tagName = release['tag_name'] as String? ?? '';
      final assets = release['assets'] as List<dynamic>? ?? [];
      final apkAsset = assets.firstWhere(
        (a) => (a['name'] as String?)?.endsWith('.apk') ?? false,
        orElse: () => null,
      );

      if (apkAsset == null) {
        throw Exception('未找到 APK 下载文件');
      }

      final apkUrl = apkAsset['browser_download_url'] as String;
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Tag 格式: "v{DATE}-{SHA}"；versionName (CI) = "{DATE}"
      final releaseDate = tagName.startsWith('v')
          ? tagName.substring(1).split('-').first
          : tagName.split('-').first;

      _latestVersion = tagName;
      _latestApkUrl = releaseDate == currentVersion ? '' : apkUrl;
      _showUpdateDialog = true;
    } catch (e) {
      _updateError = e.toString();
      _latestVersion = '';
      _latestApkUrl = '';
      _showUpdateDialog = true;
    } finally {
      _checkingUpdate = false;
      notifyListeners();
    }
  }

  Future<void> downloadUpdate() async {
    if (_latestApkUrl.isEmpty || _updateDownloading) return;
    _updateDownloading = true;
    _updateProgress = 0;
    notifyListeners();

    try {
      final client = repo.buildProxyClient();
      final downloadDir = await getDownloadsDirectory();
      if (downloadDir == null) throw Exception('无法获取下载目录');

      final fileName = 'X下载器-$_latestVersion.apk';
      final savePath = '${downloadDir.path}/$fileName';

      await client.download(
        _latestApkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _updateProgress = ((received * 100) / total).toInt();
            notifyListeners();
          }
        },
      );

      _updateProgress = 100;
      _showUpdateDialog = false;
      _notif.showCompletion(_notif.singleNotifId('update'), '更新包已下载: $fileName');
    } catch (e) {
      _updateError = e.toString();
    } finally {
      _updateDownloading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 缓存管理
  // ---------------------------------------------------------------------------

  Future<String> calcCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalBytes = 0;
      if (tempDir.existsSync()) {
        for (final entity in tempDir.listSync(recursive: true)) {
          if (entity is File) {
            totalBytes += entity.lengthSync();
          }
        }
      }
      final kb = totalBytes / 1024.0;
      final mb = kb / 1024.0;
      if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
      if (kb >= 1) return '${kb.toStringAsFixed(0)} KB';
      return '$totalBytes B';
    } catch (_) {
      return '0 B';
    }
  }

  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
        tempDir.createSync(recursive: true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _fileSizeCancelToken?.cancel();
    _preloadCancelToken?.cancel();
    _downloadCancelToken?.cancel();
    super.dispose();
  }
}
