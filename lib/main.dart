import 'package:flutter/material.dart';

import 'app.dart';

/// 应用入口
///
/// 对应 Android 端 `MainActivity` + `TwApp` 的初始化逻辑。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TwApp());
}
