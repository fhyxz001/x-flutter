import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../utils/formatters.dart';
import '../../viewmodel/waterfall_view_model.dart';
import '../theme/app_colors.dart';
import '../components/settings_sheet.dart';

/// 主屏幕 - 瀑布流
///
/// 对应 Android 端 `WaterfallScreen.kt`，包含：
/// - 顶部导航栏（标题 + 选择/代理/设置/刷新按钮）
/// - 排行榜标签栏（日榜/周榜/月榜/总榜）
/// - 瀑布流网格媒体卡片列表
/// - 选择模式底部工具栏
/// - 加载/错误/空状态
class WaterfallScreen extends StatefulWidget {
  final VoidCallback onNavigateToProxy;
  final void Function(List<MediaItem> items, int index) onNavigateToPlayer;

  const WaterfallScreen({
    super.key,
    required this.onNavigateToProxy,
    required this.onNavigateToPlayer,
  });

  @override
  State<WaterfallScreen> createState() => _WaterfallScreenState();
}

class _WaterfallScreenState extends State<WaterfallScreen> {
  @override
  void initState() {
    super.initState();
    // 进入时刷新代理
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WaterfallViewModel>().refreshProxy();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WaterfallViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildNavBar(vm),
            _buildRankingTabs(vm),
            if (vm.loading && vm.items.isNotEmpty)
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            Expanded(child: _buildContent(vm)),
            if (vm.selectMode) _buildSelectionToolbar(vm),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 导航栏
  // -------------------------------------------------------------------------

  Widget _buildNavBar(WaterfallViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '探索',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
          Row(
            children: [
              _NavButton(
                icon: Icon(
                  vm.selectMode ? Icons.check_box : Icons.check_box_outline_blank,
                  color: vm.selectMode ? AppColors.accent : AppColors.textSecondary,
                  size: 22,
                ),
                onTap: vm.toggleSelectMode,
              ),
              _NavButton(
                icon: const Icon(Icons.vpn_key, color: AppColors.textSecondary, size: 22),
                onTap: widget.onNavigateToProxy,
              ),
              _NavButton(
                icon: const Icon(Icons.settings, color: AppColors.textSecondary, size: 22),
                onTap: () => vm.updateShowSettings(true),
              ),
              _NavButton(
                icon: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 22),
                onTap: vm.loadData,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 排行榜标签
  // -------------------------------------------------------------------------

  Widget _buildRankingTabs(WaterfallViewModel vm) {
    const tabs = [
      ('', '日榜'),
      ('weekly', '周榜'),
      ('monthly', '月榜'),
      ('all', '总榜'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = vm.currentRange == tab.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => vm.changeRange(tab.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.border,
                    width: isSelected ? 0 : 0.5,
                  ),
                ),
                child: Text(
                  tab.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.background : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 内容区域
  // -------------------------------------------------------------------------

  Widget _buildContent(WaterfallViewModel vm) {
    if (vm.loading && vm.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '加载中...',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (vm.loadError.isNotEmpty && vm.items.isEmpty) {
      return Center(
        child: Text(
          vm.loadError,
          style: const TextStyle(color: AppColors.error, fontSize: 14),
        ),
      );
    }

    if (vm.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📹', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              '暂无内容',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '下拉刷新重试',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: vm.items.length + 1,
      itemBuilder: (context, index) {
        if (index < vm.items.length) {
          final item = vm.items[index];
          return _MediaCard(
            item: item,
            selectMode: vm.selectMode,
            isSelected: vm.selectedIds.contains(item.id),
            isDownloaded: vm.downloadedIds.contains(item.id),
            onTap: () {
              if (vm.selectMode) {
                vm.toggleSelect(item.id);
              } else {
                widget.onNavigateToPlayer(vm.items, index);
              }
            },
          );
        }
        // 底部提示
        if (vm.loadingMore) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                ),
                const SizedBox(height: 6),
                Text(
                  '加载更多...',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              '-- 已经到底了 --',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // 选择模式工具栏
  // -------------------------------------------------------------------------

  Widget _buildSelectionToolbar(WaterfallViewModel vm) {
    final isAllSelected = vm.items.isNotEmpty &&
        vm.items.every((e) => vm.selectedIds.contains(e.id));
    final canDownload = vm.selectedIds.isNotEmpty || vm.downloading;

    return SafeArea(
      top: false,
      child: Container(
        color: AppColors.surface.withValues(alpha: 0.95),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: vm.toggleSelectMode,
              child: Text(
                '取消',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(width: 0.5, height: 16, color: AppColors.border),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: vm.toggleSelectAll,
              child: Text(
                isAllSelected ? '取消全选' : '全选',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '已选 ${vm.selectedIds.length} 项',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: canDownload ? vm.downloadSelected : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  color: canDownload
                      ? AppColors.accent
                      : AppColors.textTertiary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  vm.downloading ? '停止' : '下载',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.background,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 导航按钮
// -----------------------------------------------------------------------------

class _NavButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          alignment: Alignment.center,
          child: icon,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 媒体卡片
// -----------------------------------------------------------------------------

class _MediaCard extends StatelessWidget {
  final MediaItem item;
  final bool selectMode;
  final bool isSelected;
  final bool isDownloaded;
  final VoidCallback onTap;

  const _MediaCard({
    required this.item,
    required this.selectMode,
    required this.isSelected,
    required this.isDownloaded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectMode && isSelected ? AppColors.accent : AppColors.border,
            width: selectMode && isSelected ? 2 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPoster(),
            _buildStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildPoster() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Stack(
        children: [
          // 缩略图
          SizedBox(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            child: item.thumbnail.isNotEmpty
                ? _buildThumbnail()
                : Container(
                    height: 160,
                    color: AppColors.surfaceVariant,
                    alignment: Alignment.center,
                    child: Text(
                      '▶',
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
          ),
          // 已下载标记
          if (isDownloaded)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                Icons.check_circle,
                color: AppColors.accent,
                size: 20,
              ),
            ),
          // 选择标记
          if (selectMode)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.accent : Colors.black.withValues(alpha: 0.3),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.9),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? Text(
                        '✓',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.background,
                        ),
                      )
                    : null,
              ),
            ),
          // 播放按钮
          if (item.url.isNotEmpty)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.play_arrow,
                  color: AppColors.accent,
                  size: 16,
                ),
              ),
            ),
          // 文件大小
          if (item.fileSize > 0)
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  formatFileSize(item.fileSize),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    // 本地文件路径
    if (item.thumbnail.startsWith('/') || item.thumbnail.startsWith('file:')) {
      final path = item.thumbnail.startsWith('file:')
          ? item.thumbnail.substring(5)
          : item.thumbnail;
      return Image.file(
        File(path),
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) => Container(
          height: 160,
          color: AppColors.surfaceVariant,
          alignment: Alignment.center,
          child: Text(
            '▶',
            style: TextStyle(fontSize: 32, color: Colors.white.withValues(alpha: 0.25)),
          ),
        ),
      );
    }
    // 远程 URL
    return Image.network(
      item.thumbnail,
      fit: BoxFit.fitWidth,
      errorBuilder: (_, __, ___) => Container(
        height: 160,
        color: AppColors.surfaceVariant,
        alignment: Alignment.center,
        child: Text(
          '▶',
          style: TextStyle(fontSize: 32, color: Colors.white.withValues(alpha: 0.25)),
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          if (item.pv > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '热度 ${formatCount(item.pv)}',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          if (item.favorite > 0)
            Text(
              '♥ ${formatCount(item.favorite)}',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
