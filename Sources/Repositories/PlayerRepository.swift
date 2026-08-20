import Foundation
import SwiftData

/// 角色与全局设置的读写入口。两者都是单例行，因此统一封装取回与懒创建逻辑。
struct PlayerRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func currentPlayer() -> Player {
        let descriptor = FetchDescriptor<Player>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        if let existing = try? context.fetch(descriptor), let player = existing.first {
            return player
        }
        let player = Player()
        context.insert(player)
        return player
    }

    func settings() -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor), let settings = existing.first {
            return settings
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }

    func ownedItems() -> [OwnedItem] {
        (try? context.fetch(FetchDescriptor<OwnedItem>())) ?? []
    }

    func owns(itemID: String) -> Bool {
        let descriptor = FetchDescriptor<OwnedItem>(predicate: #Predicate { $0.itemID == itemID })
        return ((try? context.fetch(descriptor))?.isEmpty == false)
    }
}
