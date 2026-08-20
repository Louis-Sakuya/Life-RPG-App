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

## 加成分组

同组互斥，只取一条。这是刻意的设计：`planned_ahead(+20%)` 与 `same_day(-50%)` 描述的是同一个维度，同时生效在语义上是矛盾的。

- `planning`：提前规划 +0.20 / 当天临时 -0.50
- `timeliness`：按时完成 +0.20 / 延期完成 -0.30
- `priority`：五星任务 +0.30
- `continuity`：连续完成 +0.10

分组内若同时命中多条，取绝对值最大的一条（惩罚优先），保证行为可预测。

`streakMultiplier` 独立于 clamp 之外相乘，来自 `balance.json` 的 `streakTiers`（7 天 1.1 / 30 天 1.2 / 100 天 1.5），取满足条件的最高档。

## 数值区间

- 最优情况：`1 + 0.2 + 0.2 + 0.3 + 0.1 = 1.8`，再乘 1.5 连续加成 = **2.7 倍**
- 最差情况：`1 - 0.5 - 0.3 = 0.2`（触底 clamp），无连续加成 = **0.2 倍**
- 规划任务与临时任务的收益差最大约 **13.5 倍**

这个差值足够强地引导玩家使用 Tomorrow Planning（产品核心）。如果实测发现对临时任务惩罚过重，只需要改 `modifiers.json` 里 `same_day` 的一个数字，不动任何代码。

## 等级曲线

`requiredEXP(level) = base * pow(level, exponent)`，为单级所需经验，启动时预生成累计阈值数组，查表 O(log n)。

- 玩家：`base 100 / exponent 1.5`
- 技能：`base 60 / exponent 1.6`

技能起步更快（base 更低）但后期更陡（exponent 更高），效果是玩家在新技能上能快速获得正反馈，而把某个技能推到 Lv100 是真正的长线目标。

## 调参入口

| 想调整的东西 | 改哪个文件 |
| --- | --- |
| 任务基础经验、金币比、等级曲线、连续档位 | `Resources/Config/balance.json` |
| 加成百分比与分组归属 | `Resources/Config/modifiers.json` |
| 成就 / 称号 / 挑战 | `Resources/Config/unlock_rules.json` |
| 商店商品与售价 | `Resources/Config/shop_items.json` |

以上四个文件的任何改动都不需要重新编译逻辑代码，只需重启应用。
