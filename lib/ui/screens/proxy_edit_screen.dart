import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/models.dart';
import '../theme/app_colors.dart';

/// 代理方案编辑屏幕
///
/// 对应 Android 端 `ProxyEditScreen.kt`，包含方案名称、服务器地址、端口输入。
class ProxyEditScreen extends StatefulWidget {
  final ProxyScheme? scheme;
  final VoidCallback onBack;
  final void Function(ProxyScheme scheme) onSave;

  const ProxyEditScreen({
    super.key,
    required this.scheme,
    required this.onBack,
    required this.onSave,
  });

  @override
  State<ProxyEditScreen> createState() => _ProxyEditScreenState();
}

class _ProxyEditScreenState extends State<ProxyEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.scheme?.name ?? '');
    _hostController = TextEditingController(text: widget.scheme?.host ?? '');
    _portController = TextEditingController(text: widget.scheme?.port.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());

    if (name.isEmpty || host.isEmpty || port == null || port < 1 || port > 65535) {
      return;
    }

    widget.onSave(ProxyScheme(
      id: widget.scheme?.id ?? 'proxy_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      host: host,
      port: port,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _FormRow(
                          label: '方案名称',
                          controller: _nameController,
                          placeholder: '如：工作代理',
                        ),
                        Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
                        _FormRow(
                          label: '服务器地址',
                          controller: _hostController,
                          placeholder: '如：127.0.0.1',
                        ),
                        Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
                        _FormRow(
                          label: '端口',
                          controller: _portController,
                          placeholder: '如：7890',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _handleSave,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.background,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            widget.scheme != null ? '编辑方案' : '添加方案',
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
}

class _FormRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;

  const _FormRow({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(fontSize: 14, color: AppColors.textTertiary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: keyboardType == TextInputType.number
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
