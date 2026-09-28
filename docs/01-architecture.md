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
5. 商店装饰品不得改任务经验。道具（请假卡 / 保险卡）只允许改日程时钟或连胜保护。

## 依赖注入

`AppContainer` 在 App 启动时构造，持有 `ModelContainer`、`GameConfig`、`GameCalendar` 与全部 Service / Store，通过 `.environment()` 注入 SwiftUI 树。没有全局单例（`GameConfig.shared` 仅作为配置只读快照的便利入口）。

改「一天从几点开始」会整体重建依赖 `GameCalendar` 的服务，避免一半按旧口径、一半按新口径判断今天。

## 根导航

`RootView` 在登记完成后进入四个 Tab：**今日 / 成长 / 统计 / 我的**。任务中心不再占独立 Tab，今日告示栏就是当天的任务板；发布走工会向导，按日查看走告示日历 sheet。

全局叠层：

- `celebrationOverlay`：升级、解锁、幸运成长横幅
- `cosmeticFXOverlay`：完成 / 升级粒子（默认轻量，商店商品再加密）
- 失败任务 alert、法术护盾 alert
- 升级二选一 sheet（不可关闭，杀进程后靠 `Player.unclaimedLevelUpChoices` 找回来）
- `tutorialCoach`：强制新手引导遮罩，步骤存在 `AppSettings`

触感由 `GameHaptics` 提供默认层，不依赖商店。音效由 `SoundService` 在装备「经典音效包」后播放内存正弦波，不依赖音频资源文件。

## 目录

- `Sources/App` 入口、容器、根导航
- `Sources/Core` 时间、配置、主题氛围、触感、新手引导步骤、共享值类型
- `Sources/Models` SwiftData 实体
- `Sources/Engines` 纯计算（含 `RecurringPeriodEngine`、`RecurringFinishEngine`）
- `Sources/Services` 事务与副作用（含 `NotificationPlanner` 纯规划、`SoundService`）
- `Sources/Stores` 界面状态
- `Sources/Features` 各功能页面与共享装饰（氛围、粒子、引导遮罩、头像）
- `Resources/Config` 数值与规则表
- `Tests/EngineTests` 引擎层单测

## 工程生成

仓库不提交 `.xcodeproj`。在 macOS 上：

```bash
brew install xcodegen
xcodegen generate
open LifeRPG.xcodeproj
```
