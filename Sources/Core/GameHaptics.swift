import UIKit

/// 完成反馈的默认层：不依赖商店商品。
enum GameHaptics {
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.85)
    }

    static func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.7)
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

struct RewardPopupEvent: Equatable, Identifiable {
    var id = UUID()
    var sourceID: UUID
    var exp: Int
    var gold: Int
}
