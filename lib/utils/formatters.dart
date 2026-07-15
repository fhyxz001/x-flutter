/// 格式化工具函数
///
/// 对应 Android 端 `WaterfallScreen.kt` 中的 `formatFileSize` 和 `formatCount`。

/// 格式化文件大小
String formatFileSize(int bytes) {
  if (bytes <= 0) return '';
  final kb = bytes / 1024.0;
  final mb = kb / 1024.0;
  final gb = mb / 1024.0;
  if (gb >= 1) return '${gb.toStringAsFixed(1)} GB';
  if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
  if (kb >= 1) return '${kb.toStringAsFixed(0)} KB';
  return '$bytes B';
}

/// 格式化数量（万/w, 千/k）
String formatCount(int num) {
  if (num <= 0) return '';
  if (num >= 10000) return '${(num / 10000.0).toStringAsFixed(1)}w';
  if (num >= 1000) return '${(num / 1000.0).toStringAsFixed(1)}k';
  return num.toString();
}
