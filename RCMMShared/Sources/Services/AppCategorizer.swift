import Foundation

public enum AppCategorizer {

    public static let terminalBundleIds: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "com.github.wez.wezterm",
        "dev.warp.Warp-Stable",
        "co.zeit.hyper",
        "com.mitchellh.ghostty",
    ]

    public static let editorBundleIds: Set<String> = [
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",
        "com.apple.dt.Xcode",
        "com.sublimetext.4",
        "com.sublimetext.3",
        "com.panic.Nova",
        "com.barebones.bbedit",
        "com.macromates.TextMate",
        "com.coteditor.CotEditor",
        "dev.zed.Zed",
    ]

    public static func categorize(bundleId: String?) -> AppCategory {
        guard let bundleId else { return .other }
        if terminalBundleIds.contains(bundleId) { return .terminal }
        if editorBundleIds.contains(bundleId) { return .editor }
        return .other
    }
}
