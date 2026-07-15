import 'package:flutter/material.dart';

import '../../viewmodel/waterfall_view_model.dart';
import '../theme/app_colors.dart';

/// 设置底部弹窗
///
/// 对应 Android 端 `SettingsSheet.kt`，包含：
/// - 检查更新
/// - 清除缓存
class SettingsSheet extends StatefulWidget {
  final WaterfallViewModel vm;

  const SettingsSheet({super.key, required this.vm});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  String _cacheSize = '';
  bool _showClearDialog = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final size = await widget.vm.calcCacheSize();
    if (mounted) setState(() => _cacheSize = size);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;

    return Stack(
      children: [
        _buildBottomSheet(vm),
        if (vm.showUpdateDialog) _buildUpdateDialog(vm),
        if (_showClearDialog) _buildClearCacheDialog(),
      ],
    );
  }

  Widget _buildBottomSheet(WaterfallViewModel vm) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '设置',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 检查更新
                ListTile(
                  title: Text(
                    '检查更新',
                    style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
                  ),
                  trailing: vm.checkingUpdate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          vm.updateError.isNotEmpty ? '检查失败' : '',
                          style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                        ),
                  onTap: vm.checkingUpdate ? null : vm.checkUpdate,
                ),
                Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
                // 清除缓存
                ListTile(
                  title: Text(
                    '清除缓存',
                    style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
                  ),
                  trailing: Text(
                    _cacheSize,
                    style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  ),
                  onTap: () => setState(() => _showClearDialog = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildUpdateDialog(WaterfallViewModel vm) {
    String title;
    Widget content;

    if (vm.checkingUpdate) {
      title = '检查更新';
      content = Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '正在检查更新...',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      );
    } else if (vm.updateError.isNotEmpty && vm.latestApkUrl.isEmpty) {
      title = '检查更新';
      content = Text(
        vm.updateError,
        style: TextStyle(fontSize: 14, color: AppColors.error),
      );
    } else if (vm.updateDownloading) {
      title = '发现新版本';
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '正在下载 ${vm.latestVersion}...',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: vm.updateProgress / 100.0,
              minHeight: 4,
              backgroundColor: AppColors.accent.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${vm.updateProgress}%',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      );
    } else if (vm.latestApkUrl.isEmpty) {
      title = '已是最新版本';
      content = Text(
        '当前已是最新版本 (${vm.latestVersion})',
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      );
    } else {
      title = '发现新版本';
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '新版本: ${vm.latestVersion}',
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '是否下载更新？',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
      content: content,
      actions: [
        if (vm.latestApkUrl.isNotEmpty && !vm.updateDownloading)
          TextButton(
            onPressed: vm.downloadUpdate,
            child: Text('下载', style: TextStyle(color: AppColors.accent)),
          ),
        if (!vm.updateDownloading)
          TextButton(
            onPressed: vm.dismissUpdateDialog,
            child: Text(
              vm.latestApkUrl.isNotEmpty && vm.updateError.isEmpty ? '取消' : '关闭',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _buildClearCacheDialog() {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('清除缓存', style: TextStyle(color: AppColors.textPrimary)),
      content: Text('确定清除所有缓存数据？', style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => setState(() => _showClearDialog = false),
          child: Text('取消', style: TextStyle(color: AppColors.accent)),
        ),
        TextButton(
          onPressed: () async {
            await widget.vm.clearCache();
            if (mounted) {
              setState(() {
                _cacheSize = '0 B';
                _showClearDialog = false;
              });
            }
          },
          child: Text('清除', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }
}
