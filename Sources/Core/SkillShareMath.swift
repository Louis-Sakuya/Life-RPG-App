import Foundation

/// 技能经验分配的纯计算。界面滑杆与发布向导都走这里，
/// 保证"所有技能共用 100%"不会因为各自独立拖动而超额或漏分。
enum SkillShareMath {
    static let step = 0.05
    private static let stepCount = 20.0

    static func snap(_ value: Double) -> Double {
        (min(1, max(0, value)) * stepCount).rounded() / stepCount
    }

    static func total(_ shares: [UUID: Double]) -> Double {
        shares.values.reduce(0, +)
    }

    static func isFullAllocation(_ shares: [UUID: Double], tolerance: Double = 0.02) -> Bool {
        abs(total(shares) - 1) <= tolerance
    }

    static func equalShares(ids: [UUID]) -> [UUID: Double] {
        guard !ids.isEmpty else { return [:] }
        if ids.count == 1 { return [ids[0]: 1] }

        let raw = snap(1.0 / Double(ids.count))
        var result: [UUID: Double] = [:]
        var allocated = 0.0
        for id in ids.dropLast() {
            result[id] = raw
            allocated += raw
        }
        result[ids[ids.count - 1]] = snap(1 - allocated)
        return result
    }

    /// 调整某一个技能的占比。
    /// - `keepFullAllocation` 为 true 时，其余技能按原比例填满剩余部分，总和始终为 100%。
    /// - 为 false 时，只保证总和不超过 100%，允许留白。
    static func setShare(
        _ rawValue: Double,
        for id: UUID,
        in shares: [UUID: Double],
        ids: [UUID],
        keepFullAllocation: Bool
    ) -> [UUID: Double] {
        var next = shares
        let value = snap(rawValue)
        let others = ids.filter { $0 != id }

        if keepFullAllocation {
            guard !others.isEmpty else {
                next[id] = 1
                return next
            }
            next[id] = value
            let remaining = snap(1 - value)
            let othersTotal = others.reduce(0.0) { $0 + (shares[$1] ?? 0) }
            if othersTotal <= 0.0001 {
                next[others[0]] = remaining
                for other in others.dropFirst() {
                    next[other] = 0
                }
            } else {
                for other in others {
                    let current = shares[other] ?? 0
                    next[other] = snap(current / othersTotal * remaining)
                }
                let drift = snap(1 - total(next))
                if abs(drift) > 0.0001 {
                    next[others[0]] = snap((next[others[0]] ?? 0) + drift)
                }
            }
            return next
        }

        let othersTotal = others.reduce(0.0) { $0 + (shares[$1] ?? 0) }
        if othersTotal + value > 1 {
            next[id] = snap(max(0, 1 - othersTotal))
        } else {
            next[id] = value
        }
        return next
    }
}
