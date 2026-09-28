import Foundation

/// 初始化之后的强制新手引导。步骤写进设置，杀进程后从最近的入口步恢复。
enum TutorialStep: String, CaseIterable, Sendable {
    case welcome
    case tapPublishMain
    case pickMain
    case pickUrgent
    case fillMain
    case tapPublishSide
    case pickSide
    case fillSide
    case goGrowth
    case pickHabits
    case tapAddHabit
    case fillHabit
    case done

    var host: TutorialHost {
        switch self {
        case .welcome, .tapPublishMain, .tapPublishSide:
            return .home
        case .goGrowth:
            return .tabs
        case .pickHabits, .tapAddHabit:
            return .growth
        case .done:
            return .tabs
        case .pickMain, .pickUrgent, .fillMain, .pickSide, .fillSide:
            return .wizard
        case .fillHabit:
            return .habitEditor
        }
    }

    var anchor: TutorialAnchorID? {
        switch self {
        case .tapPublishMain, .tapPublishSide: return .homePublish
        case .pickMain: return .wizardMain
        case .pickUrgent: return .wizardUrgent
        case .pickSide: return .wizardSide
        case .pickHabits: return .growthHabits
        case .tapAddHabit: return .growthAdd
        case .goGrowth: return .tabGrowth
        case .welcome, .fillMain, .fillSide, .fillHabit, .done: return nil
        }
    }

    /// 填表步骤必须能点到输入框，遮罩不能挡住界面。
    var allowsFormEntry: Bool {
        switch self {
        case .fillMain, .fillSide, .fillHabit: return true
        default: return false
        }
    }

    var highlightIsButton: Bool {
        anchor != nil && !allowsFormEntry
    }

    var showsPrimary: Bool {
        self == .welcome || self == .done
    }

    /// 杀进程后回到这一大步的入口，避免卡在已经关掉的 sheet 里。
    var resumeEntry: TutorialStep {
        switch self {
        case .pickMain, .pickUrgent, .fillMain: return .tapPublishMain
        case .pickSide, .fillSide: return .tapPublishSide
        case .pickHabits, .tapAddHabit, .fillHabit: return .goGrowth
        default: return self
        }
    }

    var title: String { L10n.t("tutorial.\(rawValue).title") }
    var message: String { L10n.t("tutorial.\(rawValue).message") }
    var primaryTitle: String {
        self == .done ? L10n.t("tutorial.done.action") : L10n.t("tutorial.welcome.action")
    }
}

enum TutorialHost: Sendable {
    case home, tabs, growth, wizard, habitEditor
}

enum TutorialAnchorID: String, Hashable, Sendable {
    case homePublish
    case wizardMain
    case wizardUrgent
    case wizardSide
    case growthHabits
    case growthAdd
    case tabGrowth
}
