import SwiftUI

/// 校验提示行：错误/警告图标 + 文案。
struct ValidationIssueRow: View {
    let isError: Bool
    let message: String
    var warningColor: Color = RCMMColor.warning
    var colorText: Bool = false
    var spacing: CGFloat = 5
    var smallIcon: Bool = false

    var body: some View {
        let tint: Color = isError ? RCMMColor.error : warningColor
        HStack(alignment: .top, spacing: spacing) {
            Image(systemName: isError ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(smallIcon ? .system(size: 9, weight: .semibold) : .system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 13)

            Text(message)
                .font(RCMMFont.caption)
                .foregroundStyle(colorText ? tint : RCMMColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
