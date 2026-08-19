import SwiftUI

enum SettingsDestination: String, CaseIterable, Identifiable {
    case finderMenu
    case newFile
    case compositeCommands
    case general
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .finderMenu:
            return "Finder 菜单"
        case .newFile:
            return "新建文件"
        case .compositeCommands:
            return "组合命令"
        case .general:
            return "通用"
        case .about:
            return "关于"
        }
    }

    var systemImage: String {
        switch self {
        case .finderMenu:
            return "list.bullet"
        case .newFile:
            return "document.badge.plus"
        case .compositeCommands:
            return "rectangle.stack.badge.play"
        case .general:
            return "gear"
        case .about:
            return "info.circle"
        }
    }
}
