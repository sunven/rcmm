import Foundation

public enum NewFileMenuPolicy: Sendable {
    public struct EnsureResult: Hashable, Sendable {
        public let entries: [MenuEntry]
        public let menuID: UUID
        public let didInsert: Bool
        public let didNormalize: Bool

        public var didChange: Bool {
            didInsert || didNormalize
        }

        public init(
            entries: [MenuEntry],
            menuID: UUID,
            didInsert: Bool,
            didNormalize: Bool = false
        ) {
            self.entries = entries
            self.menuID = menuID
            self.didInsert = didInsert
            self.didNormalize = didNormalize
        }
    }

    public static func primaryNewFileMenu(in entries: [MenuEntry]) -> NewFileMenuConfig? {
        entries.compactMap { entry -> NewFileMenuConfig? in
            guard case .newFile(let config) = entry else { return nil }
            return config
        }.first
    }

    public static func primaryNewFileMenuID(in entries: [MenuEntry]) -> UUID? {
        primaryNewFileMenu(in: entries)?.id
    }

    public static func ensurePrimaryNewFileMenu(
        in entries: [MenuEntry],
        makeDefault: () -> NewFileMenuConfig = { NewFileMenuConfig() }
    ) -> EnsureResult {
        guard let primaryIndex = entries.firstIndex(where: {
            if case .newFile = $0 { return true }
            return false
        }) else {
            let config = makeDefault()
            return EnsureResult(
                entries: entries + [.newFile(config)],
                menuID: config.id,
                didInsert: true
            )
        }

        guard case .newFile(var primaryConfig) = entries[primaryIndex] else {
            preconditionFailure("primaryIndex must point to a newFile entry")
        }

        let duplicateConfigs = entries.enumerated().compactMap { index, entry -> NewFileMenuConfig? in
            guard index != primaryIndex,
                  case .newFile(let config) = entry else {
                return nil
            }
            return config
        }

        guard !duplicateConfigs.isEmpty else {
            return EnsureResult(
                entries: entries,
                menuID: primaryConfig.id,
                didInsert: false
            )
        }

        let primaryWasEnabled = primaryConfig.isEnabled
        let hasEnabledDuplicate = duplicateConfigs.contains { $0.isEnabled }
        if !primaryWasEnabled && hasEnabledDuplicate {
            for index in primaryConfig.templates.indices {
                primaryConfig.templates[index].isEnabled = false
            }
        }
        primaryConfig.isEnabled = primaryWasEnabled || hasEnabledDuplicate

        var templateIDs = Set(primaryConfig.templates.map(\.id))
        var enabledTemplateNames = Set(
            primaryConfig.templates
                .filter(\.isEnabled)
                .map { $0.displayName.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        for duplicateConfig in duplicateConfigs {
            for template in duplicateConfig.templates {
                var mergedTemplate = template
                if templateIDs.contains(mergedTemplate.id) {
                    mergedTemplate = template.copying(id: UUID())
                }
                templateIDs.insert(mergedTemplate.id)

                if !duplicateConfig.isEnabled {
                    mergedTemplate.isEnabled = false
                }

                if mergedTemplate.isEnabled {
                    let trimmedName = mergedTemplate.displayName
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty,
                       enabledTemplateNames.contains(trimmedName) {
                        mergedTemplate.displayName = uniqueTemplateName(
                            preferredName: trimmedName,
                            existingNames: enabledTemplateNames
                        )
                    }

                    let finalName = mergedTemplate.displayName
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !finalName.isEmpty {
                        enabledTemplateNames.insert(finalName)
                    }
                }

                primaryConfig.templates.append(mergedTemplate)
            }
        }

        let normalizedEntries = entries.enumerated().compactMap { index, entry -> MenuEntry? in
            guard case .newFile = entry else {
                return entry
            }
            return index == primaryIndex ? .newFile(primaryConfig) : nil
        }

        return EnsureResult(
            entries: normalizedEntries,
            menuID: primaryConfig.id,
            didInsert: false,
            didNormalize: true
        )
    }

    private static func uniqueTemplateName(
        preferredName: String,
        existingNames: Set<String>
    ) -> String {
        let trimmedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedName.isEmpty ? "模板" : trimmedName
        guard existingNames.contains(baseName) else {
            return baseName
        }

        var suffix = 2
        while existingNames.contains("\(baseName) \(suffix)") {
            suffix += 1
        }
        return "\(baseName) \(suffix)"
    }
}

private extension NewFileTemplateConfig {
    func copying(id: UUID) -> NewFileTemplateConfig {
        NewFileTemplateConfig(
            id: id,
            displayName: displayName,
            baseName: baseName,
            fileExtension: fileExtension,
            creationMode: creationMode,
            templatePath: templatePath,
            templateFingerprint: templateFingerprint,
            initialContent: initialContent,
            isEnabled: isEnabled
        )
    }
}
