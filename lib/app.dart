import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ui/navigation/app_router.dart';
import 'ui/theme/app_theme.dart';
import 'ui/components/settings_sheet.dart';
import 'viewmodel/waterfall_view_model.dart';

/// 应用根 Widget
///
/// 对应 Android 端 `TwTheme` + `TwNavGraph` 的组合。
/// 使用 `Provider` 提供 `WaterfallViewModel`，`MaterialApp.router` 接入 `go_router`。
class TwApp extends StatelessWidget {
  final _router = createRouter();

  TwApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WaterfallViewModel(),
      child: MaterialApp.router(
        title: 'X下载器',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: _router,
        builder: (context, child) {
          final vm = context.watch<WaterfallViewModel>();
          // 设置弹窗覆盖在所有页面之上
          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              if (vm.showSettings)
                GestureDetector(
                  onTap: () => vm.updateShowSettings(false),
                  child: Container(
                    color: Colors.black54,
                    child: GestureDetector(
                      onTap: () {}, // 阻止穿透
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: SettingsSheet(vm: vm),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
