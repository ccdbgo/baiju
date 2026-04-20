# 白驹技术选型与对比（V1）

> 版本：V1
> 更新日期：2026-04-14
> 说明：本文基于官方文档与当前产品规划，用于首发阶段技术决策，不等于最终实施细节冻结。

## 1. 选型目标

白驹不是单一待办工具，而是一个同时覆盖日程、事项、习惯、纪念日、笔记、目标、时间线的跨端产品。技术选型要优先满足以下约束：

- 一套主代码体系覆盖 Android、iOS、PC。
- 支持离线使用，不能把日程和提醒完全依赖网络。
- 数据模型具有关联性，不能只按单一文档流存储。
- 首页、时间线、日历视图、年视图需要较强的自定义 UI 能力。
- 后续要支持多端同步、提醒、复盘、模块联动。
- 首发阶段更关注交付速度和稳定性，不追求过度自研。

## 2. 技术约束拆解

### 2.1 产品侧约束
- 日程、待办、习惯、纪念日、笔记、目标之间存在明显关联。
- 时间线需要聚合多个模块事件，天然更适合关系型建模。
- 提醒能力既要支持本地提醒，也要支持未来的远程通知。
- 多端同步不能牺牲本地操作速度。
- PC 端与移动端需要统一体验，但不要求完全原生外观。

### 2.2 工程侧约束
- 首发应尽量减少多端重复开发。
- 不建议一开始就上“前端一套 + 后端完全自建 + 同步完全自研”的重模式。
- 应保留后续拆出独立服务的能力，避免早期平台锁死。

### 2.3 首发假设
- 首发以个人使用与个人多端同步为主，不以多人协作为核心。
- PC 首发默认优先 Windows，macOS 可以同步支持，Linux 不是首发重点。
- Web 不是首发主平台。

## 3. 客户端方案对比

### 3.1 方案列表
- 方案 A：Flutter
- 方案 B：React Native + 桌面补充方案
- 方案 C：Tauri 2 + React/Vue
- 方案 D：.NET MAUI

### 3.2 对比维度

| 维度 | Flutter | React Native + 桌面补充 | Tauri 2 + React/Vue | .NET MAUI |
| --- | --- | --- | --- | --- |
| 单代码覆盖移动 + PC | 强 | 中 | 强 | 强 |
| 移动端成熟度 | 强 | 强 | 中 | 中 |
| 桌面端成熟度 | 中上 | 中 | 强 | 中上 |
| UI 一致性与定制度 | 强 | 中上 | 强 | 中 |
| 本地数据库与离线能力 | 强 | 中上 | 中上 | 中上 |
| 提醒/系统能力接入 | 强 | 中上 | 中 | 中上 |
| 学习和交付效率 | 强 | 中 | 中 | 中 |
| 团队技术门槛 | 中 | 中 | 高 | 中 |
| 对白驹匹配度 | 高 | 中 | 中上 | 中 |

### 3.3 逐项分析

#### A. Flutter
优点：
- Flutter 官方支持 Android、iOS、Windows、macOS、Linux、Web，多端能力完整。
- 自绘 UI 体系更适合统一实现日历、年视图、时间线、习惯热力图等高定制页面。
- 在本地数据库、状态管理、路由、通知等方面生态成熟，适合中小团队快速交付。
- 视觉一致性更强，适合白驹“极简但统一”的产品风格。

不足：
- 需要接受 Dart 技术栈。
- 应用体积通常不会像 Tauri 那样小。
- 若团队已经强绑定 React 或 C#，迁移成本更高。

判断：
- 对白驹这种“移动端 + PC + 高自定义 + 本地优先”的产品，Flutter 是当前最稳妥的一体化方案。

#### B. React Native + 桌面补充方案
优点：
- 如果团队已有 React/TypeScript 基础，上手快。
- 移动端生态成熟，业务 UI 开发效率高。

