import Foundation

public enum NewFileTemplateMetadataPolicy: Sendable {
    public static func refreshingTemplateFingerprints(in entries: [MenuEntry]) -> [MenuEntry] {
        entries.map { entry in
            guard case .newFile(var config) = entry else {
                return entry
            }

            for index in config.templates.indices {
                switch config.templates[index].creationMode {
                case .copyTemplate:
                    let normalizedPath = normalizedTemplatePath(config.templates[index].templatePath)
                    config.templates[index].templatePath = normalizedPath
                    config.templates[index].templateFingerprint = NewFileTemplateFingerprint
                        .fileFingerprint(at: normalizedPath)
                case .emptyFile, .textContent:
                    config.templates[index].templatePath = nil
                    config.templates[index].templateFingerprint = nil
                }
            }

            return .newFile(config)
        }
    }

    public static func mergingTemplateFingerprints(
        from refreshedEntries: [MenuEntry],
        into currentEntries: [MenuEntry]
    ) -> [MenuEntry] {
        let refreshedMetadata = metadataByTemplateID(in: refreshedEntries)

        return currentEntries.map { entry in
            guard case .newFile(var config) = entry else {
                return entry
            }

            for index in config.templates.indices {
                let key = TemplateKey(menuID: config.id, templateID: config.templates[index].id)

                switch config.templates[index].creationMode {
                case .copyTemplate:
                    let currentPath = normalizedTemplatePath(config.templates[index].templatePath)
                    config.templates[index].templatePath = currentPath

                    guard let refreshed = refreshedMetadata[key],
                          refreshed.creationMode == .copyTemplate,
                          refreshed.templatePath == currentPath else {
                        if currentPath == nil {
                            config.templates[index].templateFingerprint = nil
                        }
                        continue
                    }

                    config.templates[index].templateFingerprint = refreshed.templateFingerprint
                case .emptyFile, .textContent:
                    config.templates[index].templatePath = nil
                    config.templates[index].templateFingerprint = nil
                }
            }

            return .newFile(config)
        }
    }

    private static func metadataByTemplateID(in entries: [MenuEntry]) -> [TemplateKey: TemplateMetadata] {
        var metadata: [TemplateKey: TemplateMetadata] = [:]

        for entry in entries {
            guard case .newFile(let config) = entry else {
                continue
            }

            for template in config.templates {
                metadata[TemplateKey(menuID: config.id, templateID: template.id)] = TemplateMetadata(
                    creationMode: template.creationMode,
                    templatePath: normalizedTemplatePath(template.templatePath),
                    templateFingerprint: template.templateFingerprint
                )
            }
        }

        return metadata
    }

    private static func normalizedTemplatePath(_ path: String?) -> String? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }

        return path
    }
}

private struct TemplateKey: Hashable {
    let menuID: UUID
    let templateID: UUID
}

private struct TemplateMetadata {
    let creationMode: NewFileCreationMode
    let templatePath: String?
    let templateFingerprint: NewFileTemplateFingerprint?
}
