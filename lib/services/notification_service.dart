import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 通知服务
///
/// 对应 Android 端 `TwApp` 中的通知渠道管理和 `WaterfallViewModel` 中的
/// 通知发送逻辑。
class NotificationService {
  static const String _channelDownload = 'downloads';
  static const int _notifBatch = 1001;
  static const int _notifSingle = 1002;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/logo');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);

    // 创建下载通知渠道
    const androidChannel = AndroidNotificationChannel(
      _channelDownload,
      '下载',
      description: '下载进度通知',
      importance: Importance.low,
      showBadge: false,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
  }

  /// 批量下载进度通知
  void showBatchProgress(int current, int total, int percent) {
    _showProgress(
      id: _notifBatch,
      title: '下载中 ($current/$total)',
      body: '$percent%',
      percent: percent,
    );
  }

  /// 单个下载进度通知
  void showSingleProgress(int notifId, String title, int percent) {
    _showProgress(
      id: notifId,
      title: '下载中',
      body: title,
      percent: percent,
    );
  }

  /// 下载完成通知
  void showCompletion(int notifId, String text) {
    _show(
      id: notifId,
      title: text,
      body: '',
      ongoing: false,
      autoCancel: true,
      smallIcon: '@android:drawable/stat_sys_download_done',
    );
  }

  /// 取消通知
  void cancel(int id) {
    _plugin.cancel(id);
  }

  void _showProgress({
    required int id,
    required String title,
    required String body,
    required int percent,
  }) {
    _show(
      id: id,
      title: title,
      body: body,
      ongoing: true,
      autoCancel: false,
      smallIcon: '@android:drawable/stat_sys_download',
      showProgress: true,
      percent: percent,
    );
  }

  void _show({
    required int id,
    required String title,
    required String body,
    bool ongoing = false,
    bool autoCancel = false,
    String smallIcon = '@android:drawable/stat_sys_download',
    bool showProgress = false,
    int percent = 0,
  }) {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      _channelDownload,
      '下载',
      channelDescription: '下载进度通知',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: ongoing,
      autoCancel: autoCancel,
      silent: true,
      onlyAlertOnce: true,
      showProgress: showProgress,
      maxProgress: 100,
      progress: percent,
      icon: smallIcon,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    _plugin.show(id, title, body.isEmpty ? null : body, details);
  }

  int singleNotifId(String entryId) => _notifSingle + entryId.hashCode;
  int get batchNotifId => _notifBatch;
}