不足：
- React Native 官方文档当前核心平台仍是 Android 和 iOS；PC 端通常需要额外接入社区生态或额外桌面壳方案。
- 移动与桌面很容易变成两套工程思路，长期维护成本偏高。
- 对复杂日历、年视图、富交互时间线等场景，跨端一致性不如 Flutter 稳。

判断：
- 如果团队已经非常强 React，可以作为备选。
- 但基于当前官方平台边界和桌面扩展路径，这是一个“可做但更碎”的方案。
- 这里“更碎”是工程判断，不是 React Native 官方文档直接表述。

#### C. Tauri 2 + React/Vue
优点：
- Tauri 2 官方已经支持 Linux、macOS、Windows、Android、iOS。
- 体积小、性能表现好、桌面系统集成能力强。
- 如果已有成熟 Web 前端团队，桌面端推进会比较顺。

不足：
- 白驹并不是纯桌面效率工具，移动端是核心场景之一。
- 移动端生态、通知、复杂本地能力与端侧经验积累，整体仍不如 Flutter 主流。
- 需要同时处理 Web 前端、Rust、平台能力桥接，工程门槛更高。

判断：
- 如果产品未来明显转向“桌面优先”，Tauri 值得重看。
- 但在当前阶段，不建议把白驹主客户端押在 Tauri 上。

#### D. .NET MAUI
优点：
- 官方支持 Android、iOS、macOS、Windows，一套 C# 代码覆盖多端。
- 如果团队是 .NET 背景，技术统一性较好。

不足：
- 不覆盖 Linux。
- 针对高频消费级产品的组件、案例和跨端社区热度，不如 Flutter 和 React 体系活跃。
- 若团队不是 C# 背景，学习收益不如 Flutter 明显。

判断：
- 更适合 .NET 团队、企业内部系统或 Windows 偏重型产品。
- 不是白驹现阶段的优先解。

### 3.4 客户端结论

推荐结论：
- 首选：Flutter
- 备选 1：Tauri 2 + React/Vue（仅在桌面优先时考虑）
- 备选 2：React Native + 桌面扩展（仅在团队强 React 时考虑）
- 不建议首发采用：.NET MAUI

## 4. 后端与同步方案对比

### 4.1 方案列表
- 方案 A：Supabase
- 方案 B：Firebase
- 方案 C：NestJS + PostgreSQL 自建后端

### 4.2 对比维度

| 维度 | Supabase | Firebase | NestJS + PostgreSQL |
| --- | --- | --- | --- |
| 数据模型适合白驹 | 强 | 中 | 强 |
| 首发交付速度 | 强 | 强 | 中 |
| 关系型查询能力 | 强 | 弱到中 | 强 |
| 多端同步支持 | 中上 | 强 | 中 |
| 权限与账号体系 | 强 | 强 | 中 |
| 自定义业务灵活度 | 中上 | 中 | 强 |
| 后续迁移扩展性 | 强 | 中 | 强 |
| 运维复杂度 | 低到中 | 低 | 中到高 |

### 4.3 逐项分析

#### A. Supabase
优点：
- 官方提供 Postgres、Auth、Storage、Realtime、Edge Functions，首发组合完整。
- Flutter 官方集成路径明确，接入成本低。
- Postgres 非常适合白驹的关系型数据结构，例如日程、待办、习惯、笔记、时间线之间的关联查询。
- 未来如果业务复杂度上升，可以继续保留 Postgres，同时拆出独立业务服务，不会被数据模型卡死。

不足：
- 虽然有 Realtime 和 Edge Functions，但复杂同步策略和冲突处理仍要自己设计。
- 若后期服务端逻辑很重，单靠平台能力不一定够，需要补自定义服务。

判断：
- 适合白驹首发阶段，尤其适合“小团队先把产品跑起来”的目标。

#### B. Firebase
优点：
- Auth、FCM、Firestore、离线、实时能力都很成熟。
- 在消息推送、实时监听、快速起步上体验很好。

