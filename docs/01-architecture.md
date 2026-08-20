# 架构总览

## 分层

```
Features (SwiftUI View)
   ↓ 只读 @Observable
Stores (@Observable，界面状态 + 用例编排)
   ↓
Services (有状态，持有 ModelContext，负责事务与副作用)
   ↓
Engines (纯函数，只吃值类型，零依赖，可单测)
   ↓
Models (@Model SwiftData 实体) + Core (GameCalendar / GameConfig)
```

铁律：

1. `Engines/` 里的任何类型都不得 `import SwiftData`。所有引擎输入输出都是 `struct`，因此可以在没有模拟器的情况下跑单测验证数值平衡。
2. 业务代码禁止直接调用 `Date()` 判断"今天"。唯一时间源是 `GameCalendar`，它带有可配置的一天起始时刻（默认凌晨 4 点），凌晨 1 点完成的任务算作前一天。
3. 数值不写在代码里。全部来自 `Resources/Config/*.json`，由 `GameConfig` 在启动时加载一次。
4. 经济系统走流水账。任何 EXP / Gold 变动都先落一条 `RewardTransaction`，撤销时按流水反向回滚，而不是重算公式。

## 依赖注入

`AppContainer` 在 App 启动时构造，持有 `ModelContainer`、`GameConfig`、`GameCalendar` 与全部 Service / Store，通过 `.environment()` 注入 SwiftUI 树。没有全局单例（`GameConfig.shared` 仅作为配置只读快照的便利入口）。

## 目录

- `Sources/App` 入口、容器、根导航
- `Sources/Core` 时间、配置、共享值类型
- `Sources/Models` SwiftData 实体
- `Sources/Engines` 纯计算
- `Sources/Services` 事务与副作用
- `Sources/Stores` 界面状态
- `Sources/Features` 各功能页面
- `Resources/Config` 数值与规则表
- `Tests/EngineTests` 引擎层单测

## 工程生成

仓库不提交 `.xcodeproj`。在 macOS 上：

```bash
brew install xcodegen
xcodegen generate
open LifeRPG.xcodeproj
```
