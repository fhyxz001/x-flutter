import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/models.dart';
import '../viewmodel/waterfall_view_model.dart';
import '../ui/screens/waterfall_screen.dart';
import '../ui/screens/player_screen.dart';
import '../ui/screens/proxy_screen.dart';
import '../ui/screens/proxy_edit_screen.dart';

/// 路由名称常量
///
/// 对应 Android 端 `Routes` object。
class Routes {
  static const String waterfall = 'waterfall';
  static const String player = 'player';
  static const String proxy = 'proxy';
  static const String proxyEdit = 'proxy_edit';
}

/// 路由配置
///
/// 对应 Android 端 `TwNavGraph`，使用 `go_router` 替代 Navigation Compose。
GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/${Routes.waterfall}',
    routes: [
      GoRoute(
        path: '/${Routes.waterfall}',
        name: Routes.waterfall,
        builder: (context, state) {
          final vm = context.read<WaterfallViewModel>();
          return WaterfallScreen(
            onNavigateToProxy: () => context.push('/${Routes.proxy}'),
            onNavigateToPlayer: (items, index) {
              final videos = items
                  .map((e) => VideoEntry(
                        id: e.id,
                        src: e.url,
                        poster: e.thumbnail,
                        description: e.title,
                      ))
                  .toList();
              context.push('/${Routes.player}', extra: {
                'videos': videos,
                'index': index,
              });
            },
          );
        },
      ),
      GoRoute(
        path: '/${Routes.player}',
        name: Routes.player,
        builder: (context, state) {
          final vm = context.watch<WaterfallViewModel>();
          final extra = state.extra as Map<String, dynamic>?;
          final videos = extra?['videos'] as List<VideoEntry>? ?? [];
          final index = extra?['index'] as int? ?? 0;
          return PlayerScreen(
            videos: videos,
            initialIndex: index,
            onBack: () => context.pop(),
            onDownload: (entry) => vm.downloadSingle(entry),
            downloadingIds: vm.downloadingIds,
            downloadProgressMap: vm.downloadProgressMap,
            downloadedIds: vm.downloadedIds,
          );
        },
      ),
      GoRoute(
        path: '/${Routes.proxy}',
        name: Routes.proxy,
        builder: (context, state) {
          final vm = context.read<WaterfallViewModel>();
          return ProxyScreen(
            repo: vm.repo,
            onBack: () => context.pop(),
            onEditScheme: (scheme) async {
              await context.push('/${Routes.proxyEdit}', extra: scheme);
            },
          );
        },
      ),
      GoRoute(
        path: '/${Routes.proxyEdit}',
        name: Routes.proxyEdit,
        builder: (context, state) {
          final vm = context.read<WaterfallViewModel>();
          final scheme = state.extra as ProxyScheme?;
          return ProxyEditScreen(
            scheme: scheme,
            onBack: () => context.pop(),
            onSave: (saved) async {
              final config = await vm.repo.getProxyConfigAsync();
              final newSchemes = scheme != null
                  ? config.schemes.map((s) => s.id == saved.id ? saved : s).toList()
                  : [...config.schemes, saved];
              final newSelected = config.selectedId.isEmpty && newSchemes.length == 1
                  ? saved.id
                  : config.selectedId;
              await vm.repo.saveProxyConfig(
                config.copyWith(schemes: newSchemes, selectedId: newSelected),
              );
              vm.repo.refreshApi();
              if (context.mounted) context.pop();
            },
          );
        },
      ),
    ],
  );
}
