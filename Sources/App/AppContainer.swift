import Foundation
import SwiftData

/// 依赖容器。所有服务在这里构造一次，通过 `GameStore` 暴露给界面。
///
/// 时间相关的服务被打包成一个 `Services` 值：它们全都依赖 `GameCalendar`，
/// 而"一天从几点开始"是用户可以在设置里改的。改动后必须整体重建，
/// 否则会出现一半服务按旧口径、一半按新口径判断"今天"的分裂状态。
@MainActor
final class AppContainer {
    struct Services {
        let rewards: RewardService
        let quests: QuestService
        let habits: HabitService
        let dayCycle: DayCycleService
        let metrics: MetricsService
        let statistics: StatisticsService
        let unlocks: UnlockService
        let shop: ShopService
        let export: ExportService
    }

    let modelContainer: ModelContainer
    let context: ModelContext
    let config: GameConfig
    let notifications = NotificationService()

    private(set) var calendar: GameCalendar
    private(set) var services: Services

    /// 数据库加载失败时是否退化为内存模式。真机上一般不会发生，
    /// 但退化比直接崩溃更容易让用户把数据导出来。
    private(set) var isRunningInMemory: Bool

    init(config: GameConfig = .shared, inMemory: Bool = false) {
        self.config = config

        var runningInMemory = inMemory
        let container: ModelContainer
        if let created = try? ModelSchemaRegistry.makeContainer(inMemory: inMemory) {
            container = created
        } else {
            runningInMemory = true
            // 内存容器都构建失败意味着 Schema 本身有问题，属于开发期错误，
            // 应当立刻暴露而不是静默降级。
            container = try! ModelSchemaRegistry.makeContainer(inMemory: true)
        }
        self.modelContainer = container
        self.isRunningInMemory = runningInMemory

        let context = ModelContext(container)
        self.context = context

        let settings = PlayerRepository(context: context).settings()
        let calendar = GameCalendar(dayStartHour: settings.dayStartHour)
        self.calendar = calendar
        self.services = Self.makeServices(context: context, config: config, calendar: calendar)
    }

    // MARK: - 便利访问

    var rewards: RewardService { services.rewards }
    var quests: QuestService { services.quests }
    var habits: HabitService { services.habits }
    var dayCycle: DayCycleService { services.dayCycle }
    var metrics: MetricsService { services.metrics }
    var statistics: StatisticsService { services.statistics }
    var unlocks: UnlockService { services.unlocks }
    var shop: ShopService { services.shop }
    var export: ExportService { services.export }

    // MARK: - 生命周期

    func bootstrap() {
        SeedService(context: context, config: config, calendar: calendar).bootstrap()
        save()
    }

    /// 设置页改动"一天的起始时刻"后调用，整体重建时间相关的服务
    func reloadCalendar(dayStartHour: Int) {
        guard dayStartHour != calendar.dayStartHour else { return }
        calendar = GameCalendar(dayStartHour: dayStartHour)
        services = Self.makeServices(context: context, config: config, calendar: calendar)
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("保存失败：\(error)")
        }
    }

    private static func makeServices(
        context: ModelContext,
        config: GameConfig,
        calendar: GameCalendar
    ) -> Services {
        let rewards = RewardService(context: context, config: config, calendar: calendar)
        let metrics = MetricsService(context: context, config: config, calendar: calendar)
        return Services(
            rewards: rewards,
            quests: QuestService(context: context, config: config, calendar: calendar, rewards: rewards),
            habits: HabitService(context: context, config: config, calendar: calendar, rewards: rewards),
            dayCycle: DayCycleService(context: context, calendar: calendar),
            metrics: metrics,
            statistics: StatisticsService(context: context, calendar: calendar, config: config),
            unlocks: UnlockService(
                context: context,
                config: config,
                calendar: calendar,
                metrics: metrics,
                rewards: rewards
            ),
            shop: ShopService(context: context, config: config, calendar: calendar, rewards: rewards),
            export: ExportService(context: context, config: config, calendar: calendar)
        )
    }
}
