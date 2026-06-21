import SwiftUI

/// 校验提示行：错误/警告图标 + 文案。
/// 跨多个编辑器复用，颜色与文字着色可参数化以匹配各站点既有样式。
struct ValidationIssueRow: View {
    let isError: Bool
    let message: String
    var warningColor: Color = .yellow
    /// 为 true 时文字使用与严重级别相同的颜色；否则使用 `.secondary`。
    var colorText: Bool = false
    var spacing: CGFloat = 5
    /// 为 true 时图标使用 `.caption2`，匹配 CommandEditor 既有样式。
    var smallIcon: Bool = false

    var body: some View {
        let tint: Color = isError ? .red : warningColor
        HStack(spacing: spacing) {
            Image(systemName: isError ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(smallIcon ? .caption2 : nil)
                .foregroundStyle(tint)
            Text(message)
                .font(.caption2)
                .foregroundStyle(colorText ? tint : .secondary)
        }
    }
}