不足：
- Firestore 官方是 NoSQL 文档数据库，天然更适合文档型、层级型数据。
- 白驹的数据结构明显有较强关系型特征，例如跨模块时间线、日期范围统计、目标联动、复杂筛选。
- 使用 Firestore 不是不能做，但模型设计、查询组织和后期维护成本会更容易变重。

判断：
- 如果产品核心是轻协作、实时同步、文档流数据，Firebase 很强。
- 但对白驹这种时间管理与复盘型产品，Firestore 不是最顺手的数据底座。

#### C. NestJS + PostgreSQL 自建后端
优点：
- 控制力最强。
- 更适合复杂同步、复杂权限、后台任务、统计分析、未来商业化和开放接口。
- PostgreSQL 与白驹的数据模型天然匹配。

不足：
- 首发开发量明显更大。
- 登录、存储、管理后台、基础能力都要自己补齐。
- 早期产品需求还没稳定时，过早自建后端容易把时间消耗在基础设施上。

判断：
- 这是白驹中后期大概率会走到的方向。
- 但不建议作为首发阶段的最小闭环方案。

### 4.4 后端结论

推荐结论：
- 首发首选：Supabase
- 中长期演进：在保留 PostgreSQL 的前提下，按业务复杂度逐步引入 NestJS 独立服务
- 不建议首发直接用 Firestore 作为主数据模型

## 5. 本地数据层对比

### 5.1 方案列表
- 方案 A：SQLite + Drift
- 方案 B：Isar

### 5.2 对比

| 维度 | SQLite + Drift | Isar |
| --- | --- | --- |
| 关系型建模 | 强 | 中 |
| 复杂查询 | 强 | 中 |
| 事务能力 | 强 | 强 |
| 时间线聚合 | 强 | 中 |
| 多表关联 | 强 | 弱到中 |
| 上手成本 | 中 | 低 |
| 对白驹匹配度 | 高 | 中 |

### 5.3 结论

推荐使用 `SQLite + Drift`。

原因：
- SQLite 官方能力稳定，支持 ACID、JSON、CTE、窗口函数等能力，适合复杂本地数据处理。
- Drift 是基于 SQLite 的响应式持久化库，类型安全和迁移能力更适合长期维护。
- 白驹不是简单清单应用，而是跨模块聚合型产品，关系型本地存储比 NoSQL 更自然。

Isar 不是不能用，但更适合对象型或轻关系数据场景。当前白驹对时间线、统计、交叉引用的需求更偏向 SQLite。

## 6. 通知与提醒方案

推荐拆成两层：

- 本地提醒：客户端本地调度，负责日程提醒、习惯打卡提醒、纪念日提醒。
- 远程推送：服务端触发，负责账号消息、跨设备同步提示、未来的运营消息。

判断原则：
- 白驹的“提醒”不应该完全依赖服务端推送，否则离线、系统限制、时区和到点触发稳定性都会受影响。
- 首发阶段应以本地提醒为主，远程推送为辅。

推荐组合：
- Flutter 端使用 `flutter_local_notifications`
- 远程推送使用 FCM，iOS 侧走 APNs 通道

## 7. 推荐首发技术栈

### 7.1 客户端
- 框架：Flutter
- 状态管理：Riverpod
- 路由：go_router
- 本地数据库：SQLite + Drift
- 本地通知：flutter_local_notifications

### 7.2 服务端
- BaaS：Supabase
- 数据库：PostgreSQL
- 鉴权：Supabase Auth
- 实时同步：Supabase Realtime
- 轻量服务端逻辑：Supabase Edge Functions
- 对象存储：Supabase Storage

### 7.3 推送与消息
- 远程推送：Firebase Cloud Messaging
- iOS 消息投递：APNs 通道

## 8. 推荐架构

