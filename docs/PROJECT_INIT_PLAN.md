# 白驹项目初始化技术方案（V1）

> 目标：把已确定的技术选型细化成可直接开工的初始化方案。
> 适用范围：白驹首发版本，覆盖 Android、iOS、PC。

## 1. 方案结论

首发阶段采用以下技术组合：

- 客户端框架：Flutter
- 状态管理：Riverpod
- 路由：go_router
- 本地数据库：SQLite + Drift
- 后端：Supabase + PostgreSQL
- 远程同步：Supabase Realtime + 增量拉取
- 本地提醒：flutter_local_notifications
- 远程推送：FCM

架构原则：

- 本地优先，不走“先请求远端，再更新本地”的模式。
- 单 Flutter App 优先，不提前拆过多子包。
- 以功能模块为中心组织代码，不以技术层做全局大分仓。
- 所有业务数据默认可同步，删除采用软删除。

## 2. 初始化阶段的工程目标

第一阶段不是把所有功能一次做完，而是先把基础骨架搭起来，确保后续功能能稳定叠加。

初始化阶段需要完成：

- Flutter 工程创建
- 多环境配置
- 基础导航框架
- 主题与设计变量
- 本地数据库初始化
- 账号接入骨架
- 同步引擎骨架
- 通知调度骨架
- 首批核心表落地
- 今日页、日程、待办、习惯、时间线 5 个模块的空骨架

## 3. 仓库结构建议

首发建议采用 `monorepo-lite` 结构，给未来服务端和共享模块预留位置，但当前只重点建设一个 Flutter App。

```text
baiju/
├─ apps/
│  └─ baiju_app/
├─ docs/
├─ services/
│  └─ README.md
├─ tooling/
│  └─ README.md
└─ README.md
```

说明：

- `apps/baiju_app`：主客户端工程，首发全部核心实现都在这里。
- `docs`：产品、架构、数据设计、接口说明。
- `services`：后续若引入 NestJS 或后台任务服务，再逐步填充。
- `tooling`：后续脚本、代码生成、导入导出工具可放这里。

不建议首发就做：

- `packages/domain`
- `packages/ui`
- `packages/common`

原因：

- 现在还没有真实复用压力，提前拆包会增加维护成本。
- Flutter 首发阶段更重要的是把业务闭环和分层边界做清楚。

## 4. Flutter App 目录结构

`apps/baiju_app/lib` 建议结构如下：

```text
lib/
├─ app/
│  ├─ bootstrap/
│  ├─ config/
│  ├─ di/
│  ├─ router/
│  ├─ theme/
│  └─ app.dart
├─ core/
│  ├─ auth/
│  ├─ database/
│  ├─ errors/
│  ├─ logging/
│  ├─ notifications/
│  ├─ sync/
│  ├─ time/
│  ├─ utils/
│  └─ widgets/
├─ features/
│  ├─ today/
│  ├─ schedule/
│  ├─ todo/
│  ├─ habit/
│  ├─ anniversary/
│  ├─ goal/
│  ├─ note/
│  ├─ timeline/
│  └─ settings/
├─ shared/
│  ├─ enums/
│  ├─ models/
│  ├─ extensions/
│  └─ constants/
├─ l10n/
└─ main.dart
```

## 5. 模块内部分层规范

每个功能模块采用统一的 feature-first 结构：

```text
features/schedule/
├─ application/
├─ domain/
├─ infrastructure/
├─ presentation/
└─ schedule_module.dart
```

各层职责：

### 5.1 `presentation`
- 页面
- 组件
- Riverpod provider
- 页面状态对象
- 用户交互事件分发

### 5.2 `application`
- use case
- service
- 命令编排
- 跨仓储调用
- 输入校验和流程控制

### 5.3 `domain`
- entity
- value object
- repository contract
- 领域规则

### 5.4 `infrastructure`
- Drift table / dao
- Supabase data source
- DTO / mapper
- repository implementation

## 6. 全局模块职责

### 6.1 `app`
负责应用启动和全局装配：

- 环境初始化
- 第三方 SDK 初始化
- 路由表注册
- 主题与字体
- 全局 ProviderScope

### 6.2 `core/database`
负责数据库基础设施：

- Drift Database
- Migration
- 通用 DAO 基类
- 事务封装
- 常用查询工具

