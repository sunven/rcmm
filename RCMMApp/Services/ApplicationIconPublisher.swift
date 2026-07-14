import AppKit
import RCMMShared

protocol ApplicationIconPublishing: Sendable {
    func publishIcons(for entries: [MenuEntry])
}

final class ApplicationIconPublisher: ApplicationIconPublishing {
    private let iconStore: ApplicationIconStore
    private let loadIconData: @Sendable (String) -> Data?

    init(
        iconStore: ApplicationIconStore = ApplicationIconStore(),
        loadIconData: @escaping @Sendable (String) -> Data? = { path in
            ApplicationIconPublisher.loadIconData(forFile: path)
        }
    ) {
        self.iconStore = iconStore
        self.loadIconData = loadIconData
    }

    func publishIcons(for entries: [MenuEntry]) {
        var icons: [String: Data] = [:]

        for entry in entries {
            guard case .custom(let config) = entry,
                  config.executionMode == .selectedPath else {
                continue
            }

            let appPath = config.appPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !appPath.isEmpty,
                  let iconData = loadIconData(appPath) else {
                continue
            }

            icons[config.id.uuidString] = iconData
        }

        iconStore.saveIcons(icons)
    }

    private static func loadIconData(forFile path: String) -> Data? {
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        let pixelSize = 32
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        let rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        context.cgContext.clear(rect)
        icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        return bitmap.representation(using: .png, properties: [:])
    }
}
