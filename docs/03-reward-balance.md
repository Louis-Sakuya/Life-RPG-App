# 奖励与平衡

## 公式

```
baseEXP    = difficultyBaseEXP[difficulty] * durationFactor(estimatedMinutes)
baseGold   = baseEXP * goldRatio
multiplier = clamp(1 + Σ(每个分组内取一条生效的加成), 0.2, 3.0)
finalEXP   = round(baseEXP * multiplier * streakMultiplier)
finalGold  = round(baseGold * multiplier * streakMultiplier)
skillEXP   = round(finalEXP * link.expShare)
```

`durationFactor(m) = clamp(1 + (m / 60) * bonusPerHour, min, max)`

幸运日在公式之外再乘 `fortune.xpBonus` / `fortune.goldBonus`，天命额外给一笔固定金币。

周期任务进入延期补债周后，`RewardContext.forceOverdue` 为 true，即使当天完成也走延期惩罚。

## 加成分组

同组互斥，只取一条。这是刻意的设计：`planned_ahead(+20%)` 与 `same_day(-20%)` 描述的是同一个维度，同时生效在语义上是矛盾的。

- `planning`：提前规划 +0.20 / 当天临时 -0.20
- `timeliness`：按时完成 +0.20 / 延期完成 -0.50
- `priority`：五星任务 +0.30
- `continuity`：连续完成 +0.10

分组内若同时命中多条，取绝对值最大的一条（惩罚优先），保证行为可预测。

`streakMultiplier` 独立于 clamp 之外相乘，来自 `balance.json` 的 `streakTiers`（7 天 1.1 / 30 天 1.2 / 100 天 1.5），取满足条件的最高档。

## 数值区间

- 最优情况：`1 + 0.2 + 0.2 + 0.3 + 0.1 = 1.8`，再乘 1.5 连续加成 = **2.7 倍**
- 最差情况：`1 - 0.2 - 0.5 = 0.3`
- 规划任务与临时延期任务的收益差仍然足够大，用来驱动 Tomorrow Planning

如果实测发现对临时或延期任务惩罚过重，只需要改 `modifiers.json` 里对应的一个数字，不动任何代码。

## 等级曲线

`requiredEXP(level) = base * pow(level, exponent)`，为单级所需经验，启动时预生成累计阈值数组，查表 O(log n)。

- 玩家：`base 100 / exponent 1.5`
- 技能：`base 60 / exponent 1.6`
- 属性：`base 80 / exponent 1.55`

技能起步更快（base 更低）但后期更陡（exponent 更高），效果是玩家在新技能上能快速获得正反馈，而把某个技能推到 Lv100 是真正的长线目标。

属性有效等级 = 训练等级 + 升级加点。每级给匹配技能 +3% 经验（上限 +250%）。技能等级也会给关联任务经验加成。

## 商店与经济

装饰品（主题、框、背景、特效、音效、宠物）不进入奖励公式。道具是例外：

| 道具 | 价格 | 效果 |
| --- | --- | --- |
| 完美防御力场（请假卡） | 250 G | 选一天冻结进度，暂停日不计入周期窗口 |
| 法术护盾（保险卡） | 400 G | 漏登恰好一天时保住登录连胜；持有上限一张 |

金币仍然可以放心作为长期激励：道具不加减任务经验，只改时钟与连胜保护。

## 调参入口

| 想调整的东西 | 改哪个文件 |
| --- | --- |
| 任务基础经验、金币比、等级曲线、连续档位、初始栏位 | `Resources/Config/balance.json` |
| 加成百分比与分组归属 | `Resources/Config/modifiers.json` |
| 成就 / 称号 / 挑战 | `Resources/Config/unlock_rules.json` |
| 远行收队（归途）奖励 | `Sources/Engines/RecurringFinishEngine.swift` |
| 商店商品、主题氛围、道具售价 | `Resources/Config/shop_items.json` |
| 幸运成长与幸运日档位 | `Resources/Config/fortune.json` |

以上文件的任何改动都不需要重新编译逻辑代码，只需重启应用。
