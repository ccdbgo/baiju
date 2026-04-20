# baiju_app

白驹 Flutter 主客户端。

## 当前状态

已完成：

- Flutter 工程初始化
- `Riverpod`、`go_router`、`Drift`、`Supabase`、本地通知依赖接入
- `app / core / features / shared` 基础目录骨架
- 今日、日程、待办、习惯、时间线 5 个占位页面
- `Drift` 基础数据库与首批关键表生成

## 常用命令

```bash
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs
```

## Windows 注意事项

如果要在 Windows 上执行桌面构建或运行：

```bash
flutter build windows --debug
flutter run -d windows
```

系统需要先开启 Windows 开发者模式，否则 Flutter 插件阶段会报 symlink 错误。

可在系统里打开：

```powershell
start ms-settings:developers
```

## 下一步

- 接入真实 Supabase 配置
- 建立 DAO / repository / provider
- 补待办、日程、今日页的真实数据流
- 接入本地通知调度
