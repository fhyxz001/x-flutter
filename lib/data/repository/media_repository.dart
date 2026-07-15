import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// 媒体数据仓库
///
/// 对应 Android 端 `MediaRepository`，负责：
/// - 通过 pektino.com Next.js RSC payload 获取媒体列表
/// - 管理下载记录（SharedPreferences 持久化）
/// - 管理代理配置（SharedPreferences 持久化）
class MediaRepository {
  static const String _baseUrl = 'https://pektino.com/zh-CN';
  static const String _defaultUa =
      'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Mobile Safari/537.36';
  static const String _rscStateTree =
      '%5B%22%22%2C%7B%22children%22%3A%5B%22%5Blang%5D%22%2C%7B%22children%22'
      '%3A%5B%22__PAGE__%22%2C%7B%7D%5D%7D%5D%7D%2Cnull%2Cnull%2Ctrue%5D';

  static const String _prefsKeyDownloadRecords = 'download_records';
  static const String _prefsKeyProxyConfig = 'proxy_config';

  late Dio _dio;
  SharedPreferences? _prefs;

  MediaRepository() {
    _dio = _buildClient();
  }

  // ---------------------------------------------------------------------------
  // 网络客户端
  // ---------------------------------------------------------------------------

  /// 根据当前代理配置重建 Dio 实例。
  Dio _buildClient() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: true,
      validateStatus: (status) => status != null && status < 400,
    ));

    // 配置代理
    final config = getProxyConfig();
    if (config.enabled && config.selectedId.isNotEmpty) {
      final matching = config.schemes.where((s) => s.id == config.selectedId);
      if (matching.isNotEmpty) {
        final scheme = matching.first;
        dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient();
            client.findProxy = (uri) => 'PROXY ${scheme.host}:${scheme.port}';
            client.badCertificateCallback = (cert, host, port) => true;
            return client;
          },
        );
      }
    }

    return dio;
  }

  /// 代理配置变更后刷新 HTTP 客户端。
  void refreshApi() {
    _dio.close();
    _dio = _buildClient();
  }

  /// 获取一个配置了代理的 Dio 实例（供 ViewModel 下载使用）。
  Dio buildProxyClient() => _buildClient();

  // ---------------------------------------------------------------------------
  // 媒体列表获取
  // ---------------------------------------------------------------------------

  /// 从 pektino.com 获取媒体列表。
  ///
  /// [range] 取值："" 日榜, "weekly" 周榜, "monthly" 月榜, "all" 总榜。
  Future<List<MediaItem>> fetchMedia(String range) async {
    final path = range.isEmpty ? _baseUrl : '$_baseUrl/$range';
    final url = '$path?_rsc=1q2w3';

    final response = await _dio.get<String>(
      url,
      options: Options(
        headers: {
          'User-Agent': _defaultUa,
          'Accept': 'text/x-component',
          'RSC': '1',
          'Next-Router-State-Tree': _rscStateTree,
        },
        responseType: ResponseType.plain,
      ),
    );

    final body = response.data ?? '';
    return _parseRscPayload(body);
  }

  /// 解析 Next.js RSC payload，提取 `initialItems` JSON 数组。
  ///
  /// payload 是流式文本格式，通过搜索 `"initialItems":[` 并追踪括号深度
  /// 来提取完整 JSON 数组。
  List<MediaItem> _parseRscPayload(String body) {
    const prefix = '"initialItems":';
    final startIdx = body.indexOf(prefix);
    if (startIdx == -1) {
      throw Exception('initialItems not found in RSC payload');
    }

    var idx = startIdx + prefix.length;
    // 跳过空白
    while (idx < body.length && body[idx] == ' ') {
      idx++;
    }
    if (idx >= body.length || body[idx] != '[') {
      throw Exception("Expected '[' after initialItems:");
    }

    var depth = 0;
    final sb = StringBuffer();
    while (idx < body.length) {
      final ch = body[idx];
      sb.write(ch);
      switch (ch) {
        case '[':
          depth++;
        case ']':
          depth--;
          if (depth == 0) break;
        case '"':
          // 跳过字符串内容（处理转义）
          idx++;
          while (idx < body.length) {
            final c = body[idx];
            sb.write(c);
            if (c == r'\') {
              idx++;
              if (idx < body.length) sb.write(body[idx]);
            } else if (c == '"') {
              break;
            }
            idx++;
          }
      }
      if (depth == 0 && ch == ']') break;
      idx++;
    }

    if (depth != 0) {
      throw Exception('Unclosed initialItems array');
    }

    final itemsJson = sb.toString();
    final List<dynamic> rscItems = jsonDecode(itemsJson) as List<dynamic>;

    return rscItems.map((raw) {
      final item = raw as Map<String, dynamic>;
      final id = (item['url_cd'] as String?)?.isNotEmpty == true
          ? item['url_cd'] as String
          : (item['id'] ?? 0).toString();
      return MediaItem(
        id: id,
        url: (item['url'] ?? '') as String,
        thumbnail: (item['thumbnail'] ?? '') as String,
        title: (item['tweet_account'] ?? '') as String,
        duration: (item['time'] ?? 0) as int,
        favorite: int.tryParse((item['favorite'] ?? '0').toString()) ?? 0,
        pv: int.tryParse((item['pv'] ?? '0').toString()) ?? 0,
        tweetUrl: (item['tweet_url'] ?? '') as String,
        tweetAccount: (item['tweet_account'] ?? '') as String,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 下载记录
  // ---------------------------------------------------------------------------

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<List<DownloadRecord>> getDownloadRecords() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_prefsKeyDownloadRecords);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => DownloadRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDownloadRecord(DownloadRecord record) async {
    final prefs = await _getPrefs();
    final records = await getDownloadRecords();
    records.insert(0, record);
    await prefs.setString(
      _prefsKeyDownloadRecords,
      jsonEncode(records.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteDownloadRecords(Set<int> indices) async {
    final prefs = await _getPrefs();
    final records = await getDownloadRecords();
    final sorted = indices.toList()..sort((a, b) => b.compareTo(a));
    for (final i in sorted) {
      if (i >= 0 && i < records.length) {
        records.removeAt(i);
      }
    }
    await prefs.setString(
      _prefsKeyDownloadRecords,
      jsonEncode(records.map((e) => e.toJson()).toList()),
    );
  }

  Future<Set<String>> getDownloadedIds() async {
    final records = await getDownloadRecords();
    return records.map((e) => e.id).toSet();
  }

  // ---------------------------------------------------------------------------
  // 代理配置
  // ---------------------------------------------------------------------------

  ProxyConfig getProxyConfig() {
    // 同步读取缓存中的 prefs
    final prefs = _prefs;
    if (prefs == null) return ProxyConfig();
    final raw = prefs.getString(_prefsKeyProxyConfig);
    if (raw == null) return ProxyConfig();
    try {
      return ProxyConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ProxyConfig();
    }
  }

  Future<ProxyConfig> getProxyConfigAsync() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_prefsKeyProxyConfig);
    if (raw == null) return ProxyConfig();
    try {
      return ProxyConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ProxyConfig();
    }
  }

  Future<void> saveProxyConfig(ProxyConfig config) async {
    final prefs = await _getPrefs();
    await prefs.setString(
      _prefsKeyProxyConfig,
      jsonEncode(config.toJson()),
    );
  }
}
