# 路线图

## V1.0 分阶段

- **阶段 0** 仓库骨架、`project.yml`、架构文档、配置表
- **阶段 1** `GameCalendar`、`GameConfig`、全部 SwiftData 模型与 Repository
- **阶段 2** `RewardEngine`、`LevelCurve`、`StreakEngine`、流水账 + 引擎层单测
- **阶段 3** 任务闭环：Quest CRUD、Tomorrow Planning、每日结算、首页
- **阶段 4** 技能系统与习惯系统
- **阶段 5** `DailyRecord` 聚合与统计页（含热力图）
- **阶段 6** 解锁引擎接入：成就 / 称号 / 挑战
- **阶段 7** 金币商店、本地通知、设置、导出与备份

阶段 3 结束时即为最小可玩版本。

## V2.0 扩展点

每一项都已经在 V1.0 架构中留好了接入位置，不需要改动现有引擎：

- **专注模式**：番茄钟结束后产出一条 `RewardTransaction`，走同一条奖励管线；`DailyRecord.focusMinutes` 字段已存在
- **每日总结**：新增 `JournalEntry` 模型，与 `DailyRecord` 同一 `GameDay` 主键关联
- **AI 助手**：只读 `MetricsSnapshot` 与 `DailyRecord` 序列，与写入路径完全解耦，可安全接入本地或远程模型
- **多角色档案**：`Player` 增加 `profileID`，Repository 层加一层过滤即可；技能与任务已经通过 `UUID` 弱引用，不受影响
- **iCloud 同步**：模型已满足 CloudKit 约束（属性有默认值、关系可选、无唯一索引），开启 `ModelConfiguration(cloudKitDatabase:)` 即可
- **装备与收藏**：`OwnedItem` + `shop_items.json` 已经支撑，新增品类只需加 JSON 行与一个 `ShopItemKind` case
