import Foundation

public enum NewFileCreationMode: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case emptyFile
    case textContent
    case copyTemplate

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .emptyFile:
            return "空文件"
        case .textContent:
            return "文本内容"
        case .copyTemplate:
            return "复制模板"
        }
    }
}

public struct NewFileTemplateFingerprint: Codable, Hashable, Sendable {
    public let path: String
    public let fileSize: UInt64
    public let modificationTime: TimeInterval

    public init(path: String, fileSize: UInt64, modificationTime: TimeInterval) {
        self.path = path
        self.fileSize = fileSize
        self.modificationTime = modificationTime
    }

    public static func fileFingerprint(at path: String?) -> NewFileTemplateFingerprint? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        guard let resourceValues = try? url.resourceValues(
            forKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else {
            return nil
        }

        return NewFileTemplateFingerprint(
            path: path,
            fileSize: UInt64(resourceValues.fileSize ?? 0),
            modificationTime: resourceValues.contentModificationDate?.timeIntervalSince1970 ?? 0
        )
    }
}

public struct NewFileTemplateConfig: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var displayName: String
    public var baseName: String
    public var fileExtension: String
    public var creationMode: NewFileCreationMode
    public var templatePath: String?
    public var templateFingerprint: NewFileTemplateFingerprint?
    public var initialContent: String?
    public var isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case baseName
        case fileExtension
        case creationMode
        case templatePath
        case templateFingerprint
        case initialContent
        case isEnabled
    }

    public init(
        id: UUID = UUID(),
        displayName: String,
        baseName: String = "新建",
        fileExtension: String,
        creationMode: NewFileCreationMode,
        templatePath: String? = nil,
        templateFingerprint: NewFileTemplateFingerprint? = nil,
        initialContent: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.baseName = baseName
        self.fileExtension = fileExtension
        self.creationMode = creationMode
        self.templatePath = templatePath
        self.templateFingerprint = templateFingerprint
        self.initialContent = initialContent
        self.isEnabled = isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        baseName = try container.decodeIfPresent(String.self, forKey: .baseName) ?? "新建"
        fileExtension = try container.decode(String.self, forKey: .fileExtension)
        creationMode = try container.decode(NewFileCreationMode.self, forKey: .creationMode)
        templatePath = try container.decodeIfPresent(String.self, forKey: .templatePath)
        templateFingerprint = try container.decodeIfPresent(
            NewFileTemplateFingerprint.self,
            forKey: .templateFingerprint
        )
        initialContent = try container.decodeIfPresent(String.self, forKey: .initialContent)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

public struct NewFileMenuConfig: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var iconName: String?
    public var templates: [NewFileTemplateConfig]
    public var isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case iconName
        case templates
        case isEnabled
    }

    public init(
        id: UUID = UUID(),
        name: String = "新建",
        iconName: String? = "document.badge.plus",
        templates: [NewFileTemplateConfig] = Self.defaultTemplates,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.templates = templates
        self.isEnabled = isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "新建"
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
            ?? "document.badge.plus"
        templates = try container.decodeIfPresent(
            [NewFileTemplateConfig].self,
            forKey: .templates
        ) ?? []
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    public static var defaultTemplates: [NewFileTemplateConfig] {
        [
            NewFileTemplateConfig(
                displayName: "txt",
                fileExtension: "txt",
                creationMode: .emptyFile
            ),
            NewFileTemplateConfig(
                displayName: "md",
                fileExtension: "md",
                creationMode: .textContent,
                initialContent: "# Untitled\n"
            ),
            NewFileTemplateConfig(
                displayName: "word",
                fileExtension: "docx",
                creationMode: .copyTemplate,
                isEnabled: false
            ),
        ]
    }
}