### 6.3 `core/sync`
负责同步引擎：

- 同步任务调度器
- 推送本地变更
- 拉取远端变更
- 冲突处理策略
- 同步游标管理

### 6.4 `core/notifications`
负责提醒能力：

- 本地通知注册
- 通知权限申请
- 日程提醒调度
- 习惯提醒调度
- 纪念日提醒调度

### 6.5 `core/auth`
负责账号和会话：

- 登录状态
- 用户信息
- Token 持久化
- 匿名态与登录态切换

## 7. 状态管理规范

推荐规则：

- 页面级状态：Riverpod Notifier/AsyncNotifier
- 只读派生状态：Provider
- 瞬时 UI 状态：页面内部 state 或 provider
- 不使用全局事件总线

不建议：

- 所有逻辑都堆到一个大 controller
- 页面直接拼装 SQL 或直接调用远端 API

## 8. 路由设计建议

推荐一级路由：

- `/today`
- `/schedule`
- `/todo`
- `/habit`
- `/anniversary`
- `/goal`
- `/note`
- `/timeline`
- `/settings`

推荐详情路由：

- `/schedule/:id`
- `/todo/:id`
- `/habit/:id`
- `/anniversary/:id`
- `/goal/:id`
- `/note/:id`

推荐编辑路由：

- `/schedule/create`
- `/schedule/:id/edit`
- `/todo/create`
- `/todo/:id/edit`

原则：

- 列表页、详情页、编辑页分离
- 首页聚合，不承载复杂编辑逻辑
- 所有模块都保留深链接能力

## 9. 环境配置建议

建议至少区分三个环境：

- `dev`
- `staging`
- `prod`

配置内容：

- Supabase URL
- Supabase anon key
- 推送开关
- 日志级别
- 是否启用调试工具

建议文件：

```text
lib/app/config/
├─ app_env.dart
├─ env_dev.dart
├─ env_staging.dart
└─ env_prod.dart
```

## 10. 数据层设计原则

白驹的数据层必须满足：

- 关系型建模
- 本地快速查询
- 统一时间线聚合
- 可追踪同步状态
- 可软删除
- 可做增量同步

设计原则：

- 业务主表与同步元数据字段放在同一行
- 关联表使用显式外键 ID，不做隐式嵌套对象
- 所有时间统一保存 UTC 时间戳，同时保留本地展示时区策略
- 所有业务表都带审计字段和同步字段

## 11. 通用字段规范

以下字段建议所有可同步业务表统一具备：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | text | 全局唯一 ID，客户端生成 UUID |
| `user_id` | text | 所属用户 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 最后更新时间 |
| `deleted_at` | datetime nullable | 软删除时间 |
| `sync_status` | text | 同步状态 |
| `local_version` | integer | 本地版本号 |
| `remote_version` | integer nullable | 远端版本号 |
| `last_synced_at` | datetime nullable | 最近成功同步时间 |
| `device_id` | text | 最后修改设备 |

### 11.1 `sync_status` 枚举建议
- `pending_create`
- `pending_update`
- `pending_delete`
- `synced`
- `sync_failed`
- `conflict`

### 11.2 ID 规则
- 业务主键全部使用客户端生成 UUID
- 不依赖数据库自增 ID

原因：

- 先本地写入，再远端同步时不需要回填主键
- 多端写入更容易处理

## 12. 首批本地表设计

首发阶段建议先建以下表：

- `users`
- `schedules`
- `schedule_reminders`
- `todos`
- `todo_subtasks`
- `habits`
- `habit_records`
- `anniversaries`
- `notes`
- `goals`
- `timeline_events`
- `sync_queue`
- `sync_cursors`
- `app_settings`

## 13. 核心业务表字段草案

### 13.1 `users`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | text | 用户 ID |
| `email` | text nullable | 邮箱 |
| `display_name` | text nullable | 昵称 |
| `avatar_url` | text nullable | 头像 |
| `timezone` | text | 时区 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |

