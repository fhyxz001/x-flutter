import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../../data/repository/media_repository.dart';
import '../theme/app_colors.dart';

/// 代理设置屏幕
///
/// 对应 Android 端 `ProxyScreen.kt`，包含：
/// - 全局代理开关
/// - 代理方案列表（单选、编辑、删除）
/// - 添加方案入口
class ProxyScreen extends StatefulWidget {
  final MediaRepository repo;
  final VoidCallback onBack;
  final Future<void> Function(ProxyScheme? scheme) onEditScheme;

  const ProxyScreen({
    super.key,
    required this.repo,
    required this.onBack,
    required this.onEditScheme,
  });

  @override
  State<ProxyScreen> createState() => _ProxyScreenState();
}

class _ProxyScreenState extends State<ProxyScreen> {
  ProxyConfig _config = ProxyConfig();
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await widget.repo.getProxyConfigAsync();
    if (mounted) {
      setState(() => _config = config);
    }
  }

  Future<void> _save(ProxyConfig newConfig) async {
    setState(() => _config = newConfig);
    await widget.repo.saveProxyConfig(newConfig);
    widget.repo.refreshApi();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildToggle(),
                    const SizedBox(height: 12),
                    _buildSchemes(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _maybeShowDeleteDialog() {
    if (_deletingId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('确认删除', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('确定要删除该代理方案吗？', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _deletingId = null);
              Navigator.of(ctx).pop();
            },
            child: Text('取消', style: TextStyle(color: AppColors.accent)),
          ),
          TextButton(
            onPressed: () {
              final id = _deletingId!;
              final newSchemes = _config.schemes.where((s) => s.id != id).toList();
              final newSelected = _config.selectedId == id
                  ? (newSchemes.isNotEmpty ? newSchemes.first.id : '')
                  : _config.selectedId;
              _save(_config.copyWith(schemes: newSchemes, selectedId: newSelected));
              setState(() => _deletingId = null);
              Navigator.of(ctx).pop();
            },
            child: Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Text(
              '‹ 返回',
              style: TextStyle(fontSize: 15, color: AppColors.accent),
            ),
          ),
          Text(
            '代理设置',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '全局代理',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Switch(
                value: _config.enabled,
                onChanged: (enabled) => _save(_config.copyWith(enabled: enabled)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '开启后将使用选中的代理方案',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemes() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '代理方案',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await widget.onEditScheme(null);
                    _loadConfig();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+ 添加',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
          // 方案列表
          if (_config.schemes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(
                    '暂无代理方案',
                    style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '点击右上角「添加」创建代理方案',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ),
            )
          else
            ..._config.schemes.asMap().entries.map((entry) {
              final index = entry.key;
              final scheme = entry.value;
              return Column(
                children: [
                  _buildSchemeItem(scheme),
                  if (index < _config.schemes.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSchemeItem(ProxyScheme scheme) {
    final isSelected = _config.selectedId == scheme.id;
    return GestureDetector(
      onTap: () => _save(_config.copyWith(selectedId: scheme.id)),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 单选圆点
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.textTertiary,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scheme.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${scheme.host}:${scheme.port}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    await widget.onEditScheme(scheme);
                    _loadConfig();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '编辑',
                      style: TextStyle(fontSize: 12, color: AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() => _deletingId = scheme.id);
                    _maybeShowDeleteDialog();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '删除',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
