# 数据模型

所有 `@Model` 属性均带默认值、关系均为可选，以保持未来接入 CloudKit 同步的兼容性。不使用 `@Attribute(.unique)`（CloudKit 不支持）。

## 实体

| 实体 | 职责 |
| --- | --- |
| `Player` | 角色状态、累计计数器缓存、装备中的外观、请假库存与暂停日、法术护盾 |
| `Quest` | 单条有日期的可执行任务（主线 / 支线 / 重复实例） |
| `QuestTemplate` | 重复任务定义，按日生成 `Quest`；自带 7 日窗口状态 |
| `QuestSkillLink` | 任务与技能的关联，携带经验权重 |
| `Skill` | 技能，独立等级与经验 |
| `Habit` / `HabitLog` | 习惯定义与打卡记录 |
| `Challenge` | 长期挑战，进度由统计量推导 |
| `UnlockRecord` | 成就 / 称号解锁记录 |
| `DailyRecord` | 每日聚合，统计与热力图的唯一数据源 |
| `RewardTransaction` | 奖励流水账 |
| `Reminder` | 本地通知调度 |
| `OwnedItem` | 商店购买记录（装饰品） |
| `FailedQuestRecord` | 失败任务快照。原任务会被取消移出任务栏 |
| `AppSettings` | 全局设置单例（含新手引导进度） |

新增实体时只在 `ModelSchemaRegistry.allModels` 登记一次。

## 关键设计取舍

### 四种任务不建四张表

`Quest.kind` 在创建时由日期关系派生：

- `scheduledDay > createdDay` → `.main`（提前规划）
- `scheduledDay == createdDay` → `.side`（当天临时）
- 由 `QuestTemplate` 生成 → `.repeating`

因此"明天规划的任务第二天自动变成主线"不需要任何迁移任务，天然成立。`Challenge` 单独建模，因为它的完成由统计量推导而非手动勾选。

`QuestStatus` 有 `pending` / `completed` / `cancelled`。失败结算把待办标成 `cancelled`，真正留给玩家看的是 `FailedQuestRecord`。

### 周期窗口落在模板上

`QuestTemplate` 额外保存：

- `periodStart`：当前窗口（进行中或延期补债）的第一天
- `cycleOrigin`：本轮配额起算日。进入延期后保持不变，上一窗口已完成的次数仍计入欠债
- `periodState`：`active` 冲配额 / `grace` 补上一窗口的欠债
- `maxCompletionsPerDay`：同一天最多完成几次
- `finishedDay`：玩家主动收队的日期。收队后停生成、取消待办，并按持续天数发放归途奖励
- `completedJourneys`：已走完的周期窗口数。每一窗算一段旅途经历

窗口长度与失败判定由 `RecurringPeriodEngine` 纯函数计算，暂停日不计入活跃天数。

### 等级不落库

`Player.totalEXP` 与 `Skill.totalEXP` 是唯一真相，等级由 `LevelCurve.progress(totalEXP:)` 推导。好处是回滚经验时等级自动跟着回退，不会出现"扣了经验但等级还留着"的漂移。

### 关系图刻意保持最小

只保留两条 SwiftData 关系（`Quest ↔ QuestSkillLink`、`Habit ↔ HabitLog`），其余跨实体引用一律存 `UUID`。降低迁移与删除规则的复杂度。

### GameDay 的存储

`GameDay` 是值类型，内部是 `yyyymmdd` 形式的 `Int`。模型里存 `Int`，通过计算属性暴露 `GameDay`，保证排序、比较、查询谓词都能直接用整数。暂停日同样存 `[Int]`。

### Player 上的外观与道具

外观装备是当前选中的商品 id（主题、头像框、背景、宠物、音效、完成特效、升级特效），不建关系。请假卡是库存计数；法术护盾是布尔，不能叠加。购买装饰走 `OwnedItem`；消耗品入包后改 `Player` 字段，不新增拥有行。

### 引导进度

`AppSettings.hasCompletedTutorial` 与 `tutorialStepRaw` 记录强制新手引导。杀进程后从 `TutorialStep.resumeEntry` 回到最近的入口步，避免卡在已关闭的 sheet。