### 13.2 `schedules`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | text | 日程 ID |
| `user_id` | text | 用户 ID |
| `title` | text | 标题 |
| `description` | text nullable | 描述 |
| `start_at` | datetime | 开始时间 |
| `end_at` | datetime | 结束时间 |
| `is_all_day` | boolean | 是否全天 |
| `timezone` | text | 日程时区 |
| `location` | text nullable | 地点 |
| `category` | text nullable | 分类 |
| `color` | text nullable | 颜色标识 |
| `status` | text | `planned/completed/cancelled` |
| `recurrence_rule` | text nullable | 重复规则 |
| `source_todo_id` | text nullable | 来源待办 |
| `linked_note_id` | text nullable | 关联笔记 |
| `completed_at` | datetime nullable | 完成时间 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |
| `deleted_at` | datetime nullable | 删除时间 |
| `sync_status` | text | 同步状态 |
| `local_version` | integer | 本地版本 |
| `remote_version` | integer nullable | 远端版本 |
| `last_synced_at` | datetime nullable | 最近同步时间 |
| `device_id` | text | 最后修改设备 |

### 13.3 `schedule_reminders`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | text | 提醒 ID |
| `schedule_id` | text | 所属日程 |
| `trigger_minutes_before` | integer | 提前分钟数 |
| `trigger_at` | datetime | 触发时间 |
| `channel` | text | `local/push` |
| `is_enabled` | boolean | 是否启用 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |

### 13.4 `todos`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | text | 待办 ID |
| `user_id` | text | 用户 ID |
| `title` | text | 标题 |
| `description` | text nullable | 描述 |
| `priority` | text | `low/medium/high` |
| `status` | text | `open/completed/archived` |
| `due_at` | datetime nullable | 截止时间 |
| `planned_at` | datetime nullable | 计划执行时间 |
| `list_name` | text nullable | 所属清单 |
| `goal_id` | text nullable | 关联目标 |
| `linked_note_id` | text nullable | 关联笔记 |
| `converted_schedule_id` | text nullable | 转换后的日程 |
| `completed_at` | datetime nullable | 完成时间 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |
| `deleted_at` | datetime nullable | 删除时间 |
| `sync_status` | text | 同步状态 |
| `local_version` | integer | 本地版本 |
| `remote_version` | integer nullable | 远端版本 |
| `last_synced_at` | datetime nullable | 最近同步时间 |
| `device_id` | text | 最后修改设备 |

### 13.5 `todo_subtasks`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | text | 子任务 ID |
| `todo_id` | text | 所属待办 |
| `title` | text | 标题 |
| `is_completed` | boolean | 是否完成 |
| `sort_order` | integer | 排序 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |
| `deleted_at` | datetime nullable | 删除时间 |

### 13.6 `habits`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | text | 习惯 ID |
| `user_id` | text | 用户 ID |
| `name` | text | 名称 |
| `description` | text nullable | 描述 |
| `frequency_type` | text | `daily/weekly/custom` |
| `frequency_rule` | text | 周期规则 JSON 或编码串 |
| `reminder_time` | text nullable | 提醒时间 |
| `goal_id` | text nullable | 关联目标 |
| `start_date` | date | 开始日期 |
| `status` | text | `active/paused/completed` |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |
| `deleted_at` | datetime nullable | 删除时间 |
| `sync_status` | text | 同步状态 |
| `local_version` | integer | 本地版本 |
| `remote_version` | integer nullable | 远端版本 |
| `last_synced_at` | datetime nullable | 最近同步时间 |
| `device_id` | text | 最后修改设备 |

### 13.7 `habit_records`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | text | 打卡记录 ID |
| `habit_id` | text | 习惯 ID |
| `user_id` | text | 用户 ID |
| `record_date` | date | 打卡日期 |
| `recorded_at` | datetime | 打卡时间 |
| `status` | text | `done/skipped/missed` |
| `source_schedule_id` | text nullable | 来源日程 |
| `note` | text nullable | 备注 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |
| `deleted_at` | datetime nullable | 删除时间 |
| `sync_status` | text | 同步状态 |
| `local_version` | integer | 本地版本 |
| `remote_version` | integer nullable | 远端版本 |
| `last_synced_at` | datetime nullable | 最近同步时间 |
| `device_id` | text | 最后修改设备 |

