# Life RPG

把现实生活变成一场 RPG。你不是在完成 Todo，而是在培养自己的角色。

iOS 原生应用，SwiftUI + SwiftData，纯本地运行，无需联网、无需账号。

## 快速开始（macOS）

```bash
brew install xcodegen
xcodegen generate
open LifeRPG.xcodeproj
```

要求 Xcode 15+ / iOS 17+。仓库不提交 `.xcodeproj`，它由 `project.yml` 生成。

## 核心机制

- **今日主线 / 支线**：前一天规划的任务次日自动成为主线并获得 +20% 奖励；当天临时新增的任务是支线，奖励打五折。这个差距是刻意的，它把玩家推向"提前规划"这个核心习惯
- **技能系统**：自由创建任意技能，每个任务可关联多个技能并分配经验权重，技能独立升级到 Lv100
- **奖励引擎**：难度、时长、优先级、准时度、连续天数共同决定最终 EXP 与 Gold，全部数值由配置表驱动
- **习惯与连续**：一键打卡，连续天数带来全局经验加成
- **成就 / 称号 / 挑战**：三者共用同一套规则引擎，新增内容只需要改 JSON

## 文档

- [架构总览](docs/01-architecture.md)
- [数据模型](docs/02-data-model.md)
- [奖励与平衡](docs/03-reward-balance.md)
- [状态流](docs/04-state-flow.md)
- [路线图](docs/05-roadmap.md)

## 调参

不改代码即可调整全部数值：

- `Resources/Config/balance.json` 基础经验、金币比、等级曲线、连续档位
- `Resources/Config/modifiers.json` 奖励加成与分组
- `Resources/Config/unlock_rules.json` 成就、称号、挑战
- `Resources/Config/shop_items.json` 商店商品
