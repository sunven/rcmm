import SwiftUI

/// 菜单项按钮样式，提供类似原生 macOS 菜单的悬停高亮效果
struct MenuItemButtonStyle: ButtonStyle {
    @Environment(\.isHovered) private var isHovered

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .contentShape(Rectangle())
    }
}

/// 环境键用于传递悬停状态
private struct IsHoveredKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isHovered: Bool {
        get { self[IsHoveredKey.self] }
        set { self[IsHoveredKey.self] = newValue }
    }
}

/// 悬停状态修饰符
extension View {
    func onHoverState(perform action: @escaping (Bool) -> Void) -> some View {
        self.onHover(perform: action)
    }
}