### 13.8 `anniversaries`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | text | 纪念日 ID |
| `user_id` | text | 用户 ID |
| `title` | text | 标题 |
| `base_date` | date | 基准日期 |
| `calendar_type` | text | `solar/lunar` |
| `remind_days_before` | integer nullable | 提前提醒天数 |
| `category` | text nullable | 分类 |
| `note` | text nullable | 备注 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |
| `deleted_at` | datetime nullable | 删除时间 |
| `sync_status` | text | 同步状态 |
| `local_version` | integer | 本地版本 |
| `remote_version` | integer nullable | 远端版本 |
| `last_synced_at` | datetime nullable | 最近同步时间 |
| `device_id` | text | 最后修改设备 |

### 13.9 `notes`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | text | 笔记 ID |
| `user_id` | text | 用户 ID |
| `title` | text nullable | 标题 |
| `content` | text | 内容 |
| `note_type` | text | `note/diary/memo` |
| `related_entity_type` | text nullable | 关联对象类型 |
| `related_entity_id` | text nullable | 关联对象 ID |
| `is_favorite` | boolean | 是否收藏 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |
| `deleted_at` | datetime nullable | 删除时间 |
| `sync_status` | text | 同步状态 |
| `local_version` | integer | 本地版本 |
| `remote_version` | integer nullable | 远端版本 |
| `last_synced_at` | datetime nullable | 最近同步时间 |
| `device_id` | text | 最后修改设备 |

### 13.10 `goals`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | text | 目标 ID |
| `user_id` | text | 用户 ID |
| `title` | text | 标题 |
| `description` | text nullable | 描述 |
| `goal_type` | text | `yearly/monthly/stage` |
| `status` | text | `active/completed/paused/abandoned` |
| `start_date` | date nullable | 开始日期 |
| `end_date` | date nullable | 结束日期 |
| `progress_value` | real nullable | 当前进度值 |
| `progress_target` | real nullable | 目标值 |
| `unit` | text nullable | 进度单位 |
| `review_note_id` | text nullable | 复盘笔记 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |
| `deleted_at` | datetime nullable | 删除时间 |
| `sync_status` | text | 同步状态 |
| `local_version` | integer | 本地版本 |
| `remote_version` | integer nullable | 远端版本 |
| `last_synced_at` | datetime nullable | 最近同步时间 |
| `device_id` | text | 最后修改设备 |

### 13.11 `timeline_events`

这是白驹的核心聚合表，建议保留一张显式时间线表，而不是每次都临时 union 所有模块。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | text | 时间线事件 ID |
| `user_id` | text | 用户 ID |
| `event_type` | text | `schedule/todo/habit/note/anniversary/goal` |
| `event_action` | text | `created/updated/completed/checked_in/reviewed` |
| `source_entity_id` | text | 来源实体 ID |
| `source_entity_type` | text | 来源实体类型 |
| `occurred_at` | datetime | 发生时间 |
| `title` | text | 展示标题 |
| `summary` | text nullable | 展示摘要 |
| `payload_json` | text nullable | 冗余快照 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |
| `deleted_at` | datetime nullable | 删除时间 |
| `sync_status` | text | 同步状态 |
| `local_version` | integer | 本地版本 |
| `remote_version` | integer nullable | 远端版本 |
| `last_synced_at` | datetime nullable | 最近同步时间 |
| `device_id` | text | 最后修改设备 |

说明：

- 时间线是产品核心展示层，不只是查询结果。
- 保留快照字段有助于降低跨模块回查成本。
- 业务变更时要同步写入或更新对应时间线事件。

## 14. 同步基础表设计

### 14.1 `sync_queue`

该表负责记录待推送的本地变更。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | text | 队列 ID |
| `entity_type` | text | 表类型 |
| `entity_id` | text | 业务 ID |
| `operation` | text | `create/update/delete` |
| `payload_json` | text | 推送载荷快照 |
| `retry_count` | integer | 重试次数 |
| `last_error` | text nullable | 最后一次错误 |
| `status` | text | `pending/running/failed/done` |
| `next_retry_at` | datetime nullable | 下次重试时间 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |

规则：

- 本地业务数据写入成功后，再插入 `sync_queue`
- 同一实体连续多次编辑时允许合并队列
- 删除使用软删除后同步，不直接物理删除

### 14.2 `sync_cursors`

该表负责记录各业务表的远端增量同步位置。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `entity_type` | text | 业务类型 |
| `cursor_value` | text | 游标值，可存更新时间或版本 |
| `updated_at` | datetime | 更新时间 |

