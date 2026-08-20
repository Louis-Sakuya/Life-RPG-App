# 数据模型

所有 `@Model` 属性均带默认值、关系均为可选，以保持未来接入 CloudKit 同步的兼容性。不使用 `@Attribute(.unique)`（CloudKit 不支持）。

## 实体

| 实体 | 职责 |
| --- | --- |
| `Player` | 角色状态与累计计数器缓存 |
| `Quest` | 单条有日期的可执行任务（主线 / 支线 / 重复实例） |
| `QuestTemplate` | 重复任务定义，按日生成 `Quest` |
| `QuestSkillLink` | 任务与技能的关联，携带经验权重 |
| `Skill` | 技能，独立等级与经验 |
| `Habit` / `HabitLog` | 习惯定义与打卡记录 |
| `Challenge` | 长期挑战，进度由统计量推导 |
| `UnlockRecord` | 成就 / 称号解锁记录 |
| `DailyRecord` | 每日聚合，统计与热力图的唯一数据源 |
| `RewardTransaction` | 奖励流水账 |
| `Reminder` | 本地通知调度 |
| `OwnedItem` | 商店购买记录 |
| `AppSettings` | 全局设置单例 |

## 关键设计取舍

### 四种任务不建四张表

`Quest.kind` 在创建时由日期关系派生：

- `scheduledDay > createdDay` → `.main`（提前规划）
- `scheduledDay == createdDay` → `.side`（当天临时）
- 由 `QuestTemplate` 生成 → `.repeating`

因此"明天规划的任务第二天自动变成主线"不需要任何迁移任务，天然成立。`Challenge` 单独建模，因为它的完成由统计量推导而非手动勾选。

### 等级不落库

`Player.totalEXP` 与 `Skill.totalEXP` 是唯一真相，等级由 `LevelCurve.progress(totalEXP:)` 推导。好处是回滚经验时等级自动跟着回退，不会出现"扣了经验但等级还留着"的漂移。

### 关系图刻意保持最小

只保留两条 SwiftData 关系（`Quest ↔ QuestSkillLink`、`Habit ↔ HabitLog`），其余跨实体引用一律存 `UUID`。降低迁移与删除规则的复杂度。

### GameDay 的存储

`GameDay` 是值类型，内部是 `yyyymmdd` 形式的 `Int`。模型里存 `Int`，通过计算属性暴露 `GameDay`，保证排序、比较、查询谓词都能直接用整数。
