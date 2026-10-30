import AppKit
import SwiftUI

/// 与 DESIGN.md 对齐的界面令牌。所有新增或改动的自定义界面都应从这里取色与字号。
enum RCMMColor {
    static let window = dynamic(0xF7F8FA, 0x222832)
    static let surface = dynamic(0xFFFFFF, 0x2A313C)
    static let surfaceSoft = dynamic(0xF2F4F7, 0x313A47)
    static let line = dynamic(0xD8DEE8, 0x3B4656)
    static let lineSoft = dynamic(0xE7EBF1, 0x333C49)

    static let textPrimary = dynamic(0x111827, 0xF2F5F9)
    static let textSecondary = dynamic(0x374151, 0xC9D2DE)
    static let textMuted = dynamic(0x6B7280, 0x97A3B4)
    static let textFaint = dynamic(0x9AA3AF, 0x6F7B8B)

    static let accent = Color.accentColor
    static let accentText = dynamic(0x2563EB, 0x8FB2FF)
    static let accentSoft = Color.accentColor.opacity(0.13)

    static let success = dynamic(0x2F9E44, 0x4FC46B)
    static let successSoft = dynamic(0xDFF4E5, 0x233D2B)
    static let warning = dynamic(0xB7791F, 0xE0A33B)
    static let warningSoft = dynamic(0xFFF4D6, 0x3D3321)
    static let error = dynamic(0xD92D20, 0xF0655A)
    static let errorSoft = dynamic(0xFDE3DF, 0x43251F)

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(srgbHex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(srgbHex hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum RCMMFont {
    static let pageTitle = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let sheetTitle = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let emptyTitle = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let sectionTitle = Font.system(size: 12, weight: .semibold)
    static let rowTitle = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 13)
    static let secondary = Font.system(size: 12)
    static let caption = Font.system(size: 11)
    static let badge = Font.system(size: 11, weight: .medium)
    static let fieldLabel = Font.system(size: 11, weight: .medium)
    static let metric = Font.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit()
    static let code = Font.system(size: 11, design: .monospaced)
}

struct RCMMDivider: View {
    var axis: Axis = .horizontal

    var body: some View {
        Rectangle()
            .fill(RCMMColor.line)
            .frame(
                width: axis == .vertical ? 1 : nil,
                height: axis == .horizontal ? 1 : nil
            )
    }
}

/// 页面标题：名称用圆体，副标题直接说明这个页面管什么。
struct RCMMPageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(RCMMFont.pageTitle)
                    .foregroundStyle(RCMMColor.textPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(RCMMFont.secondary)
                        .foregroundStyle(RCMMColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            trailing
        }
    }
}

extension RCMMPageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// 顶部统计：数字在上、名词在下，不做胶囊。
struct RCMMMetric: View {
    let value: String
    let label: String
    var tint: Color = RCMMColor.textPrimary

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(RCMMFont.metric)
                .foregroundStyle(tint)
            Text(label)
                .font(RCMMFont.caption)
                .foregroundStyle(RCMMColor.textMuted)
        }
    }
}

/// 设置面板：一层底色，无描边、无阴影；标题在面板外。
struct RCMMPanel<Content: View>: View {
    let title: String?
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(title: String? = nil, padding: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.title = title
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(RCMMFont.sectionTitle)
                    .foregroundStyle(RCMMColor.textMuted)
            }

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(RCMMColor.surface)
            )
        }
    }
}

struct RCMMFieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(RCMMFont.fieldLabel)
            .foregroundStyle(RCMMColor.textMuted)
    }
}

struct RCMMField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            RCMMFieldLabel(label)
            content
        }
    }
}

/// 键值行：标签固定宽度，值占满剩余空间，扫描时左对齐成一条线。
struct RCMMInfoRow: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(RCMMFont.caption)
                .foregroundStyle(RCMMColor.textMuted)
                .frame(width: 58, alignment: .leading)

            Text(value.isEmpty ? "未设置" : value)
                .font(monospaced ? RCMMFont.code : RCMMFont.secondary)
                .foregroundStyle(value.isEmpty ? RCMMColor.textMuted : RCMMColor.textSecondary)
                .lineLimit(3)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RCMMCodeBlock: View {
    let text: String

    var body: some View {
        Text(text)
            .font(RCMMFont.code)
            .foregroundStyle(RCMMColor.textSecondary)
            .textSelection(.enabled)
            .lineLimit(6)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(RCMMColor.surfaceSoft)
            )
    }
}

enum RCMMMessageKind {
    case neutral
    case success
    case warning
    case error

    var symbol: String {
        switch self {
        case .neutral: return "info.circle"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .neutral: return RCMMColor.textMuted
        case .success: return RCMMColor.success
        case .warning: return RCMMColor.warning
        case .error: return RCMMColor.error
        }
    }
}

struct RCMMInlineMessage: View {
    let text: String
    let kind: RCMMMessageKind

    init(_ text: String, kind: RCMMMessageKind = .neutral) {
        self.text = text
        self.kind = kind
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: kind.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(kind.tint)
                .frame(width: 14)

            Text(text)
                .font(RCMMFont.secondary)
                .foregroundStyle(RCMMColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