## 15. 同步策略落地规则

### 15.1 写路径

统一写路径：

1. UI 触发操作
2. Application use case 校验
3. Drift 事务写本地业务表
4. 更新或生成时间线事件
5. 写入 `sync_queue`
6. 重新调度提醒
7. 后台异步同步到远端

### 15.2 拉取路径

统一拉取路径：

1. 根据 `sync_cursors` 获取各表游标
2. 拉取远端变更
3. 比较本地 `local_version` 与远端 `remote_version`
4. 按策略合并
5. 更新本地表
6. 重新生成相关时间线快照或提醒
7. 更新游标

### 15.3 冲突策略

首发建议采用简单策略：

- 配置型数据：最后修改生效
- 完成状态与打卡记录：幂等写入
- 笔记正文：先最后修改生效，后续再加历史版本

## 16. 通知调度设计

建议新增“调度器服务”，不把提醒逻辑散落到各 feature。

职责：

- 根据 `schedule_reminders` 生成本地通知
- 根据 `habits.reminder_time` 生成习惯提醒
- 根据 `anniversaries` 计算临近提醒
- 编辑后自动取消旧提醒并重建

建议位置：

```text
lib/core/notifications/
├─ notification_service.dart
├─ notification_scheduler.dart
├─ notification_payload.dart
└─ notification_permission_service.dart
```

## 17. Drift 分表与 DAO 建议

建议按业务拆分 table 和 dao 文件，不要所有表堆进一个文件。

```text
lib/core/database/
├─ app_database.dart
├─ migrations/
├─ tables/
│  ├─ users_table.dart
│  ├─ schedules_table.dart
│  ├─ schedule_reminders_table.dart
│  ├─ todos_table.dart
│  ├─ todo_subtasks_table.dart
│  ├─ habits_table.dart
│  ├─ habit_records_table.dart
│  ├─ anniversaries_table.dart
│  ├─ notes_table.dart
│  ├─ goals_table.dart
│  ├─ timeline_events_table.dart
│  ├─ sync_queue_table.dart
│  └─ sync_cursors_table.dart
└─ daos/
   ├─ schedules_dao.dart
   ├─ todos_dao.dart
   ├─ habits_dao.dart
   ├─ anniversaries_dao.dart
   ├─ notes_dao.dart
   ├─ goals_dao.dart
   ├─ timeline_dao.dart
   └─ sync_dao.dart
```

## 18. 首发阶段的 Provider 拆分建议

建议每个 feature 至少有三类 provider：

- `repositoryProvider`
- `queryProvider`
- `actionProvider`

示例：

```text
features/todo/presentation/providers/
├─ todo_repository_provider.dart
├─ today_todos_provider.dart
├─ todo_detail_provider.dart
└─ todo_actions_provider.dart
```

原则：

- 查询和写操作拆开
- 不让页面直接依赖 Drift DAO
- 页面只依赖 application 层能力或 query provider

## 19. 首批实现顺序

建议按下面顺序推进，而不是按全部模块平铺开发：

### 阶段 A：骨架
- Flutter 项目初始化
- Riverpod、go_router、Drift、Supabase 接入
- 主题、导航、日志、环境配置

### 阶段 B：最小业务闭环
- 用户登录
- 待办
- 日程
- 今日页聚合
- 本地提醒

### 阶段 C：联动闭环
- 习惯
- 时间线
- 待办转日程
- 日程完成转打卡

### 阶段 D：补足模块
- 纪念日
- 笔记
- 目标

## 20. 初始化阶段不做什么

为了控制复杂度，以下内容不建议放到第一轮脚手架：

- CRDT
- 实时多人协作
- 富文本编辑器
- 插件系统
- 自定义脚本引擎
- 复杂模板系统
- 多 package 代码仓拆分

## 21. 下一步可执行动作

在本方案基础上，下一步可以直接进入工程落地：

1. 初始化 Flutter 工程与基础依赖
2. 建立 `lib` 目录骨架
3. 落第一版 Drift 表定义
4. 接入 Supabase 登录和配置
5. 搭建今日页、待办、日程 3 个基础页面

如果继续执行，我下一步可以直接开始第 1 步和第 2 步，把 Flutter 项目脚手架搭起来。