```text
Flutter App
├─ Presentation Layer
├─ Application Layer
├─ Domain Layer
├─ Local Database (SQLite + Drift)
├─ Notification Scheduler
└─ Sync Engine
      ↓
Supabase
├─ Auth
├─ PostgreSQL
├─ Realtime
├─ Storage
└─ Edge Functions
```

### 8.1 架构原则
- 采用本地优先，不采用“所有操作先打远程接口”的模式。
- 所有新增、编辑、完成、打卡操作先写本地数据库。
- 同步引擎异步将变更推送到远端。
- 启动、切后台恢复、手动下拉刷新时做增量同步。
- 提醒从本地数据库生成，不依赖服务器定时推送。

### 8.2 本地表设计建议
核心业务表建议至少包括：
- `schedules`
- `todos`
- `habits`
- `habit_records`
- `anniversaries`
- `notes`
- `goals`
- `timeline_events`
- `sync_queue`

统一建议字段：
- `id`
- `user_id`
- `created_at`
- `updated_at`
- `deleted_at`
- `sync_status`
- `local_version`

## 9. 同步策略建议

### 9.1 基础策略
- 客户端本地先写
- 远端异步同步
- 远端增量回拉
- 删除采用软删除
- 通过 `updated_at` 或版本号做增量比较

### 9.2 冲突策略
- 日程、待办、习惯配置类字段：优先采用最后修改生效
- 笔记正文：建议预留版本历史，避免简单覆盖
- 完成状态、打卡记录：以幂等写入为主，减少冲突

### 9.3 不建议
- 不建议首发就做复杂 CRDT
- 不建议完全依赖实时订阅做同步
- 不建议把本地缓存当作“临时 UI 缓存”，而不是正式数据源

## 10. 演进路线

### 阶段 1：首发可交付
- Flutter
- SQLite + Drift
- Supabase
- 本地提醒
- 基础多端同步

### 阶段 2：能力增强
- 完善同步冲突处理
- 增加统计分析
- 增加附件和富文本
- 优化桌面端快捷操作

### 阶段 3：服务拆分
- 保留 PostgreSQL
- 逐步拆出 NestJS 业务服务
- 增加后台任务、运营能力、开放接口

## 11. 最终推荐

如果以“尽快做出稳定可用的首发版本”为目标，推荐组合是：

- 客户端：Flutter
- 本地数据：SQLite + Drift
- 后端：Supabase + PostgreSQL
- 通知：本地通知 + FCM
- 架构：本地优先 + 增量同步

这套组合的核心优势是：
- 一套主客户端覆盖移动端与 PC
- 能承载复杂时间管理产品的数据结构
- 首发效率高
- 后续可平滑演进到独立后端

## 12. 参考资料

以下结论主要参考官方资料，核对日期为 2026-04-14：

- Flutter supported platforms:
  https://docs.flutter.dev/reference/supported-platforms
- React Native Platform:
  https://reactnative.dev/docs/platform
- Tauri 2 官网:
  https://tauri.app/
- Tauri 2 stable release:
  https://tauri.app/blog
- .NET MAUI:
  https://learn.microsoft.com/en-us/dotnet/maui/what-is-maui?view=net-maui-9.0
- Supabase Docs:
  https://supabase.com/docs
- Supabase Flutter quickstart:
  https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- Firebase Cloud Firestore:
  https://firebase.google.com/docs/firestore
- Firestore data model:
  https://firebase.google.com/docs/firestore/data-model
- Firebase Cloud Messaging:
  https://firebase.google.com/docs/cloud-messaging
- SQLite features:
  https://sqlite.org/features.html
- SQLite documentation:
  https://sqlite.org/docs.html
- Drift:
  https://pub.dev/packages/drift
- Isar:
  https://isar.dev/
- Riverpod:
  https://riverpod.dev/
- go_router:
  https://pub.dev/packages/go_router
- flutter_local_notifications:
  https://pub.dev/packages/flutter_local_notifications
